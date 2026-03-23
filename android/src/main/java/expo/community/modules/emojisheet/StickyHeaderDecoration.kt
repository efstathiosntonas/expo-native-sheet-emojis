package expo.community.modules.emojisheet

import android.graphics.Canvas
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView

class StickyHeaderDecoration(
    private val adapter: EmojiGridAdapter,
    var backgroundColor: Int = 0
) : RecyclerView.ItemDecoration() {

    override fun onDrawOver(c: Canvas, parent: RecyclerView, state: RecyclerView.State) {
        val topChild = parent.getChildAt(0) ?: return
        val topPosition = parent.getChildAdapterPosition(topChild)
        if (topPosition == RecyclerView.NO_POSITION) return

        val headerPosition = findHeaderPositionBefore(topPosition)
        if (headerPosition == RecyclerView.NO_POSITION) return

        val headerView = createHeaderView(parent, headerPosition)
        fixLayoutSize(parent, headerView)

        val nextHeaderPosition = findNextHeaderPosition(topPosition)
        val contactPoint = headerView.bottom
        if (nextHeaderPosition != RecyclerView.NO_POSITION) {
            val nextHeaderView = parent.findViewHolderForAdapterPosition(nextHeaderPosition)?.itemView
            if (nextHeaderView != null && nextHeaderView.top < contactPoint) {
                c.save()
                c.translate(0f, (nextHeaderView.top - headerView.height).toFloat())
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

    private fun createHeaderView(parent: RecyclerView, position: Int): View {
        val holder = adapter.createViewHolder(parent, EmojiGridAdapter.VIEW_TYPE_HEADER)
        adapter.bindViewHolder(holder, position)
        if (backgroundColor != 0) {
            holder.itemView.setBackgroundColor(backgroundColor)
        }
        return holder.itemView
    }

    private fun fixLayoutSize(parent: ViewGroup, view: View) {
        val widthSpec = View.MeasureSpec.makeMeasureSpec(parent.width, View.MeasureSpec.EXACTLY)
        val heightSpec = View.MeasureSpec.makeMeasureSpec(parent.height, View.MeasureSpec.UNSPECIFIED)
        view.measure(widthSpec, heightSpec)
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
    }
}
