package expo.community.modules.emojisheet

import android.graphics.Color
import android.graphics.Typeface
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.appcompat.widget.AppCompatTextView
import androidx.recyclerview.widget.RecyclerView

class EmojiGridAdapter(
    private var theme: EmojiSheetTheme,
    private val onEmojiClick: (emoji: String, emojiId: String) -> Unit,
    private val onEmojiLongPress: (view: View, baseEmoji: String, emojiId: String) -> Unit
) : RecyclerView.Adapter<RecyclerView.ViewHolder>() {

    companion object {
        const val VIEW_TYPE_HEADER = 0
        const val VIEW_TYPE_EMOJI = 1
    }

    var spanCount: Int = 7
    var emojiTextSize: Float = 32f
    var enableSkinTones: Boolean = true
    var enableHaptics: Boolean = true
    var enableAnimations: Boolean = false

    sealed class ListItem {
        data class Header(val title: String, val categoryKey: String) : ListItem()
        data class Emoji(
            val emoji: String,
            val name: String,
            val toneEnabled: Boolean,
            val keywords: List<String>,
            val id: String
        ) : ListItem()
    }

    private var items: List<ListItem> = emptyList()
    private var sectionPositions: List<Int> = emptyList()

    fun setItems(newItems: List<ListItem>, sections: List<Int>) {
        items = newItems
        sectionPositions = sections
        notifyDataSetChanged()
    }

    fun getSectionPositions(): List<Int> = sectionPositions

    fun updateTheme(newTheme: EmojiSheetTheme) {
        theme = newTheme
        notifyDataSetChanged()
    }

    override fun getItemViewType(position: Int): Int = when (items[position]) {
        is ListItem.Header -> VIEW_TYPE_HEADER
        is ListItem.Emoji -> VIEW_TYPE_EMOJI
    }

    override fun getItemCount(): Int = items.size

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val density = parent.context.resources.displayMetrics.density
        return when (viewType) {
            VIEW_TYPE_HEADER -> {
                val tv = TextView(parent.context).apply {
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                    typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                    gravity = Gravity.START or Gravity.CENTER_VERTICAL
                    textAlignment = View.TEXT_ALIGNMENT_VIEW_START
                    textDirection = View.TEXT_DIRECTION_LOCALE
                    val pad = (16 * density).toInt()
                    setPadding(pad, pad, pad, (8 * density).toInt())
                    layoutParams = RecyclerView.LayoutParams(
                        RecyclerView.LayoutParams.MATCH_PARENT,
                        RecyclerView.LayoutParams.WRAP_CONTENT
                    )
                }
                HeaderVH(tv)
            }
            else -> {
                val size = (48 * density).toInt()
                val container = FrameLayout(parent.context).apply {
                    layoutParams = RecyclerView.LayoutParams(
                        RecyclerView.LayoutParams.MATCH_PARENT,
                        size
                    )
                }
                val tv = AppCompatTextView(parent.context).apply {
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, emojiTextSize)
                    gravity = Gravity.CENTER
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                }
                container.addView(tv)
                EmojiVH(container, tv)
            }
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        when (val item = items[position]) {
            is ListItem.Header -> {
                val h = holder as HeaderVH
                h.textView.text = item.title
                h.textView.setTextColor(theme.textSecondaryColor)
                h.textView.contentDescription = item.title
            }
            is ListItem.Emoji -> {
                val h = holder as EmojiVH
                // Cancel any in-flight animation from a previous binding to prevent stale end-actions on recycled views
                h.container.animate().cancel()
                h.container.scaleX = 1f
                h.container.scaleY = 1f
                h.textView.text = item.emoji
                h.container.contentDescription = item.name
                h.textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, emojiTextSize)
                // Prevent theme text color from washing out color emojis
                h.textView.setTextColor(Color.BLACK)
                h.textView.alpha = 1.0f
                h.container.setOnClickListener { view ->
                    if (enableHaptics) {
                        view.performHapticFeedback(android.view.HapticFeedbackConstants.KEYBOARD_TAP)
                    }
                    if (enableAnimations) {
                        view.animate().cancel()
                        view.animate().scaleX(0.85f).scaleY(0.85f).setDuration(80).withEndAction {
                            view.animate().scaleX(1f).scaleY(1f).setDuration(80).start()
                        }.start()
                    }
                    onEmojiClick(item.emoji, item.id)
                }
                if (item.toneEnabled && enableSkinTones) {
                    h.container.setOnLongClickListener { view ->
                        onEmojiLongPress(h.container, item.emoji, item.id)
                        true
                    }
                } else {
                    h.container.setOnLongClickListener(null)
                    h.container.isLongClickable = false
                }
            }
        }
    }

    fun getCategoryIndexForPosition(position: Int): Int {
        if (sectionPositions.isEmpty()) return 0
        var catIndex = 0
        for (i in sectionPositions.indices) {
            if (sectionPositions[i] <= position) {
                catIndex = i
            } else {
                break
            }
        }
        return catIndex
    }

    class HeaderVH(val textView: TextView) : RecyclerView.ViewHolder(textView)
    class EmojiVH(val container: FrameLayout, val textView: AppCompatTextView) :
        RecyclerView.ViewHolder(container)
}
