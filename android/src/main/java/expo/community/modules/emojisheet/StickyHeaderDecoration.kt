package expo.community.modules.emojisheet

import android.graphics.Canvas
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView

class StickyHeaderDecoration(
    private val adapter: EmojiGridAdapter,
    var backgroundColor: Int = 0
) : RecyclerView.ItemDecoration() {

    private var cachedHeaderPosition: Int = RecyclerView.NO_POSITION
    private var cachedHeaderView: View? = null
    private var cachedParentWidth: Int = 0

    override fun onDrawOver(c: Canvas, parent: RecyclerView, state: RecyclerView.State) {
        val topChild = parent.getChildAt(0) ?: return
        val topPosition = parent.getChildAdapterPosition(topChild)
        if (topPosition == RecyclerView.NO_POSITION) return

        val headerPosition = findHeaderPositionBefore(topPosition)
        if (headerPosition == RecyclerView.NO_POSITION) return

        val headerView = getHeaderView(parent, headerPosition)

        val nextHeaderPosition = findNextHeaderPosition(topPosition)
        if (nextHeaderPosition != RecyclerView.NO_POSITION) {
            val nextHeaderView = parent.findViewHolderForAdapterPosition(nextHeaderPosition)?.itemView
            if (nextHeaderView != null && nextHeaderView.top < headerView.height) {
                val offset = maxOf(0f, (nextHeaderView.top - headerView.height).toFloat())
                c.save()
                c.translate(0f, offset)
                headerView.draw(c)
                c.restore()
                return
            }
        }

        c.save()
        c.translate(0f, 0f)
        headerView.draw(c)
        c.restore()
    }

    private fun getHeaderView(parent: RecyclerView, position: Int): View {
        if (position == cachedHeaderPosition && cachedHeaderView != null && cachedParentWidth == parent.width) {
            return cachedHeaderView!!
        }
        val holder = adapter.createViewHolder(parent, EmojiGridAdapter.VIEW_TYPE_HEADER)
        adapter.bindViewHolder(holder, position)
        val view = holder.itemView
        if (backgroundColor != 0) {
            view.setBackgroundColor(backgroundColor)
        }
        fixLayoutSize(parent, view)
        cachedHeaderPosition = position
        cachedHeaderView = view
        cachedParentWidth = parent.width
        return view
    }

    fun invalidateCache() {
        cachedHeaderPosition = RecyclerView.NO_POSITION
        cachedHeaderView = null
    }

    private fun findHeaderPositionBefore(pos: Int): Int {
        for (i in pos downTo 0) {
            if (adapter.getItemViewType(i) == EmojiGridAdapter.VIEW_TYPE_HEADER) return i
        }
        return RecyclerView.NO_POSITION
    }

    private fun findNextHeaderPosition(pos: Int): Int {
        val count = adapter.itemCount
        for (i in (pos + 1) until count) {
            if (adapter.getItemViewType(i) == EmojiGridAdapter.VIEW_TYPE_HEADER) return i
        }
        return RecyclerView.NO_POSITION
    }

    private fun fixLayoutSize(parent: ViewGroup, view: View) {
        val widthSpec = View.MeasureSpec.makeMeasureSpec(parent.width, View.MeasureSpec.EXACTLY)
        val heightSpec = View.MeasureSpec.makeMeasureSpec(parent.height, View.MeasureSpec.UNSPECIFIED)
        view.measure(widthSpec, heightSpec)
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
    }
}
