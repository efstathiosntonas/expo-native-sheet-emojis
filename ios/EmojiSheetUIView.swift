import UIKit

// MARK: - Delegate Protocol

protocol EmojiSheetUIViewDelegate: AnyObject {
    func emojiSheetView(_ view: EmojiSheetUIView, didSelectEmoji data: [String: Any])
}

private enum FrequentlyUsedKeys {
    static let count = "count"
    static let dayStamp = "dayStamp"
    static let timestamp = "timestamp"
}

// MARK: - EmojiSheetUIView

class EmojiSheetUIView: UIView,
    EmojiSearchBarDelegate,
    EmojiCategoryStripDelegate,
    EmojiGridViewDelegate
{
    private enum LayoutConstants {
        static let searchBarTopSpacing: CGFloat = 24
        static let searchBarHorizontalInset: CGFloat = 12
        static let searchBarHeight: CGFloat = 40
        static let searchBarBottomSpacing: CGFloat = 8
        static let categoryStripHeight: CGFloat = 44
        static let floatingBarHorizontalInset: CGFloat = 16
        static let floatingBarBottomInset: CGFloat = 8
        static let floatingBarCornerRadius: CGFloat = 22
    }

    weak var delegate: EmojiSheetUIViewDelegate?
    var onEmojiSelected: (([String: Any]) -> Void)?
    var searchPlaceholder: String? {
        didSet { if let v = searchPlaceholder { searchBar.setPlaceholder(v) } }
    }
    var noResultsText: String? {
        didSet { if let v = noResultsText { emptyStateLabel.text = v } }
    }
    var onSearchFocusChanged: ((Bool) -> Void)?
    var onScrollIntentUp: (() -> Void)?
    var onPullDownAtTopDrag: ((CGFloat) -> Void)?
    var onPullDownAtTopRelease: ((CGFloat, CGFloat) -> Void)?

    // MARK: - Configurable Properties

    var columns: Int = 7 {
        didSet { gridView.columns = columns }
    }
    var emojiSize: CGFloat = 32 {
        didSet { gridView.emojiSize = emojiSize }
    }
    var showSearch: Bool = true {
        didSet { if showSearch != oldValue { configureLayout() } }
    }
    var showRecents: Bool = true
    var enableSkinTones: Bool = true {
        didSet { gridView.enableSkinTones = enableSkinTones }
    }
    var recentLimit: Int = 30
    var categoryBarPosition: String = "top" {
        didSet { if categoryBarPosition != oldValue { configureLayout() } }
    }
    var categoryNames: [String: String]?
    var excludeEmojis: Set<String> = []

    private var currentTheme: EmojiSheetTheme = .light
    private var allSections: [EmojiSection] = []
    private var filteredSections: [EmojiSection] = []
    private var frequentlyUsedSection: EmojiSection?
    private var localizedKeywords: [String: [String]] = [:]
    private var currentSearchText: String?
    // Search runs on a background queue to avoid blocking the UI while iterating
    // 1900+ emojis with keyword matching. The generation counter ensures stale
    // search results from previous keystrokes are discarded before updating the grid.
    private var searchGeneration: Int = 0

    private let searchBar = EmojiSearchBar()
    private let categoryStrip = EmojiCategoryStrip()
    private let gridView = EmojiGridView()
    private let emptyStateLabel = UILabel()

    // Bottom bar mode views
    private var bottomBarBlurView: UIVisualEffectView?
    private var isLayoutConfigured = false

    // Constraint references for dynamic layout
    private var searchBarTopConstraint: NSLayoutConstraint?
    private var categoryStripTopConstraint: NSLayoutConstraint?
    private var gridViewTopConstraint: NSLayoutConstraint?
    private var gridViewBottomConstraint: NSLayoutConstraint?
    private var categoryStripLeadingConstraint: NSLayoutConstraint?
    private var categoryStripTrailingConstraint: NSLayoutConstraint?
    private var categoryStripHeightConstraint: NSLayoutConstraint?
    private var categoryStripBottomConstraint: NSLayoutConstraint?

    private static let frequentlyUsedKey = "EmojiSheet_FrequentlyUsed"

    private static let categoryDisplayNames: [String: String] = [
        "smileys_emotion": "Smileys & Emotion",
        "people_body": "People & Body",
        "animals_nature": "Animals & Nature",
        "food_drink": "Food & Drink",
        "travel_places": "Travel & Places",
        "activities": "Activities",
        "objects": "Objects",
        "symbols": "Symbols",
        "flags": "Flags",
        "frequently_used": "Frequently Used",
    ]

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        categoryStrip.translatesAutoresizingMaskIntoConstraints = false
        gridView.translatesAutoresizingMaskIntoConstraints = false

        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.text = "No emojis found"
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.font = .systemFont(ofSize: 16)
        emptyStateLabel.isHidden = true

        addSubview(searchBar)
        addSubview(gridView)
        addSubview(emptyStateLabel)
        addSubview(categoryStrip)

        searchBar.delegate = self
        categoryStrip.delegate = self
        gridView.delegate = self

        configureLayout()
    }

    private func configureLayout() {
        // Remove old dynamic constraints
        [searchBarTopConstraint, categoryStripTopConstraint, gridViewTopConstraint,
         gridViewBottomConstraint, categoryStripLeadingConstraint, categoryStripTrailingConstraint,
         categoryStripHeightConstraint, categoryStripBottomConstraint].compactMap { $0 }.forEach {
            $0.isActive = false
        }

        // Remove old bottom bar blur + shadow wrapper if present
        bottomBarBlurView?.superview?.removeFromSuperview()
        bottomBarBlurView = nil

        // Search bar visibility
        searchBar.isHidden = !showSearch

        let isBottomBar = categoryBarPosition == "bottom"

        // Always set these constraints for searchBar
        let searchBarLeading = searchBar.leadingAnchor.constraint(
            equalTo: leadingAnchor, constant: LayoutConstants.searchBarHorizontalInset)
        let searchBarTrailing = searchBar.trailingAnchor.constraint(
            equalTo: trailingAnchor, constant: -LayoutConstants.searchBarHorizontalInset)
        let searchBarHeight = searchBar.heightAnchor.constraint(
            equalToConstant: LayoutConstants.searchBarHeight)

        // Empty state
        let emptyTop = emptyStateLabel.topAnchor.constraint(equalTo: gridView.topAnchor, constant: 40)
        let emptyLeading = emptyStateLabel.leadingAnchor.constraint(equalTo: leadingAnchor)
        let emptyTrailing = emptyStateLabel.trailingAnchor.constraint(equalTo: trailingAnchor)

        if isBottomBar {
            // Bottom bar mode: floating pill with blur at bottom
            // Shadow wrapper (can't put shadow on clipsToBounds view)
            let shadowWrapper = UIView()
            shadowWrapper.translatesAutoresizingMaskIntoConstraints = false
            shadowWrapper.backgroundColor = .clear
            shadowWrapper.layer.shadowColor = UIColor.black.cgColor
            shadowWrapper.layer.shadowOpacity = 0.12
            shadowWrapper.layer.shadowRadius = 8
            shadowWrapper.layer.shadowOffset = CGSize(width: 0, height: 2)
            addSubview(shadowWrapper)

            let blurEffect = UIBlurEffect(style: currentTheme.backgroundColor.isLight ? .systemThinMaterial : .systemThinMaterialDark)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.translatesAutoresizingMaskIntoConstraints = false
            blurView.clipsToBounds = true
            blurView.layer.cornerRadius = LayoutConstants.floatingBarCornerRadius
            shadowWrapper.addSubview(blurView)
            bottomBarBlurView = blurView

            // Pin blur to shadow wrapper
            NSLayoutConstraint.activate([
                blurView.topAnchor.constraint(equalTo: shadowWrapper.topAnchor),
                blurView.leadingAnchor.constraint(equalTo: shadowWrapper.leadingAnchor),
                blurView.trailingAnchor.constraint(equalTo: shadowWrapper.trailingAnchor),
                blurView.bottomAnchor.constraint(equalTo: shadowWrapper.bottomAnchor),
            ])

            categoryStrip.removeFromSuperview()
            blurView.contentView.addSubview(categoryStrip)
            categoryStrip.translatesAutoresizingMaskIntoConstraints = false

            // Search bar at top
            searchBarTopConstraint = searchBar.topAnchor.constraint(
                equalTo: topAnchor, constant: LayoutConstants.searchBarTopSpacing)

            // Grid below search (or top if no search)
            if showSearch {
                gridViewTopConstraint = gridView.topAnchor.constraint(
                    equalTo: searchBar.bottomAnchor, constant: LayoutConstants.searchBarBottomSpacing)
            } else {
                gridViewTopConstraint = gridView.topAnchor.constraint(
                    equalTo: topAnchor, constant: LayoutConstants.searchBarTopSpacing)
            }

            gridViewBottomConstraint = gridView.bottomAnchor.constraint(equalTo: bottomAnchor)

            // Floating pill: inset from edges, above safe area
            let pillBottom = shadowWrapper.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -LayoutConstants.floatingBarBottomInset)
            let pillLeading = shadowWrapper.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: LayoutConstants.floatingBarHorizontalInset)
            let pillTrailing = shadowWrapper.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -LayoutConstants.floatingBarHorizontalInset)
            let pillHeight = shadowWrapper.heightAnchor.constraint(
                equalToConstant: LayoutConstants.categoryStripHeight)

            // Category strip fills the blur view
            categoryStripLeadingConstraint = categoryStrip.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor)
            categoryStripTrailingConstraint = categoryStrip.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor)
            categoryStripTopConstraint = categoryStrip.topAnchor.constraint(equalTo: blurView.contentView.topAnchor)
            categoryStripHeightConstraint = categoryStrip.heightAnchor.constraint(
                equalToConstant: LayoutConstants.categoryStripHeight)

            NSLayoutConstraint.activate([
                searchBarTopConstraint!, searchBarLeading, searchBarTrailing, searchBarHeight,
                gridViewTopConstraint!, gridViewBottomConstraint!,
                gridView.leadingAnchor.constraint(equalTo: leadingAnchor),
                gridView.trailingAnchor.constraint(equalTo: trailingAnchor),
                pillBottom, pillLeading, pillTrailing, pillHeight,
                categoryStripLeadingConstraint!, categoryStripTrailingConstraint!,
                categoryStripTopConstraint!, categoryStripHeightConstraint!,
                emptyTop, emptyLeading, emptyTrailing,
            ])

            // Bottom content inset so grid content scrolls above the floating bar
            let floatingBarTotalHeight = LayoutConstants.categoryStripHeight
                + LayoutConstants.floatingBarBottomInset * 2
            gridView.setBottomContentInset(floatingBarTotalHeight)

        } else {
            // Top bar mode (default)
            // Make sure categoryStrip is in self (not in blur)
            if categoryStrip.superview !== self {
                categoryStrip.removeFromSuperview()
                addSubview(categoryStrip)
                categoryStrip.translatesAutoresizingMaskIntoConstraints = false
            }

            gridView.setBottomContentInset(0)

            searchBarTopConstraint = searchBar.topAnchor.constraint(
                equalTo: topAnchor, constant: LayoutConstants.searchBarTopSpacing)

            if showSearch {
                categoryStripTopConstraint = categoryStrip.topAnchor.constraint(
                    equalTo: searchBar.bottomAnchor, constant: LayoutConstants.searchBarBottomSpacing)
            } else {
                categoryStripTopConstraint = categoryStrip.topAnchor.constraint(
                    equalTo: topAnchor, constant: LayoutConstants.searchBarTopSpacing)
            }

            categoryStripLeadingConstraint = categoryStrip.leadingAnchor.constraint(equalTo: leadingAnchor)
            categoryStripTrailingConstraint = categoryStrip.trailingAnchor.constraint(equalTo: trailingAnchor)
            categoryStripHeightConstraint = categoryStrip.heightAnchor.constraint(
                equalToConstant: LayoutConstants.categoryStripHeight)

            gridViewTopConstraint = gridView.topAnchor.constraint(equalTo: categoryStrip.bottomAnchor)
            gridViewBottomConstraint = gridView.bottomAnchor.constraint(equalTo: bottomAnchor)

            NSLayoutConstraint.activate([
                searchBarTopConstraint!, searchBarLeading, searchBarTrailing, searchBarHeight,
                categoryStripTopConstraint!, categoryStripLeadingConstraint!,
                categoryStripTrailingConstraint!, categoryStripHeightConstraint!,
                gridViewTopConstraint!, gridViewBottomConstraint!,
                gridView.leadingAnchor.constraint(equalTo: leadingAnchor),
                gridView.trailingAnchor.constraint(equalTo: trailingAnchor),
                emptyTop, emptyLeading, emptyTrailing,
            ])
        }

        isLayoutConfigured = true
    }

    // MARK: - Data Loading (cached across instances)

    // Emoji data + translation keywords are parsed once on a serial background queue
    // and cached for the app's lifetime. The serial queue prevents concurrent warmCache()
    // and loadDataAsync() from racing on the same static vars.
    private static let cacheQueue = DispatchQueue(label: "EmojiSheetCache")
    private static var cachedSections: [EmojiSection]?
    private static var cachedKeywords: [String: [String]]?
    static var hasCachedData: Bool { cacheQueue.sync { cachedSections != nil && cachedKeywords != nil } }

    static func warmCache() {
        cacheQueue.async {
            guard cachedSections == nil || cachedKeywords == nil else { return }
            let sections = parseEmojiJSON()
            let keywords = loadAllKeywords()
            cachedSections = sections
            cachedKeywords = keywords
        }
    }

    private static func loadAllKeywords() -> [String: [String]] {
        let bundle = Bundle(for: EmojiSheetUIView.self)
        var merged: [String: [String]] = [:]

        // Translation files are copied into ios/translations/ by the config plugin.
        // The podspec bundles translations/*.json into the module's resource bundle.
        // CocoaPods may copy them flat (root level) or preserve the subdirectory.
        // We check both locations.

        // 1. Check translations/ subdirectory
        if let translationsURL = bundle.url(forResource: "translations", withExtension: nil) {
            if let urls = try? FileManager.default.contentsOfDirectory(at: translationsURL, includingPropertiesForKeys: nil)
                .filter({ $0.pathExtension == "json" }) {
                for url in urls {
                    Self.mergeKeywords(from: url, into: &merged)
                }
            }
        }

        // 2. Fallback: check flat bundle root for known locale files
        if merged.isEmpty {
            let locales = ["ca", "cs", "de", "el", "en", "es", "fi", "fr", "hi", "hu",
                           "it", "ja", "ko", "nl", "pl", "pt", "ru", "sv", "tr", "uk", "zh"]
            for locale in locales {
                if let url = bundle.url(forResource: locale, withExtension: "json") {
                    Self.mergeKeywords(from: url, into: &merged)
                }
            }
        }

        return merged
    }

    private static func mergeKeywords(from url: URL, into merged: inout [String: [String]]) {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
        else { return }
        for (key, value) in dict {
            if var existing = merged[key] {
                existing.append(contentsOf: value)
                merged[key] = existing
            } else {
                merged[key] = value
            }
        }
    }

    func loadDataAsync() {
        let cached = Self.cacheQueue.sync { (Self.cachedSections, Self.cachedKeywords) }
        if let sections = cached.0, let keywords = cached.1 {
            self.allSections = sections
            self.localizedKeywords = keywords
            self.rebuildSections(searchText: nil)
            return
        }

        Self.cacheQueue.async { [weak self] in
            guard let self else { return }
            let sections = Self.cachedSections ?? Self.parseEmojiJSON()
            let keywords = Self.cachedKeywords ?? Self.loadAllKeywords()
            Self.cachedSections = sections
            Self.cachedKeywords = keywords
            DispatchQueue.main.async {
                self.allSections = sections
                self.localizedKeywords = keywords
                self.rebuildSections(searchText: nil)
            }
        }
    }

    private static func maxSupportedEmojiVersion() -> Double {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        switch (osVersion.majorVersion, osVersion.minorVersion) {
        case (18, 4...): return 16.0
        case (18, _):    return 15.1
        case (17, 4...): return 15.1
        case (17, _):    return 15.0
        case (16, 4...): return 15.0
        case (16, _):    return 14.0
        case (15, 4...): return 14.0
        case (15, _):    return 13.1
        default:         return 13.1
        }
    }

    private static func parseEmojiJSON() -> [EmojiSection] {
        let bundle = Bundle(for: EmojiSheetUIView.self)
        guard let url = bundle.url(forResource: "emojis", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return []
        }

        let maxVersion = Self.maxSupportedEmojiVersion()
        return json.compactMap { sectionDict -> EmojiSection? in
            guard let title = sectionDict["title"] as? String,
                  let items = sectionDict["data"] as? [[String: Any]]
            else {
                return nil
            }
            let emojis = items.compactMap { item -> EmojiItem? in
                guard let emoji = item["emoji"] as? String,
                      let name = item["name"] as? String,
                      let v = item["v"] as? String,
                      let toneEnabled = item["toneEnabled"] as? Bool,
                      let keywords = item["keywords"] as? [String],
                      let id = item["id"] as? String
                else {
                    return nil
                }
                let emojiVersion = Double(v) ?? 0
                guard emojiVersion <= maxVersion else { return nil }
                return EmojiItem(emoji: emoji, name: name, version: v, toneEnabled: toneEnabled, keywords: keywords, id: id)
            }
            return EmojiSection(title: title, data: emojis)
        }
    }

    private func loadLocalizedKeywords() -> [String: [String]] {
        return Self.loadAllKeywords()
    }

    private var filteredAllSections: [EmojiSection] {
        guard !excludeEmojis.isEmpty else { return allSections }
        return allSections.map { section in
            EmojiSection(title: section.title, data: section.data.filter { !excludeEmojis.contains($0.id) })
        }.filter { !$0.data.isEmpty }
    }

    private var mergedCategoryNames: [String: String] {
        var names = Self.categoryDisplayNames
        if let custom = categoryNames {
            for (key, value) in custom {
                names[key] = value
            }
        }
        return names
    }

    private func rebuildSections(searchText: String?) {
        currentSearchText = searchText

        guard let search = searchText, !search.isEmpty else {
            searchGeneration += 1
            emptyStateLabel.isHidden = true
            gridView.isHidden = false
            var sections: [EmojiSection] = []
            if showRecents {
                let freq = loadFrequentlyUsed().filter { !excludeEmojis.contains($0.id) }
                if !freq.isEmpty {
                    sections.append(EmojiSection(title: "frequently_used", data: freq))
                }
            }
            sections.append(contentsOf: filteredAllSections)
            categoryStrip.setSearchActive(false)
            categoryStrip.updateCategories(sections.map { $0.title })
            filteredSections = sections
            gridView.updateSections(sections, categoryNames: mergedCategoryNames)
            // Scroll back to top after clearing search
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.gridView.scrollToTop()
            }
            return
        }

        categoryStrip.setSearchActive(true)
        searchGeneration += 1
        let generation = searchGeneration
        let sections = filteredAllSections
        let keywords = localizedKeywords

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let searchVariants = self.normalizedSearchVariants(search)
            var scored: [(item: EmojiItem, score: Int)] = []

            for section in sections {
                guard generation == self.searchGeneration else { return }
                for item in section.data {
                    let score = self.relevanceScore(
                        item: item,
                        searchVariants: searchVariants,
                        localizedKeywords: keywords
                    )
                    if score > 0 {
                        scored.append((item, score))
                    }
                }
            }

            // Sort by relevance score descending, then by original order for ties
            scored.sort { $0.score > $1.score }
            let matchedItems = scored.map { $0.item }

            guard generation == self.searchGeneration else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.searchGeneration else { return }
                var resultSections: [EmojiSection] = []
                if !matchedItems.isEmpty {
                    resultSections.append(EmojiSection(title: "search_results", data: matchedItems))
                }
                self.emptyStateLabel.isHidden = !matchedItems.isEmpty
                self.gridView.isHidden = matchedItems.isEmpty
                self.filteredSections = resultSections
                self.gridView.updateSections(resultSections, categoryNames: self.mergedCategoryNames)
                self.gridView.scrollToTop()
            }
        }
    }

    private static func localizedKeywordsForEmoji(_ emoji: String, in dict: [String: [String]]) -> [String] {
        if let kw = dict[emoji] { return kw }
        let stripped = String(emoji.unicodeScalars.filter { $0.value != 0xFE0E && $0.value != 0xFE0F })
        if stripped != emoji, let kw = dict[stripped] { return kw }
        return []
    }

    // Relevance scoring for search results:
    // 100 = exact name match, 90 = name starts with, 80 = exact keyword,
    // 70 = keyword starts with, 50 = name contains, 30 = keyword contains,
    // 10 = localized keyword contains. Returns 0 for no match.
    private func relevanceScore(
        item: EmojiItem,
        searchVariants: [String],
        localizedKeywords: [String: [String]]
    ) -> Int {
        let nameNorm = normalizeSearchText(item.name)

        // Check name
        for variant in searchVariants {
            if nameNorm == variant { return 100 }
            if nameNorm.hasPrefix(variant) { return 90 }
        }

        // Check built-in keywords
        var bestScore = 0
        for kw in item.keywords {
            let kwNorm = normalizeSearchText(kw)
            for variant in searchVariants {
                if kwNorm == variant { bestScore = max(bestScore, 80) }
                else if kwNorm.hasPrefix(variant) { bestScore = max(bestScore, 70) }
                else if kwNorm.contains(variant) { bestScore = max(bestScore, 30) }
            }
            if bestScore >= 80 { break }
        }

        // Check name contains (lower priority than keyword exact/startsWith)
        if bestScore < 50 {
            for variant in searchVariants {
                if nameNorm.contains(variant) { bestScore = max(bestScore, 50) }
            }
        }

        if bestScore > 0 { return bestScore }

        // Check localized keywords
        let localKw = Self.localizedKeywordsForEmoji(item.emoji, in: localizedKeywords)
        for kw in localKw {
            let kwNorm = normalizeSearchText(kw)
            if searchVariants.contains(where: { kwNorm.contains($0) }) { return 10 }
        }

        // Transliteration fallback for non-Latin scripts
        let nameVariants = normalizedSearchVariants(item.name)
        for nameVariant in nameVariants where nameVariant != nameNorm {
            if searchVariants.contains(where: { nameVariant.contains($0) }) { return 5 }
        }

        return 0
    }

    /// Fast path: checks pre-normalized text first, then falls back to transliteration-aware variants.
    private func matchesNormalized(_ normalizedText: String, originalText: String, searchVariants: [String]) -> Bool {
        if searchVariants.contains(where: normalizedText.contains) {
            return true
        }

        return normalizedSearchVariants(originalText)
            .contains { candidateVariant in
                candidateVariant != normalizedText &&
                    searchVariants.contains(where: { candidateVariant.contains($0) })
            }
    }

    // MARK: - Frequently Used

    private func loadFrequentlyUsed() -> [EmojiItem] {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.frequentlyUsedKey) as? [String: [String: Any]] else {
            return []
        }

        let allEmojis = allSections.flatMap { $0.data }
        let emojiLookup = Dictionary(allEmojis.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let sorted = dict.sorted { a, b in
            let dayA = a.value[FrequentlyUsedKeys.dayStamp] as? Double ?? 0
            let dayB = b.value[FrequentlyUsedKeys.dayStamp] as? Double ?? 0
            if dayA != dayB { return dayA > dayB }

            let timeA = a.value[FrequentlyUsedKeys.timestamp] as? Double ?? 0
            let timeB = b.value[FrequentlyUsedKeys.timestamp] as? Double ?? 0
            if timeA != timeB { return timeA > timeB }
            return a.key < b.key
        }

        return sorted.prefix(recentLimit).compactMap { id, _ in
            emojiLookup[id]
        }
    }

    private func recordEmojiUsage(_ item: EmojiItem) {
        var dict = (UserDefaults.standard.dictionary(forKey: Self.frequentlyUsedKey) as? [String: [String: Any]]) ?? [:]
        let existing = dict[item.id]
        let count = (existing?[FrequentlyUsedKeys.count] as? Int ?? 0) + 1
        let now = Date()
        let dayStamp = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        dict[item.id] = [
            FrequentlyUsedKeys.count: count,
            FrequentlyUsedKeys.dayStamp: dayStamp,
            FrequentlyUsedKeys.timestamp: now.timeIntervalSince1970,
        ]
        UserDefaults.standard.set(dict, forKey: Self.frequentlyUsedKey)
    }

    private func normalizeSearchText(_ text: String) -> String {
        text
            .precomposedStringWithCompatibilityMapping
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                locale: .current
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: .current)
    }

    private func normalizedSearchVariants(_ text: String) -> [String] {
        let normalized = normalizeSearchText(text)
        let transliterated = text.applyingTransform(.toLatin, reverse: false)
            .map(normalizeSearchText)

        return Array(
            Set(
                [normalized, transliterated]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
            )
        )
    }

    // MARK: - Theme

    func updateTheme(_ theme: String) {
        currentTheme = theme == "dark" ? .dark : .light
        applyCurrentTheme()
    }

    func applyCustomTheme(_ theme: EmojiSheetTheme) {
        currentTheme = theme
        applyCurrentTheme()
    }

    private func applyCurrentTheme() {
        backgroundColor = currentTheme.backgroundColor
        searchBar.applyTheme(currentTheme)
        categoryStrip.applyTheme(currentTheme)
        gridView.applyTheme(currentTheme)
        emptyStateLabel.textColor = currentTheme.textSecondaryColor
    }

    // MARK: - EmojiSearchBarDelegate

    func searchBar(_ searchBar: EmojiSearchBar, didChangeText text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        rebuildSections(searchText: trimmedText.isEmpty ? nil : trimmedText)
    }

    func searchBarDidBeginEditing(_ searchBar: EmojiSearchBar) {
        onSearchFocusChanged?(true)
        if categoryBarPosition == "bottom" {
            bottomBarBlurView?.superview?.isHidden = true
        }
    }

    func searchBarDidEndEditing(_ searchBar: EmojiSearchBar) {
        onSearchFocusChanged?(false)
        if categoryBarPosition == "bottom" {
            bottomBarBlurView?.superview?.isHidden = false
        }
    }

    // MARK: - EmojiCategoryStripDelegate

    func categoryStrip(_ strip: EmojiCategoryStrip, didSelectCategoryAt index: Int) {
        gridView.scrollToSection(index)
    }

    // MARK: - EmojiGridViewDelegate

    func gridView(_ gridView: EmojiGridView, didSelectEmoji emoji: String, item: EmojiItem) {
        recordEmojiUsage(item)
        rebuildSections(searchText: currentSearchText)
        let data: [String: Any] = [
            "emoji": emoji,
            "name": item.name,
            "id": item.id,
        ]
        delegate?.emojiSheetView(self, didSelectEmoji: data)
        onEmojiSelected?(data)
    }

    func gridView(_ gridView: EmojiGridView, didScrollToSectionAt index: Int) {
        categoryStrip.selectCategory(at: index)
    }

    func gridViewDidRequestSheetExpansion(_ gridView: EmojiGridView) {
        onScrollIntentUp?()
    }

    func gridView(_ gridView: EmojiGridView, didDragSheetDown distance: CGFloat) {
        onPullDownAtTopDrag?(distance)
    }

    func gridView(_ gridView: EmojiGridView, didReleaseSheetDown distance: CGFloat, velocity: CGFloat) {
        onPullDownAtTopRelease?(distance, velocity)
    }
}

// MARK: - UIColor brightness helper

private extension UIColor {
    var isLight: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            var white: CGFloat = 0
            return getWhite(&white, alpha: &alpha) ? white > 0.5 : true
        }
        let brightness = ((red * 299) + (green * 587) + (blue * 114)) / 1000
        return brightness > 0.5
    }
}
