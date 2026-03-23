package expo.community.modules.emojisheet

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView

@SuppressLint("ViewConstructor")
class EmojiSearchBar(
    context: Context,
    private val onSearchChanged: (query: String) -> Unit,
    private val onFocusChanged: ((Boolean) -> Unit)? = null
) : FrameLayout(context) {

    private val searchIcon: ImageView
    private val editText: EditText
    private val clearButton: TextView
    private val background = GradientDrawable()
    private val handler = Handler(Looper.getMainLooper())
    private var pendingRunnable: Runnable? = null
    private var currentPlaceholderColor: Int = 0x80000000.toInt()

    init {
        val density = context.resources.displayMetrics.density
        val horizontalPadding = (12 * density).toInt()
        val verticalPadding = (8 * density).toInt()
        val barHeight = (40 * density).toInt()
        val margin = (12 * density).toInt()
        val cornerRadius = 20 * density
        val iconWidth = (22 * density).toInt()
        val clearSize = (18 * density).toInt()
        val clearMarginEnd = (8 * density).toInt()

        background.cornerRadius = cornerRadius
        setBackground(background)

        setPadding(horizontalPadding, 0, horizontalPadding, 0)

        val lp = LayoutParams(LayoutParams.MATCH_PARENT, barHeight)
        lp.setMargins(margin, verticalPadding, margin, verticalPadding)
        layoutParams = lp

        searchIcon = ImageView(context).apply {
            setImageResource(R.drawable.ic_search)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            val iconLp = LayoutParams(iconWidth, LayoutParams.MATCH_PARENT)
            layoutParams = iconLp
        }
        addView(searchIcon)

        // Clear button (X) — hidden until text is entered
        clearButton = TextView(context).apply {
            text = "\u2715"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            gravity = Gravity.CENTER
            visibility = View.GONE
            val clearLp = LayoutParams(clearSize, clearSize).apply {
                gravity = Gravity.CENTER_VERTICAL or Gravity.END
                marginEnd = clearMarginEnd
            }
            layoutParams = clearLp
            contentDescription = "Clear search"
            setOnClickListener {
                editText.setText("")
                updateClearButtonVisibility()
                pendingRunnable?.let { r -> handler.removeCallbacks(r) }
                onSearchChanged("")
            }
        }
        addView(clearButton)

        editText = EditText(context).apply {
            setBackgroundColor(0x00000000)
            hint = "Search emoji"
            setSingleLine(true)
            textDirection = View.TEXT_DIRECTION_LOCALE
            textAlignment = View.TEXT_ALIGNMENT_VIEW_START
            imeOptions = EditorInfo.IME_ACTION_SEARCH
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setPadding((4 * density).toInt(), 0, clearSize + clearMarginEnd, 0)
            val etLp = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            etLp.marginStart = iconWidth
            layoutParams = etLp
        }
        addView(editText)

        editText.setOnFocusChangeListener { _, hasFocus ->
            onFocusChanged?.invoke(hasFocus)
        }

        editText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                updateClearButtonVisibility()
                pendingRunnable?.let { handler.removeCallbacks(it) }
                val runnable = Runnable {
                    onSearchChanged(s?.toString()?.trim() ?: "")
                }
                pendingRunnable = runnable
                handler.postDelayed(runnable, 500)
            }
        })
    }

    private fun updateClearButtonVisibility() {
        val hasText = !editText.text.isNullOrEmpty()
        clearButton.visibility = if (hasText) View.VISIBLE else View.GONE
    }

    fun applyTheme(theme: EmojiSheetTheme) {
        val searchTextColor = theme.searchTextColor ?: theme.textColor
        val placeholderTextColor = theme.placeholderTextColor ?: theme.textSecondaryColor
        currentPlaceholderColor = placeholderTextColor

        background.setColor(theme.searchBarBackgroundColor)
        editText.setTextColor(searchTextColor)
        editText.setHintTextColor(placeholderTextColor)
        searchIcon.setColorFilter(placeholderTextColor)
        clearButton.setTextColor(placeholderTextColor)

        theme.selectionColor?.let { selectionColor ->
            editText.highlightColor = selectionColor
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                editText.textCursorDrawable?.mutate()?.setTint(selectionColor)
            }
        }
    }

    fun setHint(text: String) {
        editText.hint = text
    }

    fun clearSearch() {
        editText.setText("")
        updateClearButtonVisibility()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        pendingRunnable?.let { handler.removeCallbacks(it) }
    }
}
