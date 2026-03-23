package expo.community.modules.emojisheet

import android.content.Context
import android.content.SharedPreferences
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewConfiguration
import android.view.VelocityTracker
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import java.text.Normalizer
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future

class EmojiSheetUIView(context: Context) : LinearLayout(context) {

    companion object {
        private const val FREQ_PREFS = "emoji_sheet_frequently_used"
        private const val FREQ_COUNT_SUFFIX = "_count"
        private const val FREQ_DAY_SUFFIX = "_day"
        private const val FREQ_TIME_SUFFIX = "_time"
        private val COMBINING_MARKS_REGEX = "\\p{Mn}+".toRegex()
        // Emoji data + translation keywords are parsed once on a background thread
        // and cached for the app's lifetime. The cacheLock prevents concurrent warmCache()
        // and loadDataAsync() from parsing the same data twice.
        private val cacheLock = Any()
        @Volatile
        private var cachedData: Pair<List<EmojiCategory>, Map<String, List<String>>>? = null

        fun warmCache(context: Context) {
            if (cachedData != null) return
            Thread {
                synchronized(cacheLock) {
                    if (cachedData != null) return@Thread
                    val categories = EmojiData.loadCategories(context)
                    val keywords = loadAllKeywords(context)
                    cachedData = Pair(categories, keywords)
                }
            }.start()
        }

        private fun loadAllKeywords(context: Context): Map<String, List<String>> {
            val merged = mutableMapOf<String, MutableList<String>>()
            try {
                val translationFiles = context.assets.list("translations")?.filter { it.endsWith(".json") } ?: emptyList()
                for (file in translationFiles) {
                    val json = context.assets.open("translations/$file").bufferedReader().use { it.readText() }
                    val obj = org.json.JSONObject(json)
                    for (key in obj.keys()) {
                        val arr = obj.getJSONArray(key)
                        val keywords = merged.getOrPut(key) { mutableListOf() }
                        for (i in 0 until arr.length()) {
                            keywords.add(arr.getString(i))
                        }
                    }
                }
            } catch (e: Exception) {
                // Fallback or empty
            }
            return merged
        }
    }

    var onEmojiSelected: ((Map<String, Any>) -> Unit)? = null
    var onSearchFocused: ((Boolean) -> Unit)? = null
    var onScrollIntentUp: (() -> Unit)? = null
    var onPullDownAtTopDrag: ((Float) -> Unit)? = null
    var onPullDownAtTopRelease: ((Float, Float) -> Unit)? = null

    // Configurable properties
    var columns: Int = 7
    var emojiSize: Float = 32f
    var showSearch: Boolean = true
    var showRecents: Boolean = true
    var enableSkinTones: Boolean = true
    var enableHaptics: Boolean = true
    var recentLimit: Int = 30
    var categoryBarPosition: String = "top"
    var categoryNames: Map<String, String>? = null
    @Volatile
    var excludeEmojis: Set<String> = emptySet()

    private var currentTheme = EmojiSheetTheme.light
    private var allCategories: List<EmojiCategory> = emptyList()
    private var allCategoryKeys: List<String> = emptyList()
    private var localizedKeywords: Map<String, List<String>> = emptyMap()

    private val searchBar: EmojiSearchBar
    private lateinit var categoryStrip: EmojiCategoryStrip
    private val recyclerView: RecyclerView
    private val gridAdapter: EmojiGridAdapter
    private val gridLayoutManager: GridLayoutManager
    private val emptyStateLabel: TextView
    private val contentFrame: FrameLayout

    private var isSearchActive = false
    private var bottomPillContainer: View? = null
    private var suppressCategorySync = false
    private var currentSearchQuery = ""
    private var didTriggerExpandForCurrentDrag = false
    private var initialTouchY = 0f
    private var lastTopPullDragDistance = 0f
    private var isHandlingTopPullDrag = false
    private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop.toFloat()
    private var velocityTracker: VelocityTracker? = null
    private var topPullStartY: Float? = null
    private val topPullActivationThresholdPx = 24f * context.resources.displayMetrics.density

    init {
        orientation = VERTICAL
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)

        // Search bar
        searchBar = EmojiSearchBar(context, { query ->
            onSearch(query)
        }, { hasFocus ->
            onSearchFocused?.invoke(hasFocus)
            if (categoryBarPosition == "bottom") {
                bottomPillContainer?.visibility = if (hasFocus) View.GONE else View.VISIBLE
            }
        })
        addView(searchBar)

        // Category strip (starts with just frequently_used, rebuilt after data loads)
        allCategoryKeys = listOf("frequently_used")
        categoryStrip = EmojiCategoryStrip(context, allCategoryKeys) { index ->
            scrollToCategory(index)
        }
        addView(categoryStrip)

        // Grid
        gridAdapter = EmojiGridAdapter(
            theme = currentTheme,
            onEmojiClick = { emoji, emojiId -> handleEmojiClick(emoji, emojiId) },
            onEmojiLongPress = { view, baseEmoji, emojiId -> showSkinTonePicker(view, baseEmoji, emojiId) }
        )

        gridLayoutManager = GridLayoutManager(context, columns)
        gridLayoutManager.spanSizeLookup = object : GridLayoutManager.SpanSizeLookup() {
            override fun getSpanSize(position: Int): Int {
                return if (gridAdapter.getItemViewType(position) == EmojiGridAdapter.VIEW_TYPE_HEADER) {
                    gridAdapter.spanCount
                } else {
                    1
                }
            }
        }

        recyclerView = RecyclerView(context).apply {
            layoutManager = gridLayoutManager
            adapter = gridAdapter
            setHasFixedSize(false)
            overScrollMode = View.OVER_SCROLL_NEVER
            isNestedScrollingEnabled = true
            // Prevent BottomSheet from intercepting scroll when grid can scroll
            addOnItemTouchListener(object : RecyclerView.SimpleOnItemTouchListener() {
                override fun onInterceptTouchEvent(rv: RecyclerView, e: android.view.MotionEvent): Boolean {
                    velocityTracker?.addMovement(e)

                    when (e.actionMasked) {
                        android.view.MotionEvent.ACTION_DOWN -> {
                            velocityTracker?.recycle()
                            velocityTracker = VelocityTracker.obtain().apply { addMovement(e) }
                            initialTouchY = e.y
                            didTriggerExpandForCurrentDrag = false
                            lastTopPullDragDistance = 0f
                            isHandlingTopPullDrag = false
                            topPullStartY = null
                        }
                        android.view.MotionEvent.ACTION_UP,
                        android.view.MotionEvent.ACTION_CANCEL -> {
                            didTriggerExpandForCurrentDrag = false
                            velocityTracker?.computeCurrentVelocity(1000)
                            val releaseVelocityY = velocityTracker?.yVelocity ?: 0f
                            if (isHandlingTopPullDrag) {
                                onPullDownAtTopRelease?.invoke(lastTopPullDragDistance, releaseVelocityY)
                            }
                            lastTopPullDragDistance = 0f
                            isHandlingTopPullDrag = false
                            topPullStartY = null
                            velocityTracker?.recycle()
                            velocityTracker = null
                        }
                    }

                    if (e.actionMasked == android.view.MotionEvent.ACTION_MOVE) {
                        val deltaY = e.y - initialTouchY
                        val isAtTop = !rv.canScrollVertically(-1)
                        if (isHandlingTopPullDrag) {
                            rv.parent?.requestDisallowInterceptTouchEvent(true)
                            rv.stopScroll()
                            val baselineY = topPullStartY ?: e.y
                            val dragDistance = maxOf(0f, e.y - baselineY)
                            lastTopPullDragDistance = dragDistance
                            onPullDownAtTopDrag?.invoke(dragDistance)
                        } else if (isAtTop && deltaY > topPullActivationThresholdPx) {
                            rv.parent?.requestDisallowInterceptTouchEvent(true)
                            rv.stopScroll()
                            isHandlingTopPullDrag = true
                            topPullStartY = e.y
                            lastTopPullDragDistance = 0f
                            onPullDownAtTopDrag?.invoke(0f)
                        } else if (rv.canScrollVertically(-1) || rv.canScrollVertically(1)) {
                            rv.parent?.requestDisallowInterceptTouchEvent(true)
                        }
                    } else if (rv.canScrollVertically(-1) || rv.canScrollVertically(1)) {
                        rv.parent?.requestDisallowInterceptTouchEvent(true)
                    }
                    return false
                }
            })
            val lp = LayoutParams(
                LayoutParams.MATCH_PARENT,
                0,
                1f
            )
            layoutParams = lp
        }

        recyclerView.addOnScrollListener(object : RecyclerView.OnScrollListener() {
            override fun onScrollStateChanged(rv: RecyclerView, newState: Int) {
                if (newState == RecyclerView.SCROLL_STATE_IDLE) {
                    didTriggerExpandForCurrentDrag = false
                }
            }

            override fun onScrolled(rv: RecyclerView, dx: Int, dy: Int) {
                if (dy > 0 && rv.scrollState != RecyclerView.SCROLL_STATE_IDLE && !didTriggerExpandForCurrentDrag) {
                    didTriggerExpandForCurrentDrag = true
                    onScrollIntentUp?.invoke()
                }

                if (suppressCategorySync || isSearchActive) return
                val firstVisible = gridLayoutManager.findFirstVisibleItemPosition()
                if (firstVisible != RecyclerView.NO_POSITION) {
                    val catIndex = gridAdapter.getCategoryIndexForPosition(firstVisible)
                    categoryStrip.setSelectedCategory(catIndex)
                }
            }
        })

        // Wrap grid + empty state in a FrameLayout so they share the same space
        val density = context.resources.displayMetrics.density
        emptyStateLabel = TextView(context).apply {
            text = "No emojis found"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER_HORIZONTAL or Gravity.TOP
            visibility = View.GONE
            setPadding(0, (40 * density).toInt(), 0, 0)
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        contentFrame = FrameLayout(context).apply {
            val lp = LayoutParams(LayoutParams.MATCH_PARENT, 0, 1f)
            layoutParams = lp
            addView(recyclerView.also {
                it.layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )
            })
            addView(emptyStateLabel)
        }
        addView(contentFrame)

        applyTheme(currentTheme)
    }

    /** Call after setting configurable properties but before loadDataAsync to apply layout changes. */
    fun applyConfiguration() {
        // Update grid adapter settings
        gridAdapter.spanCount = columns
        gridAdapter.emojiTextSize = emojiSize
        gridAdapter.enableSkinTones = enableSkinTones
        gridAdapter.enableHaptics = enableHaptics
        gridLayoutManager.spanCount = columns

        // Show/hide search
        searchBar.visibility = if (showSearch) View.VISIBLE else View.GONE

        // Category bar position
        if (categoryBarPosition == "bottom") {
            // Move category strip to floating pill overlay at bottom
            val stripIndex = indexOfChild(categoryStrip)
            if (stripIndex >= 0) {
                removeView(categoryStrip)
            }
            // Remove contentFrame from linear layout and re-add in a wrapper
            removeView(contentFrame)

            val density = context.resources.displayMetrics.density
            val horizontalInset = (16 * density).toInt()
            val bottomInset = (8 * density).toInt()
            val stripHeight = (44 * density).toInt()
            val cornerRadius = 22 * density

            val wrapperFrame = FrameLayout(context).apply {
                layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, 0, 1f)
            }

            contentFrame.layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            wrapperFrame.addView(contentFrame)

            // Floating pill container with rounded background
            val pillBackground = android.graphics.drawable.GradientDrawable().apply {
                setColor(currentTheme.categoryBarBackgroundColor)
                this.cornerRadius = cornerRadius
            }

            val pillContainer = FrameLayout(context).apply {
                background = pillBackground
                elevation = 8 * density
                clipToOutline = true
                outlineProvider = android.view.ViewOutlineProvider.BACKGROUND
            }

            categoryStrip.setBackgroundColor(android.graphics.Color.TRANSPARENT)
            categoryStrip.layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                stripHeight
            )
            pillContainer.addView(categoryStrip)

            pillContainer.layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                stripHeight
            ).apply {
                gravity = Gravity.BOTTOM
                setMargins(horizontalInset, 0, horizontalInset, bottomInset)
            }
            bottomPillContainer = pillContainer
            wrapperFrame.addView(pillContainer)

            // Bottom padding so grid content scrolls above the floating bar
            val totalBarSpace = stripHeight + bottomInset * 2
            recyclerView.setPadding(
                recyclerView.paddingLeft,
                recyclerView.paddingTop,
                recyclerView.paddingRight,
                totalBarSpace
            )
            recyclerView.clipToPadding = false

            addView(wrapperFrame)
        }
    }

    var searchPlaceholder: String? = null
        set(value) { field = value; if (value != null) searchBar.setHint(value) }
    var noResultsText: String? = null
        set(value) { field = value; if (value != null) emptyStateLabel.text = value }

    fun loadDataAsync() {
        val cached = cachedData
        if (cached != null) {
            allCategories = cached.first
            localizedKeywords = cached.second
            allCategoryKeys = buildCategoryKeys()
            rebuildCategoryStrip()
            buildAndSetItems()
            return
        }

        Thread {
            val data = synchronized(cacheLock) {
                cachedData ?: run {
                    val categories = EmojiData.loadCategories(context)
                    val keywords = loadLocalizedKeywords()
                    Pair(categories, keywords).also { cachedData = it }
                }
            }
            val categories = data.first
            val keywords = data.second
            post {
                allCategories = categories
                localizedKeywords = keywords
                allCategoryKeys = buildCategoryKeys()
                rebuildCategoryStrip()
                buildAndSetItems()
            }
        }.start()
    }

    fun updateTheme(theme: String) {
        currentTheme = EmojiSheetTheme.fromName(theme)
        applyTheme(currentTheme)
    }

    fun applyCustomTheme(theme: EmojiSheetTheme) {
        currentTheme = theme
        applyTheme(currentTheme)
    }

    private fun applyTheme(theme: EmojiSheetTheme) {
        setBackgroundColor(theme.backgroundColor)
        searchBar.applyTheme(theme)
        categoryStrip.applyTheme(theme)
        gridAdapter.updateTheme(theme)
        recyclerView.setBackgroundColor(theme.backgroundColor)
        emptyStateLabel.setTextColor(theme.textSecondaryColor)
    }

    private fun buildCategoryKeys(): List<String> {
        val keys = mutableListOf<String>()
        if (showRecents && getFrequentlyUsed().isNotEmpty()) {
            keys.add("frequently_used")
        }
        for (cat in allCategories) {
            keys.add(cat.title)
        }
        return keys
    }

    private fun buildAndSetItems() {
        val items = mutableListOf<EmojiGridAdapter.ListItem>()
        val sectionPositions = mutableListOf<Int>()

        // Frequently used (only if there are actual entries)
        if (showRecents) {
            val freq = getFrequentlyUsed().filter { it.id !in excludeEmojis }
            if (freq.isNotEmpty()) {
                sectionPositions.add(items.size)
                items.add(EmojiGridAdapter.ListItem.Header(
                    EmojiData.displayName("frequently_used", categoryNames),
                    "frequently_used"
                ))
            }
            for (entry in freq) {
                val resolvedEmoji = resolveSkinTone(entry.emoji, entry.id, entry.toneEnabled)
                items.add(EmojiGridAdapter.ListItem.Emoji(
                    emoji = resolvedEmoji,
                    name = entry.name,
                    toneEnabled = entry.toneEnabled,
                    keywords = entry.keywords,
                    id = entry.id
                ))
            }
        }

        // Regular categories
        for (cat in allCategories) {
            val filtered = cat.data.filter { it.id !in excludeEmojis }
            if (filtered.isEmpty()) continue
            sectionPositions.add(items.size)
            items.add(EmojiGridAdapter.ListItem.Header(
                EmojiData.displayName(cat.title, categoryNames),
                cat.title
            ))
            for (emoji in filtered) {
                val resolvedEmoji = resolveSkinTone(emoji.emoji, emoji.id, emoji.toneEnabled)
                items.add(EmojiGridAdapter.ListItem.Emoji(
                    emoji = resolvedEmoji,
                    name = emoji.name,
                    toneEnabled = emoji.toneEnabled,
                    keywords = emoji.keywords,
                    id = emoji.id
                ))
            }
        }

        gridAdapter.setItems(items, sectionPositions)

        // Rebuild category keys in case frequently_used changed
        val newKeys = buildCategoryKeys()
        if (newKeys != allCategoryKeys) {
            allCategoryKeys = newKeys
            rebuildCategoryStrip()
        }
    }

    private fun rebuildCategoryStrip() {
        val parent = categoryStrip.parent
        if (parent is android.view.ViewGroup) {
            val index = parent.indexOfChild(categoryStrip)
            parent.removeView(categoryStrip)
            categoryStrip = EmojiCategoryStrip(context, allCategoryKeys) { catIndex ->
                scrollToCategory(catIndex)
            }
            parent.addView(categoryStrip, index)
        } else {
            val index = indexOfChild(categoryStrip)
            removeView(categoryStrip)
            categoryStrip = EmojiCategoryStrip(context, allCategoryKeys) { catIndex ->
                scrollToCategory(catIndex)
            }
            addView(categoryStrip, index)
        }
        categoryStrip.applyTheme(currentTheme)
    }

    private fun resolveSkinTone(baseEmoji: String, emojiId: String, toneEnabled: Boolean): String {
        if (!toneEnabled) return baseEmoji
        val savedTone = EmojiSkinTonePicker.getSavedTone(context, emojiId)
        return if (savedTone != null) {
            EmojiData.applyTone(baseEmoji, savedTone)
        } else {
            baseEmoji
        }
    }

    private fun scrollToCategory(index: Int) {
        val positions = gridAdapter.getSectionPositions()
        if (index in positions.indices) {
            suppressCategorySync = true
            gridLayoutManager.scrollToPositionWithOffset(positions[index], 0)
            recyclerView.post {
                suppressCategorySync = false
            }
        }
    }

    // Search runs on a single background thread to avoid blocking the UI.
    // A single-thread executor ensures only one search runs at a time —
    // new keystrokes cancel the previous task via Future.cancel(true)
    // and the generation counter provides a secondary guard against stale results.
    private var searchGeneration = 0
    private val searchExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var searchFuture: Future<*>? = null

    private fun onSearch(query: String) {
        val trimmedQuery = query.trim()
        currentSearchQuery = trimmedQuery
        if (trimmedQuery.isEmpty()) {
            searchGeneration += 1
            isSearchActive = false
            categoryStrip.visibility = View.VISIBLE
            bottomPillContainer?.visibility = View.VISIBLE
            emptyStateLabel.visibility = View.GONE
            recyclerView.visibility = View.VISIBLE
            buildAndSetItems()
            recyclerView.postDelayed({ recyclerView.scrollToPosition(0) }, 100)
            return
        }

        isSearchActive = true
        categoryStrip.visibility = View.GONE
        bottomPillContainer?.visibility = View.GONE

        val generation = ++searchGeneration
        val categories = allCategories
        val keywords = localizedKeywords

        // Cancel previous search task
        searchFuture?.cancel(true)
        val exclude = excludeEmojis
        searchFuture = searchExecutor.submit {
            val normalizedQueryVariants = normalizedSearchVariants(trimmedQuery)
            val scored = mutableListOf<Pair<EmojiGridAdapter.ListItem.Emoji, Int>>()

            for (cat in categories) {
                if (Thread.currentThread().isInterrupted || generation != searchGeneration) return@submit
                for (emoji in cat.data) {
                    if (emoji.id in exclude) continue
                    val score = relevanceScore(emoji, normalizedQueryVariants, keywords)
                    if (score > 0) {
                        val resolved = resolveSkinTone(emoji.emoji, emoji.id, emoji.toneEnabled)
                        scored.add(Pair(EmojiGridAdapter.ListItem.Emoji(
                            emoji = resolved, name = emoji.name,
                            toneEnabled = emoji.toneEnabled, keywords = emoji.keywords, id = emoji.id
                        ), score))
                    }
                }
            }

            // Sort by relevance score descending
            scored.sortByDescending { it.second }

            if (Thread.currentThread().isInterrupted || generation != searchGeneration) return@submit
            post {
                if (generation != searchGeneration) return@post
                val results = mutableListOf<EmojiGridAdapter.ListItem>()
                val sectionPositions = mutableListOf<Int>()
                sectionPositions.add(0)
                results.add(EmojiGridAdapter.ListItem.Header("Search Results", "search"))
                for ((item, _) in scored) { results.add(item) }

                val hasResults = results.size > 1
                emptyStateLabel.visibility = if (hasResults) View.GONE else View.VISIBLE
                recyclerView.visibility = if (hasResults) View.VISIBLE else View.GONE
                gridAdapter.setItems(results, sectionPositions)
                recyclerView.scrollToPosition(0)
            }
        }
    }

    private fun handleEmojiClick(emoji: String, emojiId: String) {
        trackFrequentlyUsed(emojiId)
        refreshVisibleItemsAfterUsage()
        val name = findEmojiName(emojiId) ?: ""
        val data = mapOf("emoji" to emoji, "name" to name, "id" to emojiId)
        onEmojiSelected?.invoke(data)
    }

    private fun findEmojiName(emojiId: String): String? {
        for (cat in allCategories) {
            for (emoji in cat.data) {
                if (emoji.id == emojiId) return emoji.name
            }
        }
        return null
    }

    private fun showSkinTonePicker(anchorView: View, baseEmoji: String, emojiId: String) {
        if (!enableSkinTones) return
        if (enableHaptics) {
            anchorView.performHapticFeedback(android.view.HapticFeedbackConstants.LONG_PRESS)
        }
        val originalBase = findBaseEmoji(emojiId) ?: baseEmoji
        val picker = EmojiSkinTonePicker(context, currentTheme, enableHaptics) { selectedEmoji ->
            trackFrequentlyUsed(emojiId)
            refreshVisibleItemsAfterUsage()
            val name = findEmojiName(emojiId) ?: ""
            val data = mapOf("emoji" to selectedEmoji, "name" to name, "id" to emojiId)
            onEmojiSelected?.invoke(data)
        }
        picker.show(anchorView, originalBase, emojiId)
    }

    private fun findBaseEmoji(emojiId: String): String? {
        for (cat in allCategories) {
            for (emoji in cat.data) {
                if (emoji.id == emojiId) return emoji.emoji
            }
        }
        return null
    }

    // --- Localized Search ---

    private fun loadLocalizedKeywords(): Map<String, List<String>> {
        return loadAllKeywords(context)
    }

    // --- Frequently Used ---

    private fun getFreqPrefs(): SharedPreferences =
        context.getSharedPreferences(FREQ_PREFS, Context.MODE_PRIVATE)

    private fun trackFrequentlyUsed(emojiId: String) {
        val prefs = getFreqPrefs()
        val currentCount = prefs.getInt(emojiId + FREQ_COUNT_SUFFIX, 0)
        prefs.edit()
            .putInt(emojiId + FREQ_COUNT_SUFFIX, currentCount + 1)
            .putLong(emojiId + FREQ_DAY_SUFFIX, getStartOfDayMillis())
            .putLong(emojiId + FREQ_TIME_SUFFIX, System.currentTimeMillis())
            .apply()
    }

    private fun getFrequentlyUsed(): List<EmojiItem> {
        val prefs = getFreqPrefs()
        val all = prefs.all

        val entries = mutableListOf<Triple<String, Int, Long>>()
        val seen = mutableSetOf<String>()

        for ((key, value) in all) {
            if (key.endsWith(FREQ_COUNT_SUFFIX)) {
                val emojiId = key.removeSuffix(FREQ_COUNT_SUFFIX)
                if (seen.add(emojiId)) {
                    val count = value as? Int ?: 0
                    val lastUsed = prefs.getLong(emojiId + FREQ_TIME_SUFFIX, 0)
                    entries.add(Triple(emojiId, count, lastUsed))
                }
            }
        }

        entries.sortWith(
            compareByDescending<Triple<String, Int, Long>> {
                prefs.getLong(it.first + FREQ_DAY_SUFFIX, 0)
            }
                .thenByDescending { it.third }
                .thenBy { it.first }
        )

        val top = entries.take(recentLimit)

        val emojiMap = mutableMapOf<String, EmojiItem>()
        for (cat in allCategories) {
            for (emoji in cat.data) {
                emojiMap[emoji.id] = emoji
            }
        }

        return top.mapNotNull { (id, _, _) -> emojiMap[id] }
    }

    private fun refreshVisibleItemsAfterUsage() {
        if (currentSearchQuery.isBlank()) {
            buildAndSetItems()
        } else {
            onSearch(currentSearchQuery)
        }
    }

    private fun stripVariationSelectors(emoji: String): String {
        return emoji.filter { it.code != 0xFE0E && it.code != 0xFE0F }
    }

    private fun normalizeSearchText(text: String): String {
        val normalized = Normalizer.normalize(text, Normalizer.Form.NFD)
            .replace(COMBINING_MARKS_REGEX, "")
        return normalized
            .trim()
            .lowercase(Locale.ROOT)
    }

    private fun normalizedSearchVariants(text: String): Set<String> {
        return setOf(normalizeSearchText(text)).filter { it.isNotBlank() }.toSet()
    }

    private fun matchesSearch(normalizedText: String, queryVariants: Set<String>): Boolean {
        return queryVariants.any { normalizedText.contains(it) }
    }

    // Relevance scoring for search results:
    // 100 = exact name match, 90 = name starts with, 80 = exact keyword,
    // 70 = keyword starts with, 50 = name contains, 30 = keyword contains,
    // 10 = localized keyword contains. Returns 0 for no match.
    private fun relevanceScore(
        emoji: EmojiItem,
        queryVariants: Set<String>,
        localizedKeywords: Map<String, List<String>>
    ): Int {
        val nameNorm = normalizeSearchText(emoji.name)

        // Check name
        for (variant in queryVariants) {
            if (nameNorm == variant) return 100
            if (nameNorm.startsWith(variant)) return 90
        }

        // Check built-in keywords
        var bestScore = 0
        for (kw in emoji.keywords) {
            val kwNorm = normalizeSearchText(kw)
            for (variant in queryVariants) {
                if (kwNorm == variant) bestScore = maxOf(bestScore, 80)
                else if (kwNorm.startsWith(variant)) bestScore = maxOf(bestScore, 70)
                else if (kwNorm.contains(variant)) bestScore = maxOf(bestScore, 30)
            }
            if (bestScore >= 80) break
        }

        // Check name contains (lower priority than keyword exact/startsWith)
        if (bestScore < 50) {
            for (variant in queryVariants) {
                if (nameNorm.contains(variant)) bestScore = maxOf(bestScore, 50)
            }
        }

        if (bestScore > 0) return bestScore

        // Check localized keywords
        val localKw = localizedKeywords[emoji.emoji]
            ?: localizedKeywords[stripVariationSelectors(emoji.emoji)]
        if (localKw != null) {
            for (kw in localKw) {
                if (queryVariants.any { normalizeSearchText(kw).contains(it) }) return 10
            }
        }

        return 0
    }

    private fun getStartOfDayMillis(): Long {
        val calendar = java.util.Calendar.getInstance()
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
        calendar.set(java.util.Calendar.MINUTE, 0)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        searchFuture?.cancel(true)
        searchExecutor.shutdownNow()
    }
}
