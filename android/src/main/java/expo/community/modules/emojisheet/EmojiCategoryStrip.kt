package expo.community.modules.emojisheet

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView

@SuppressLint("ViewConstructor")
class EmojiCategoryStrip(
    context: Context,
    private val categoryKeys: List<String>,
    private val onCategorySelected: (index: Int) -> Unit
) : LinearLayout(context) {

    companion object {
        private val ICON_MAP = mapOf(
            "frequently_used" to R.drawable.ic_category_recent,
            "smileys_emotion" to R.drawable.ic_category_smileys,
            "people_body" to R.drawable.ic_category_people,
            "animals_nature" to R.drawable.ic_category_nature,
            "food_drink" to R.drawable.ic_category_food,
            "travel_places" to R.drawable.ic_category_travel,
            "activities" to R.drawable.ic_category_activities,
            "objects" to R.drawable.ic_category_objects,
            "symbols" to R.drawable.ic_category_symbols,
            "flags" to R.drawable.ic_category_flags
        )
    }

    private val recyclerView: RecyclerView
    private val adapter: CategoryAdapter
    private var selectedIndex = 0
    private var currentTheme = EmojiSheetTheme.light
    private val dividerView: View

    init {
        orientation = VERTICAL
        val density = context.resources.displayMetrics.density

        recyclerView = RecyclerView(context).apply {
            layoutManager = LinearLayoutManager(context, LinearLayoutManager.HORIZONTAL, false)
            setHasFixedSize(true)
            overScrollMode = View.OVER_SCROLL_NEVER
            val rvLp = LayoutParams(LayoutParams.MATCH_PARENT, (44 * density).toInt())
            layoutParams = rvLp
        }

        adapter = CategoryAdapter()
        recyclerView.adapter = adapter

        addView(recyclerView)

        dividerView = View(context).apply {
            val divLp = LayoutParams(LayoutParams.MATCH_PARENT, 1)
            layoutParams = divLp
        }
        addView(dividerView)
    }

    fun setSelectedCategory(index: Int) {
        if (index == selectedIndex) return
        val old = selectedIndex
        selectedIndex = index
        adapter.notifyItemChanged(old)
        adapter.notifyItemChanged(index)
        recyclerView.smoothScrollToPosition(index)
    }

    fun applyTheme(theme: EmojiSheetTheme) {
        currentTheme = theme
        setBackgroundColor(theme.categoryBarBackgroundColor)
        dividerView.setBackgroundColor(theme.dividerColor)
        adapter.notifyDataSetChanged()
    }

    fun applyLayoutDirection(direction: Int) {
        layoutDirection = direction
        recyclerView.layoutDirection = direction
        dividerView.layoutDirection = direction
        recyclerView.adapter?.notifyDataSetChanged()
    }

    private inner class CategoryAdapter : RecyclerView.Adapter<CategoryAdapter.VH>() {

        inner class VH(val container: FrameLayout) : RecyclerView.ViewHolder(container) {
            val iconView: ImageView = container.getChildAt(0) as ImageView
            val bg: GradientDrawable = GradientDrawable()

            init {
                bg.shape = GradientDrawable.OVAL
                container.background = bg
            }
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val density = parent.context.resources.displayMetrics.density
            val size = (40 * density).toInt()
            val iconSize = (22 * density).toInt()
            val margin = (2 * density).toInt()

            val container = FrameLayout(parent.context).apply {
                val lp = RecyclerView.LayoutParams(size, size)
                lp.setMargins(margin, margin, margin, margin)
                layoutParams = lp
            }

            val icon = ImageView(parent.context).apply {
                scaleType = ImageView.ScaleType.FIT_CENTER
                val iconLp = FrameLayout.LayoutParams(iconSize, iconSize)
                iconLp.gravity = Gravity.CENTER
                layoutParams = iconLp
            }
            container.addView(icon)

            return VH(container)
        }

        override fun getItemCount(): Int = categoryKeys.size

        override fun onBindViewHolder(holder: VH, position: Int) {
            val key = categoryKeys[position]
            val drawableRes = ICON_MAP[key] ?: R.drawable.ic_category_smileys
            holder.iconView.setImageResource(drawableRes)

            val isSelected = position == selectedIndex
            val tint = if (isSelected) currentTheme.categoryActiveIconColor else currentTheme.categoryIconColor
            holder.iconView.imageTintList = ColorStateList.valueOf(tint)
            holder.bg.setColor(if (isSelected) currentTheme.categoryActiveBackgroundColor else 0x00000000)

            holder.container.contentDescription = EmojiData.displayName(key)

            holder.container.setOnClickListener {
                val pos = holder.bindingAdapterPosition
                if (pos != RecyclerView.NO_POSITION) {
                    val old = selectedIndex
                    selectedIndex = pos
                    notifyItemChanged(old)
                    notifyItemChanged(pos)
                    onCategorySelected(pos)
                }
            }
        }
    }
}
