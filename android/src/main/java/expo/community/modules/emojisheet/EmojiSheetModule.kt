package expo.community.modules.emojisheet

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.WindowManager
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import android.widget.FrameLayout
import android.widget.LinearLayout
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialog
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class EmojiSheetModule : Module() {
    private var dialog: BottomSheetDialog? = null
    private var currentPromise: Promise? = null
    private var bottomSheetContentView: View? = null
    private var isAnimatingClose = false

    override fun definition() =
        ModuleDefinition {
            Name("EmojiSheet")

            OnCreate {
                val ctx = appContext.reactContext ?: return@OnCreate
                EmojiSheetUIView.warmCache(ctx)
            }

            AsyncFunction("present") { options: Map<String, Any>, promise: Promise ->
                val activity = appContext.currentActivity
                if (activity == null) {
                    promise.resolve(Bundle().apply { putBoolean("cancelled", true) })
                    return@AsyncFunction
                }
                activity.runOnUiThread {
                    presentSheet(options, promise)
                }
            }

            AsyncFunction("dismiss") {
                appContext.currentActivity?.runOnUiThread {
                    dismissSheet(cancelled = true)
                }
            }

            AsyncFunction("clearRecents") {
                appContext.reactContext
                    ?.getSharedPreferences("emoji_sheet_frequently_used", android.content.Context.MODE_PRIVATE)
                    ?.edit()?.clear()?.apply()
            }

            AsyncFunction("clearSkinTonePreferences") {
                appContext.reactContext
                    ?.getSharedPreferences("emoji_sheet_skin_tones", android.content.Context.MODE_PRIVATE)
                    ?.edit()?.clear()?.apply()
            }

            View(EmojiSheetContentView::class) {
                Prop("theme") { view: EmojiSheetContentView, theme: String? ->
                    val resolved = if (theme == "system") {
                        val uiMode = view.context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
                        if (uiMode == android.content.res.Configuration.UI_MODE_NIGHT_YES) "dark" else "light"
                    } else {
                        theme ?: "light"
                    }
                    view.updateTheme(resolved)
                }
                Prop("categoryBarPosition") { view: EmojiSheetContentView, position: String? ->
                    view.updateCategoryBarPosition(position ?: "top")
                }
                Prop("columns") { view: EmojiSheetContentView, columns: Int? ->
                    view.updateColumns(columns ?: 7)
                }
                Prop("emojiSize") { view: EmojiSheetContentView, size: Double? ->
                    view.updateEmojiSize(size?.toFloat() ?: 32f)
                }
                Prop("recentLimit") { view: EmojiSheetContentView, limit: Int? ->
                    view.updateRecentLimit(limit ?: 30)
                }
                Prop("showSearch") { view: EmojiSheetContentView, show: Boolean? ->
                    view.updateShowSearch(show ?: true)
                }
                Prop("showRecents") { view: EmojiSheetContentView, show: Boolean? ->
                    view.updateShowRecents(show ?: true)
                }
                Prop("enableSkinTones") { view: EmojiSheetContentView, enable: Boolean? ->
                    view.updateEnableSkinTones(enable ?: true)
                }
                Prop("enableHaptics") { view: EmojiSheetContentView, enable: Boolean? ->
                    view.updateEnableHaptics(enable ?: true)
                }
                Prop("enableAnimations") { view: EmojiSheetContentView, enable: Boolean? ->
                    view.updateEnableAnimations(enable ?: false)
                }
                Prop("searchPlaceholder") { view: EmojiSheetContentView, text: String? ->
                    if (text != null) view.updateSearchPlaceholder(text)
                }
                Prop("noResultsText") { view: EmojiSheetContentView, text: String? ->
                    if (text != null) view.updateNoResultsText(text)
                }
                Prop("categoryNames") { view: EmojiSheetContentView, names: Map<String, String>? ->
                    if (names != null) view.updateCategoryNames(names)
                }
                Prop("excludeEmojis") { view: EmojiSheetContentView, ids: List<String>? ->
                    view.updateExcludeEmojis(ids ?: emptyList())
                }
                Events("onEmojiSelected")
            }
        }

    private fun presentSheet(options: Map<String, Any>, promise: Promise) {
        val activity = appContext.currentActivity ?: return
        val themeString = options["theme"] as? String ?: "light"
        val isDark = when (themeString) {
            "dark" -> true
            "system" -> {
                val uiMode = activity.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
                uiMode == android.content.res.Configuration.UI_MODE_NIGHT_YES
            }
            else -> false
        }
        val density = activity.resources.displayMetrics.density

        // Parse new options
        @Suppress("UNCHECKED_CAST")
        val snapPoints = (options["snapPoints"] as? List<*>)?.mapNotNull { (it as? Number)?.toDouble() } ?: listOf(0.5, 1.0)
        val columns = (options["columns"] as? Number)?.toInt() ?: 7
        val emojiSize = (options["emojiSize"] as? Number)?.toFloat() ?: 32f
        val showSearch = options["showSearch"] as? Boolean ?: true
        val showRecents = options["showRecents"] as? Boolean ?: true
        val enableSkinTones = options["enableSkinTones"] as? Boolean ?: true
        val enableHaptics = options["enableHaptics"] as? Boolean ?: true
        val enableAnimations = options["enableAnimations"] as? Boolean ?: false
        val recentLimit = (options["recentLimit"] as? Number)?.toInt() ?: 30
        val gestureEnabled = options["gestureEnabled"] as? Boolean ?: true
        val backdropOpacity = (options["backdropOpacity"] as? Number)?.toFloat() ?: if (isDark) 0.4f else 0.22f
        val categoryBarPosition = options["categoryBarPosition"] as? String ?: "top"
        @Suppress("UNCHECKED_CAST")
        val categoryNames = options["categoryNames"] as? Map<String, String>
        @Suppress("UNCHECKED_CAST")
        val excludeEmojis = ((options["excludeEmojis"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()).toSet()

        // Resolve colors from options or defaults
        val bgColor = parseColor(options["backgroundColor"] as? String) ?: if (isDark) Color.parseColor("#1A1A2E") else Color.WHITE
        val searchBgColor = parseColor(options["searchBarBackgroundColor"] as? String) ?: if (isDark) Color.parseColor("#2A2F39") else Color.parseColor("#F0F0F0")
        val searchTextColor = parseColor(options["searchTextColor"] as? String)
        val placeholderTextColor = parseColor(options["placeholderTextColor"] as? String)
        val selectionColor = parseColor(options["selectionColor"] as? String)
        val textColor = parseColor(options["textColor"] as? String) ?: if (isDark) Color.WHITE else Color.BLACK
        val textSecondaryColor = parseColor(options["textSecondaryColor"] as? String) ?: if (isDark) 0x99FFFFFF.toInt() else 0x80000000.toInt()
        val accentColor = parseColor(options["accentColor"] as? String) ?: Color.parseColor("#EA4578")
        val dividerColor = parseColor(options["dividerColor"] as? String) ?: if (isDark) 0x26FFFFFF.toInt() else Color.parseColor("#E0E0E0")
        val handleColor = parseColor(options["handleColor"] as? String) ?: if (isDark) 0x66FFFFFF.toInt() else 0x33000000.toInt()
        val categoryIconColor = parseColor(options["categoryIconColor"] as? String) ?: textSecondaryColor
        val categoryActiveIconColor = parseColor(options["categoryActiveIconColor"] as? String) ?: accentColor
        val categoryActiveBackgroundColor = parseColor(options["categoryActiveBackgroundColor"] as? String) ?: dividerColor
        val categoryBarBackgroundColor = parseColor(options["categoryBarBackgroundColor"] as? String) ?: bgColor

        val customTheme = EmojiSheetTheme(
            backgroundColor = bgColor,
            searchBarBackgroundColor = searchBgColor,
            textColor = textColor,
            textSecondaryColor = textSecondaryColor,
            dividerColor = dividerColor,
            accentColor = accentColor,
            categoryIconColor = categoryIconColor,
            categoryActiveIconColor = categoryActiveIconColor,
            categoryActiveBackgroundColor = categoryActiveBackgroundColor,
            handleColor = handleColor,
            categoryBarBackgroundColor = categoryBarBackgroundColor,
            searchTextColor = searchTextColor,
            placeholderTextColor = placeholderTextColor,
            selectionColor = selectionColor
        )

        val bottomSheet = BottomSheetDialog(activity).apply {
            if (gestureEnabled) {
                setCancelable(true)
                setCanceledOnTouchOutside(true)
            } else {
                setCancelable(false)
                setCanceledOnTouchOutside(false)
            }
        }

        val pickerView = EmojiSheetUIView(activity)
        // Apply configurable properties
        pickerView.columns = columns
        pickerView.emojiSize = emojiSize
        pickerView.showSearch = showSearch
        pickerView.showRecents = showRecents
        pickerView.enableSkinTones = enableSkinTones
        pickerView.enableHaptics = enableHaptics
        pickerView.enableAnimations = enableAnimations
        pickerView.recentLimit = recentLimit
        pickerView.categoryBarPosition = categoryBarPosition
        pickerView.categoryNames = categoryNames
        pickerView.excludeEmojis = excludeEmojis
        (options["searchPlaceholder"] as? String)?.let { pickerView.searchPlaceholder = it }
        (options["noResultsText"] as? String)?.let { pickerView.noResultsText = it }
        pickerView.applyCustomTheme(customTheme)
        pickerView.applyConfiguration()

        pickerView.onEmojiSelected = { data ->
            currentPromise?.resolve(Bundle().apply {
                putString("emoji", data["emoji"] as? String ?: "")
                putString("name", data["name"] as? String ?: "")
                putString("id", data["id"] as? String ?: "")
            })
            currentPromise = null
            dialog?.dismiss()
            dialog = null
        }
        pickerView.onSearchFocused = { hasFocus ->
            if (hasFocus) {
                bottomSheet.behavior.state = BottomSheetBehavior.STATE_EXPANDED
            } else {
                bottomSheet.behavior.state = BottomSheetBehavior.STATE_HALF_EXPANDED
            }
        }
        pickerView.onScrollIntentUp = {
            if (bottomSheet.behavior.state != BottomSheetBehavior.STATE_EXPANDED) {
                bottomSheet.behavior.state = BottomSheetBehavior.STATE_EXPANDED
            }
        }
        pickerView.onPullDownAtTopDrag = { distance ->
            updateSheetDrag(bottomSheet, distance)
        }
        pickerView.onPullDownAtTopRelease = { distance, velocity ->
            finishSheetDrag(bottomSheet, distance, velocity)
        }

        // Drag handle
        val handleBar = View(activity).apply {
            val width = (40 * density).toInt()
            val height = (4 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(width, height).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                topMargin = (8 * density).toInt()
                bottomMargin = (4 * density).toInt()
            }
            background = GradientDrawable().apply {
                setColor(handleColor)
                cornerRadius = height / 2f
            }
        }

        // Container
        val halfExpandedRatio = snapPoints.firstOrNull()?.toFloat() ?: 0.55f
        val minSheetHeight = (activity.resources.displayMetrics.heightPixels * halfExpandedRatio).toInt()
        val cornerRadius = 16 * density
        val container = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            minimumHeight = minSheetHeight
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            background = GradientDrawable().apply {
                setColor(bgColor)
                cornerRadii = floatArrayOf(cornerRadius, cornerRadius, cornerRadius, cornerRadius, 0f, 0f, 0f, 0f)
            }
            clipToOutline = true
            outlineProvider = android.view.ViewOutlineProvider.BACKGROUND
            addView(handleBar)
            val pickerLp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f
            )
            addView(pickerView, pickerLp)
        }

        bottomSheet.setContentView(container)

        ViewCompat.setOnApplyWindowInsetsListener(container) { view, insets ->
            val imeInsets = insets.getInsets(WindowInsetsCompat.Type.ime())
            val systemBarInsets = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(
                systemBarInsets.left,
                0,
                systemBarInsets.right,
                maxOf(imeInsets.bottom, systemBarInsets.bottom)
            )
            WindowInsetsCompat.CONSUMED
        }

        // Strip ALL backgrounds from BottomSheet internals
        bottomSheet.setOnShowListener { dlg ->
            val d = dlg as BottomSheetDialog
            val bottomSheetInternal = d.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)
            bottomSheetContentView = bottomSheetInternal
            bottomSheetInternal?.apply {
                setBackgroundColor(Color.TRANSPARENT)
                (parent as? View)?.setBackgroundColor(Color.TRANSPARENT)
            }
            pickerView.loadDataAsync()
        }

        bottomSheet.window?.let { window ->
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
        bottomSheet.window?.setDimAmount(backdropOpacity)

        bottomSheet.behavior.apply {
            state = BottomSheetBehavior.STATE_HALF_EXPANDED
            this.halfExpandedRatio = halfExpandedRatio
            peekHeight = minSheetHeight
            isHideable = true
            skipCollapsed = false
            isFitToContents = false
            isDraggable = gestureEnabled
        }

        bottomSheet.setOnDismissListener {
            bottomSheetContentView = null
            isAnimatingClose = false
            currentPromise?.resolve(Bundle().apply { putBoolean("cancelled", true) })
            currentPromise = null
            dialog = null
        }

        currentPromise = promise
        dialog = bottomSheet
        bottomSheet.show()
    }

    private fun dismissSheet(cancelled: Boolean) {
        if (isAnimatingClose) {
            return
        }
        if (cancelled) {
            currentPromise?.resolve(Bundle().apply { putBoolean("cancelled", true) })
            currentPromise = null
        }
        bottomSheetContentView = null
        dialog?.dismiss()
        dialog = null
    }

    private fun updateSheetDrag(bottomSheet: BottomSheetDialog, distance: Float) {
        val sheetView = bottomSheetContentView
            ?: bottomSheet.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)
            ?: return

        if (bottomSheet.behavior.state != BottomSheetBehavior.STATE_EXPANDED) {
            return
        }

        sheetView.animate().cancel()
        sheetView.translationY = distance.coerceAtLeast(0f)
    }

    private fun finishSheetDrag(bottomSheet: BottomSheetDialog, distance: Float, velocityY: Float) {
        val sheetView = bottomSheetContentView
            ?: bottomSheet.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)
            ?: run {
                dismissSheet(cancelled = true)
                return
            }

        if (bottomSheet.behavior.state != BottomSheetBehavior.STATE_EXPANDED) {
            sheetView.translationY = 0f
            return
        }

        val dismissalThreshold = (sheetView.height * 0.42f).takeIf { it > 0f }
            ?: (sheetView.resources.displayMetrics.heightPixels * 0.42f)

        if (distance >= dismissalThreshold || velocityY >= 1400f) {
            animateSheetDismiss(bottomSheet)
            return
        }

        sheetView.animate()
            .translationY(0f)
            .setDuration(180)
            .setInterpolator(AccelerateDecelerateInterpolator())
            .start()
    }

    private fun animateSheetDismiss(bottomSheet: BottomSheetDialog) {
        if (isAnimatingClose) return

        val sheetView = bottomSheetContentView
            ?: bottomSheet.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)

        if (sheetView == null) {
            dismissSheet(cancelled = true)
            return
        }

        isAnimatingClose = true
        sheetView.animate().cancel()
        sheetView.animate()
            .translationY(sheetView.height.toFloat().takeIf { it > 0 } ?: sheetView.resources.displayMetrics.heightPixels.toFloat())
            .setDuration(220)
            .setInterpolator(AccelerateDecelerateInterpolator())
            .withEndAction {
                isAnimatingClose = false
                dismissSheet(cancelled = true)
            }
            .start()
    }

    private fun parseColor(hex: String?): Int? {
        if (hex == null) return null
        return try {
            Color.parseColor(hex)
        } catch (e: IllegalArgumentException) {
            null
        }
    }
}
