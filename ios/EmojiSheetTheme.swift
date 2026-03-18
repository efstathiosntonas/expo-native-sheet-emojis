import UIKit

struct EmojiSheetTheme {
    let backgroundColor: UIColor
    let searchBarBackgroundColor: UIColor
    let textColor: UIColor
    let textSecondaryColor: UIColor
    let dividerColor: UIColor
    let accentColor: UIColor
    let categoryIconColor: UIColor
    let categoryActiveIconColor: UIColor
    let categoryActiveBackgroundColor: UIColor
    let handleColor: UIColor
    let categoryBarBackgroundColor: UIColor
    let searchTextColor: UIColor?
    let placeholderTextColor: UIColor?
    let selectionColor: UIColor?

    init(
        backgroundColor: UIColor,
        searchBarBackgroundColor: UIColor,
        textColor: UIColor,
        textSecondaryColor: UIColor,
        dividerColor: UIColor,
        accentColor: UIColor,
        categoryIconColor: UIColor,
        categoryActiveIconColor: UIColor? = nil,
        categoryActiveBackgroundColor: UIColor? = nil,
        handleColor: UIColor? = nil,
        categoryBarBackgroundColor: UIColor? = nil,
        searchTextColor: UIColor? = nil,
        placeholderTextColor: UIColor? = nil,
        selectionColor: UIColor? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.searchBarBackgroundColor = searchBarBackgroundColor
        self.textColor = textColor
        self.textSecondaryColor = textSecondaryColor
        self.dividerColor = dividerColor
        self.accentColor = accentColor
        self.categoryIconColor = categoryIconColor
        self.categoryActiveIconColor = categoryActiveIconColor ?? accentColor
        self.categoryActiveBackgroundColor = categoryActiveBackgroundColor ?? dividerColor
        self.handleColor = handleColor ?? UIColor(white: 0.72, alpha: 1)
        self.categoryBarBackgroundColor = categoryBarBackgroundColor ?? backgroundColor
        self.searchTextColor = searchTextColor
        self.placeholderTextColor = placeholderTextColor
        self.selectionColor = selectionColor
    }

    static let dark = EmojiSheetTheme(
        backgroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1),
        searchBarBackgroundColor: UIColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1),
        textColor: .white,
        textSecondaryColor: UIColor(white: 1, alpha: 0.6),
        dividerColor: UIColor(white: 1, alpha: 0.15),
        accentColor: UIColor(red: 0.918, green: 0.271, blue: 0.471, alpha: 1),
        categoryIconColor: UIColor(white: 1, alpha: 0.5),
        categoryActiveIconColor: UIColor(red: 0.918, green: 0.271, blue: 0.471, alpha: 1),
        categoryActiveBackgroundColor: UIColor(white: 1, alpha: 0.15),
        handleColor: UIColor(white: 0.5, alpha: 1),
        categoryBarBackgroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1)
    )

    static let light = EmojiSheetTheme(
        backgroundColor: .white,
        searchBarBackgroundColor: UIColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1),
        textColor: .black,
        textSecondaryColor: UIColor(white: 0, alpha: 0.5),
        dividerColor: UIColor(red: 0.878, green: 0.878, blue: 0.878, alpha: 1),
        accentColor: UIColor(red: 0.918, green: 0.271, blue: 0.471, alpha: 1),
        categoryIconColor: UIColor(white: 0, alpha: 0.4),
        categoryActiveIconColor: UIColor(red: 0.918, green: 0.271, blue: 0.471, alpha: 1),
        categoryActiveBackgroundColor: UIColor(red: 0.878, green: 0.878, blue: 0.878, alpha: 1),
        handleColor: UIColor(white: 0.72, alpha: 1),
        categoryBarBackgroundColor: .white
    )
}
