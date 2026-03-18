import ExpoModulesCore
import UIKit

// MARK: - Data Models

struct EmojiItem {
    let emoji: String
    let name: String
    let version: String
    let toneEnabled: Bool
    let keywords: [String]
    let id: String
}

struct EmojiSection {
    let title: String
    var data: [EmojiItem]
}

// MARK: - Content View (ExpoView wrapper)

class EmojiSheetContentView: ExpoView, EmojiSheetUIViewDelegate {
    let onEmojiSelected = EventDispatcher()
    private let pickerView = EmojiSheetUIView()

    required init(appContext: AppContext? = nil) {
        super.init(appContext: appContext)
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        pickerView.delegate = self
        addSubview(pickerView)
        NSLayoutConstraint.activate([
            pickerView.topAnchor.constraint(equalTo: topAnchor),
            pickerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pickerView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        pickerView.loadDataAsync()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTheme(_ theme: String) {
        pickerView.updateTheme(theme)
    }

    func updateCategoryBarPosition(_ position: String) {
        pickerView.categoryBarPosition = position
    }

    func updateColumns(_ columns: Int) {
        pickerView.columns = columns
    }

    func updateEmojiSize(_ size: CGFloat) {
        pickerView.emojiSize = size
    }

    func updateRecentLimit(_ limit: Int) {
        pickerView.recentLimit = limit
    }

    func updateShowSearch(_ show: Bool) {
        pickerView.showSearch = show
    }

    func updateShowRecents(_ show: Bool) {
        pickerView.showRecents = show
    }

    func updateEnableSkinTones(_ enable: Bool) {
        pickerView.enableSkinTones = enable
    }

    func updateSearchPlaceholder(_ text: String) {
        pickerView.searchPlaceholder = text
    }

    func updateNoResultsText(_ text: String) {
        pickerView.noResultsText = text
    }

    func updateCategoryNames(_ names: [String: String]) {
        pickerView.categoryNames = names
    }

    func updateExcludeEmojis(_ ids: [String]) {
        pickerView.excludeEmojis = Set(ids)
    }

    // MARK: - EmojiSheetUIViewDelegate

    func emojiSheetView(_ view: EmojiSheetUIView, didSelectEmoji data: [String: Any]) {
        onEmojiSelected(data)
    }
}
