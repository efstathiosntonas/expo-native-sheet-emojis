package expo.community.modules.emojisheet

import android.annotation.SuppressLint
import android.content.Context
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.viewevent.EventDispatcher
import expo.modules.kotlin.views.ExpoView

@SuppressLint("ViewConstructor")
class EmojiSheetContentView(
    context: Context,
    appContext: AppContext
) : ExpoView(context, appContext) {

    private val onEmojiSelected by EventDispatcher()
    private val pickerView = EmojiSheetUIView(context)

    init {
        pickerView.layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        pickerView.onEmojiSelected = { data ->
            onEmojiSelected(data)
        }
        addView(pickerView)
        pickerView.loadDataAsync()
    }

    fun applyConfiguration() {
        pickerView.applyConfiguration()
    }

    fun updateTheme(theme: String) {
        pickerView.updateTheme(theme)
    }

    fun updateCategoryBarPosition(position: String) {
        pickerView.categoryBarPosition = position
        pickerView.applyConfiguration()
    }

    fun updateColumns(columns: Int) {
        pickerView.columns = columns
        pickerView.applyConfiguration()
    }

    fun updateEmojiSize(size: Float) {
        pickerView.emojiSize = size
        pickerView.applyConfiguration()
    }

    fun updateRecentLimit(limit: Int) {
        pickerView.recentLimit = limit
    }

    fun updateShowSearch(show: Boolean) {
        pickerView.showSearch = show
    }

    fun updateShowRecents(show: Boolean) {
        pickerView.showRecents = show
    }

    fun updateEnableSkinTones(enable: Boolean) {
        pickerView.enableSkinTones = enable
    }

    fun updateEnableHaptics(enable: Boolean) {
        pickerView.enableHaptics = enable
    }

    fun updateSearchPlaceholder(text: String) {
        pickerView.searchPlaceholder = text
    }

    fun updateNoResultsText(text: String) {
        pickerView.noResultsText = text
    }

    fun updateCategoryNames(names: Map<String, String>) {
        pickerView.categoryNames = names
    }

    fun updateExcludeEmojis(ids: List<String>) {
        pickerView.excludeEmojis = ids.toSet()
    }
}
