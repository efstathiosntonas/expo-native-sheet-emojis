import UIKit

protocol EmojiCategoryStripDelegate: AnyObject {
    func categoryStrip(_ strip: EmojiCategoryStrip, didSelectCategoryAt index: Int)
}

class EmojiCategoryStrip: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    weak var delegate: EmojiCategoryStripDelegate?

    private var currentTheme: EmojiSheetTheme = .light
    private var selectedIndex: Int = 0
    private var isSearchActive = false

    private static let sfSymbolForCategory: [String: String] = [
        "frequently_used": "clock.fill",
        "smileys_emotion": "face.smiling",
        "people_body": "hand.raised.fill",
        "animals_nature": "pawprint.fill",
        "food_drink": "fork.knife",
        "travel_places": "airplane",
        "activities": "sportscourt.fill",
        "objects": "lightbulb.fill",
        "symbols": "exclamationmark.circle",
        "flags": "flag.fill",
    ]

    private var categoryKeys: [String] = []

    private var collectionView: UICollectionView!
    private let dividerLine = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CategoryCell.self, forCellWithReuseIdentifier: "CategoryCell")
        addSubview(collectionView)

        dividerLine.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dividerLine)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: dividerLine.topAnchor),

            dividerLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            dividerLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            dividerLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            dividerLine.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    func updateCategories(_ keys: [String]) {
        categoryKeys = keys
        selectedIndex = 0
        reloadCategories()
    }

    func applyTheme(_ theme: EmojiSheetTheme) {
        currentTheme = theme
        backgroundColor = theme.categoryBarBackgroundColor
        dividerLine.backgroundColor = theme.dividerColor
        reloadCategories()
    }

    func applyLayoutDirection(_ attribute: UISemanticContentAttribute) {
        UIView.performWithoutAnimation {
            semanticContentAttribute = attribute
            collectionView.semanticContentAttribute = attribute
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
        }
    }

    func selectCategory(at index: Int) {
        guard !isSearchActive, index != selectedIndex, index >= 0, index < categoryKeys.count else { return }
        selectedIndex = index
        reloadCategories()
        scrollToCategoryIfNeeded(at: index)
    }

    func setSearchActive(_ active: Bool) {
        isSearchActive = active
        reloadCategories()
    }

    private func reloadCategories() {
        UIView.performWithoutAnimation {
            collectionView.reloadData()
            collectionView.layoutIfNeeded()
        }
    }

    private func scrollToCategoryIfNeeded(at index: Int) {
        guard index >= 0, index < categoryKeys.count else { return }

        let indexPath = IndexPath(item: index, section: 0)
        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
            return
        }

        let visibleBounds = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)
        guard !visibleBounds.contains(attributes.frame) else {
            return
        }

        collectionView.scrollToItem(
            at: indexPath,
            at: .centeredHorizontally,
            animated: false
        )
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categoryKeys.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
        let key = categoryKeys[indexPath.item]
        let sfSymbol = Self.sfSymbolForCategory[key] ?? "questionmark.circle"
        let isSelected = !isSearchActive && indexPath.item == selectedIndex
        cell.configure(
            sfSymbol: sfSymbol,
            isSelected: isSelected,
            theme: currentTheme,
            categoryKey: key
        )
        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width / CGFloat(categoryKeys.count)
        return CGSize(width: max(width, 36), height: collectionView.bounds.height)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndex = indexPath.item
        isSearchActive = false
        reloadCategories()
        delegate?.categoryStrip(self, didSelectCategoryAt: indexPath.item)
    }
}

// MARK: - Category Cell

private class CategoryCell: UICollectionViewCell {
    private let circleView = UIView()
    private let iconView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        circleView.translatesAutoresizingMaskIntoConstraints = false
        circleView.layer.cornerRadius = 16
        contentView.addSubview(circleView)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        contentView.addSubview(iconView)

        NSLayoutConstraint.activate([
            circleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circleView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            circleView.widthAnchor.constraint(equalToConstant: 32),
            circleView.heightAnchor.constraint(equalToConstant: 32),

            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static let categoryDisplayNames: [String: String] = [
        "frequently_used": "Frequently Used",
        "smileys_emotion": "Smileys & Emotion",
        "people_body": "People & Body",
        "animals_nature": "Animals & Nature",
        "food_drink": "Food & Drink",
        "travel_places": "Travel & Places",
        "activities": "Activities",
        "objects": "Objects",
        "symbols": "Symbols",
        "flags": "Flags",
    ]

    func configure(sfSymbol: String, isSelected: Bool, theme: EmojiSheetTheme, categoryKey: String) {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image = UIImage(systemName: sfSymbol, withConfiguration: config)
        iconView.tintColor = isSelected ? theme.categoryActiveIconColor : theme.categoryIconColor
        circleView.backgroundColor = isSelected ? theme.categoryActiveBackgroundColor : .clear

        isAccessibilityElement = true
        accessibilityLabel = Self.categoryDisplayNames[categoryKey] ?? categoryKey.replacingOccurrences(of: "_", with: " ").capitalized
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}
