package expo.community.modules.emojisheet

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.TextView
import androidx.appcompat.widget.AppCompatTextView

@SuppressLint("ViewConstructor")
class EmojiSkinTonePicker(
    private val context: Context,
    private val theme: EmojiSheetTheme,
    private val onToneSelected: (emoji: String) -> Unit
) {
    companion object {
        private const val PREFS_NAME = "emoji_sheet_skin_tones"

        fun getPrefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        fun getSavedTone(context: Context, emojiId: String): Int? {
            val prefs = getPrefs(context)
            val value = prefs.getInt(emojiId, -1)
            return if (value == -1) null else value
        }

        fun saveTone(context: Context, emojiId: String, toneCodePoint: Int) {
            getPrefs(context).edit().putInt(emojiId, toneCodePoint).apply()
        }
    }

    fun show(anchorView: View, baseEmoji: String, emojiId: String) {
        val density = context.resources.displayMetrics.density
        val cellSize = (44 * density).toInt()
        val padding = (8 * density).toInt()
        val cornerRadius = 12 * density
        val elevation = 8 * density

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(padding, padding, padding, padding)

            val bg = GradientDrawable().apply {
                setColor(theme.searchBarBackgroundColor)
                this.cornerRadius = cornerRadius
            }
            background = bg
        }

        // Base emoji (no tone)
        val variants = mutableListOf(baseEmoji to -1)
        for (tone in EmojiData.skinToneModifiers) {
            variants.add(EmojiData.applyTone(baseEmoji, tone) to tone)
        }

        val skinToneLabels = listOf(
            "Default skin tone",
            "Light skin tone",
            "Medium-light skin tone",
            "Medium skin tone",
            "Medium-dark skin tone",
            "Dark skin tone"
        )

        for ((index, pair) in variants.withIndex()) {
            val (variantEmoji, _) = pair
            val tv = AppCompatTextView(context).apply {
                text = variantEmoji
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(cellSize, cellSize)
                contentDescription = skinToneLabels[index]
                setOnClickListener(null) // set below after popup created
            }
            container.addView(tv)
        }

        val totalWidth = cellSize * variants.size + padding * 2
        val totalHeight = cellSize + padding * 2

        val popup = PopupWindow(container, totalWidth, totalHeight, true).apply {
            this.elevation = elevation
            isOutsideTouchable = true
            setBackgroundDrawable(null)
        }

        // Set click listeners now that popup exists
        for (i in 0 until container.childCount) {
            val (variantEmoji, toneCodePoint) = variants[i]
            (container.getChildAt(i) as View).setOnClickListener {
                if (toneCodePoint != -1) {
                    saveTone(context, emojiId, toneCodePoint)
                } else {
                    // Reset to base
                    getPrefs(context).edit().remove(emojiId).apply()
                }
                onToneSelected(variantEmoji)
                popup.dismiss()
            }
        }

        // Position above anchor
        val location = IntArray(2)
        anchorView.getLocationOnScreen(location)
        val xOff = -(totalWidth / 2) + (anchorView.width / 2)
        val yOff = -totalHeight - (4 * density).toInt()

        popup.showAsDropDown(anchorView, xOff, yOff)
    }
}
