package expo.community.modules.emojisheet

data class EmojiSheetTheme(
    val backgroundColor: Int,
    val searchBarBackgroundColor: Int,
    val textColor: Int,
    val textSecondaryColor: Int,
    val dividerColor: Int,
    val accentColor: Int,
    val categoryIconColor: Int,
    val categoryActiveIconColor: Int,
    val categoryActiveBackgroundColor: Int,
    val handleColor: Int,
    val categoryBarBackgroundColor: Int,
    val searchTextColor: Int? = null,
    val placeholderTextColor: Int? = null,
    val selectionColor: Int? = null
) {
    companion object {
        val dark = create(
            backgroundColor = 0xFF1A1A2E.toInt(),
            searchBarBackgroundColor = 0xFF2A2F39.toInt(),
            textColor = 0xFFFFFFFF.toInt(),
            textSecondaryColor = 0x99FFFFFF.toInt(),
            dividerColor = 0x26FFFFFF.toInt(),
            accentColor = 0xFFEA4578.toInt(),
            categoryIconColor = 0x80FFFFFF.toInt(),
            handleColor = 0x66FFFFFF.toInt()
        )

        val light = create(
            backgroundColor = 0xFFFFFFFF.toInt(),
            searchBarBackgroundColor = 0xFFF0F0F0.toInt(),
            textColor = 0xFF000000.toInt(),
            textSecondaryColor = 0x80000000.toInt(),
            dividerColor = 0xFFE0E0E0.toInt(),
            accentColor = 0xFFEA4578.toInt(),
            categoryIconColor = 0x66000000.toInt(),
            handleColor = 0x33000000.toInt()
        )

        fun fromName(name: String): EmojiSheetTheme =
            if (name == "dark") dark else light

        fun create(
            backgroundColor: Int,
            searchBarBackgroundColor: Int,
            textColor: Int,
            textSecondaryColor: Int,
            dividerColor: Int,
            accentColor: Int,
            categoryIconColor: Int,
            categoryActiveIconColor: Int = accentColor,
            categoryActiveBackgroundColor: Int = dividerColor,
            handleColor: Int = 0x33000000,
            categoryBarBackgroundColor: Int = backgroundColor,
            searchTextColor: Int? = null,
            placeholderTextColor: Int? = null,
            selectionColor: Int? = null
        ): EmojiSheetTheme = EmojiSheetTheme(
            backgroundColor = backgroundColor,
            searchBarBackgroundColor = searchBarBackgroundColor,
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
    }
}
