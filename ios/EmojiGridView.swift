import UIKit

protocol EmojiGridViewDelegate: AnyObject {
    func gridView(_ gridView: EmojiGridView, didSelectEmoji emoji: String, item: EmojiItem)
    func gridView(_ gridView: EmojiGridView, didScrollToSectionAt index: Int)
    func gridViewDidRequestSheetExpansion(_ gridView: EmojiGridView)
    func gridView(_ gridView: EmojiGridView, didDragSheetDown distance: CGFloat)
    func gridView(_ gridView: EmojiGridView, didReleaseSheetDown distance: CGFloat, velocity: CGFloat)
}

class EmojiGridView: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    weak var delegate: EmojiGridViewDelegate?

    var columns: Int = 7 {
        didSet { if columns != oldValue { rebuildLayout() } }
    }
    var emojiSize: CGFloat = 32
    var cellHeight: CGFloat = 48 {
        didSet { if cellHeight != oldValue { rebuildLayout() } }
    }
    var enableSkinTones: Bool = true
    var enableHaptics: Bool = true
    var enableAnimations: Bool = true

    private lazy var selectionFeedback = UISelectionFeedbackGenerator()
    private lazy var impactFeedbackMedium = UIImpactFeedbackGenerator(style: .medium)

    private var sections: [EmojiSection] = []
    private var categoryNames: [String: String] = [:]
    private var currentTheme: EmojiSheetTheme = .light
    private var collectionView: UICollectionView!
    private var skinTonePicker: EmojiSkinTonePicker?
    private var isScrollingProgrammatically = false
    private var lastContentOffsetY: CGFloat = 0
    private var didRequestSheetExpansionDuringDrag = false
    private var lastPullDownDragDistance: CGFloat = 0
    private var isHandlingTopPullDrag = false
    private let topPullActivationThreshold: CGFloat = 32
    private var topPullStartTranslationY: CGFloat?

    private static let skinToneModifiers: [String] = [
        "\u{1F3FB}", "\u{1F3FC}", "\u{1F3FD}", "\u{1F3FE}", "\u{1F3FF}",
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCollectionView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        collectionView.delaysContentTouches = false
        collectionView.showsVerticalScrollIndicator = true
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: "EmojiCell")
        collectionView.register(
            SectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "SectionHeader"
        )
        collectionView.keyboardDismissMode = .none
        addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        let cols = columns
        let height = cellHeight

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(cols)),
            heightDimension: .absolute(height)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(height)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 12, trailing: 8)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(32)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        header.pinToVisibleBounds = true
        section.boundarySupplementaryItems = [header]

        return UICollectionViewCompositionalLayout { _, _ in section }
    }

    private func rebuildLayout() {
        collectionView.setCollectionViewLayout(createLayout(), animated: false)
    }

    func updateSections(_ newSections: [EmojiSection], categoryNames: [String: String]) {
        self.sections = newSections
        self.categoryNames = categoryNames
        collectionView.reloadData()
    }

    func applyTheme(_ theme: EmojiSheetTheme) {
        currentTheme = theme
        collectionView.indicatorStyle = indicatorStyle(for: theme)
        collectionView.reloadData()
    }

    private func indicatorStyle(for theme: EmojiSheetTheme) -> UIScrollView.IndicatorStyle {
        let backgroundBrightness = theme.backgroundColor.resolvedColor(with: traitCollection).perceivedBrightness
        return backgroundBrightness < 0.5 ? .white : .black
    }

    func scrollToSection(_ index: Int) {
        guard index < sections.count else { return }
        isScrollingProgrammatically = true
        let indexPath = IndexPath(item: 0, section: index)
        if let attributes = collectionView.layoutAttributesForSupplementaryElement(
            ofKind: UICollectionView.elementKindSectionHeader,
            at: indexPath
        ) {
            let offset = CGPoint(x: 0, y: attributes.frame.origin.y - collectionView.contentInset.top)
            collectionView.setContentOffset(offset, animated: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isScrollingProgrammatically = false
        }
    }

    func scrollToTop() {
        let topOffset = CGPoint(x: 0, y: -collectionView.adjustedContentInset.top)
        collectionView.setContentOffset(topOffset, animated: false)
    }

    func setBottomContentInset(_ inset: CGFloat) {
        collectionView.contentInset.bottom = inset
        collectionView.verticalScrollIndicatorInsets.bottom = inset
    }

    // MARK: - Skin Tone Helpers

    static func applyingSkinTone(_ modifier: String, to emoji: String) -> String {
        var scalars = Array(emoji.unicodeScalars)
        if scalars.count >= 1 {
            let modifierScalar = modifier.unicodeScalars.first!
            // Insert skin tone modifier after the first scalar
            if scalars.count > 1 && scalars[1] == "\u{200D}" {
                // ZWJ sequence: insert before ZWJ
                scalars.insert(modifierScalar, at: 1)
            } else {
                scalars.insert(modifierScalar, at: 1)
            }
        }
        return String(String.UnicodeScalarView(scalars))
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].data.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCell", for: indexPath) as! EmojiCell
        let item = sections[indexPath.section].data[indexPath.item]

        // Check for persisted skin tone
        var displayEmoji = item.emoji
        if item.toneEnabled {
            if let savedTone = UserDefaults.standard.string(forKey: "EmojiSkinTone_\(item.id)") {
                displayEmoji = Self.applyingSkinTone(savedTone, to: item.emoji)
            }
        }

        cell.configure(emoji: displayEmoji, fontSize: emojiSize)
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = item.name
        cell.accessibilityTraits = .button

        // Add long press for tone-enabled emojis
        if enableSkinTones && item.toneEnabled {
            cell.enableLongPress { [weak self] in
                self?.showSkinTonePicker(for: item, at: indexPath)
            }
        } else {
            cell.disableLongPress()
        }

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "SectionHeader",
            for: indexPath
        ) as! SectionHeaderView
        let title = sections[indexPath.section].title
        let displayName = categoryNames[title] ?? title.replacingOccurrences(of: "_", with: " ").capitalized
        header.configure(title: displayName, theme: currentTheme)
        header.isAccessibilityElement = true
        header.accessibilityLabel = displayName
        return header
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if enableHaptics {
            selectionFeedback.selectionChanged()
        }
        if enableAnimations, let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.08, delay: 0, options: [.allowUserInteraction]) {
                cell.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            } completion: { _ in
                UIView.animate(withDuration: 0.08) {
                    cell.transform = .identity
                }
            }
        }
        let item = sections[indexPath.section].data[indexPath.item]
        var emoji = item.emoji
        if item.toneEnabled, let savedTone = UserDefaults.standard.string(forKey: "EmojiSkinTone_\(item.id)") {
            emoji = Self.applyingSkinTone(savedTone, to: item.emoji)
        }
        delegate?.gridView(self, didSelectEmoji: emoji, item: item)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isScrollingProgrammatically else { return }
        dismissSkinTonePicker()

        let currentOffsetY = scrollView.contentOffset.y
        let deltaY = currentOffsetY - lastContentOffsetY
        if scrollView.isDragging, deltaY > 2, !didRequestSheetExpansionDuringDrag {
            didRequestSheetExpansionDuringDrag = true
            delegate?.gridViewDidRequestSheetExpansion(self)
        }

        let topOffsetY = -scrollView.adjustedContentInset.top
        let downwardDrag = scrollView.panGestureRecognizer.translation(in: scrollView).y
        let isAtTop = currentOffsetY <= topOffsetY + 1
        if scrollView.isDragging, isHandlingTopPullDrag {
            scrollView.contentOffset.y = topOffsetY
            let baselineTranslation = topPullStartTranslationY ?? downwardDrag
            let dragDistance = max(0, downwardDrag - baselineTranslation)
            lastPullDownDragDistance = dragDistance
            delegate?.gridView(self, didDragSheetDown: dragDistance)
        } else if scrollView.isDragging,
                  isAtTop,
                  downwardDrag > topPullActivationThreshold
        {
            isHandlingTopPullDrag = true
            topPullStartTranslationY = downwardDrag
            scrollView.contentOffset.y = topOffsetY
            lastPullDownDragDistance = 0
            delegate?.gridView(self, didDragSheetDown: 0)
        } else if isHandlingTopPullDrag {
            lastPullDownDragDistance = 0
            delegate?.gridView(self, didDragSheetDown: 0)
        }

        lastContentOffsetY = currentOffsetY

        // Use a point just below the top of the visible area to determine the current section
        let probeY = collectionView.contentOffset.y + 80
        let probePoint = CGPoint(x: collectionView.bounds.midX, y: probeY)

        if let indexPath = collectionView.indexPathForItem(at: probePoint) {
            delegate?.gridView(self, didScrollToSectionAt: indexPath.section)
        } else {
            for section in (0..<sections.count).reversed() {
                let headerIndexPath = IndexPath(item: 0, section: section)
                if let attrs = collectionView.layoutAttributesForSupplementaryElement(
                    ofKind: UICollectionView.elementKindSectionHeader,
                    at: headerIndexPath
                ), attrs.frame.origin.y <= collectionView.contentOffset.y + 60 {
                    delegate?.gridView(self, didScrollToSectionAt: section)
                    return
                }
            }
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastContentOffsetY = scrollView.contentOffset.y
        didRequestSheetExpansionDuringDrag = false
        lastPullDownDragDistance = 0
        isHandlingTopPullDrag = false
        topPullStartTranslationY = nil
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if isHandlingTopPullDrag {
            let releaseVelocity = scrollView.panGestureRecognizer.velocity(in: scrollView).y
            delegate?.gridView(self, didReleaseSheetDown: lastPullDownDragDistance, velocity: releaseVelocity)
            lastPullDownDragDistance = 0
            isHandlingTopPullDrag = false
        }
        topPullStartTranslationY = nil
        if !decelerate {
            didRequestSheetExpansionDuringDrag = false
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        didRequestSheetExpansionDuringDrag = false
        topPullStartTranslationY = nil
    }

    // MARK: - Skin Tone Picker

    private func showSkinTonePicker(for item: EmojiItem, at indexPath: IndexPath) {
        dismissSkinTonePicker()

        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        let cellFrameInSelf = collectionView.convert(cell.frame, to: self)

        if enableHaptics {
            impactFeedbackMedium.impactOccurred()
        }

        let picker = EmojiSkinTonePicker(
            baseEmoji: item.emoji,
            emojiId: item.id,
            theme: currentTheme
        )
        picker.enableHaptics = enableHaptics
        picker.onEmojiSelected = { [weak self] emoji, modifier in
            guard let self = self else { return }
            if let modifier = modifier {
                UserDefaults.standard.set(modifier, forKey: "EmojiSkinTone_\(item.id)")
            } else {
                UserDefaults.standard.removeObject(forKey: "EmojiSkinTone_\(item.id)")
            }
            self.collectionView.reloadItems(at: [indexPath])
            self.delegate?.gridView(self, didSelectEmoji: emoji, item: item)
            self.dismissSkinTonePicker()
        }

        addSubview(picker)
        picker.translatesAutoresizingMaskIntoConstraints = false

        let pickerWidth: CGFloat = 6 * 48 + 16
        let pickerHeight: CGFloat = 56

        var centerX = cellFrameInSelf.midX
        let halfWidth = pickerWidth / 2
        centerX = max(halfWidth + 4, min(bounds.width - halfWidth - 4, centerX))

        NSLayoutConstraint.activate([
            picker.centerXAnchor.constraint(equalTo: leadingAnchor, constant: centerX),
            picker.bottomAnchor.constraint(equalTo: topAnchor, constant: cellFrameInSelf.minY - 4),
            picker.widthAnchor.constraint(equalToConstant: pickerWidth),
            picker.heightAnchor.constraint(equalToConstant: pickerHeight),
        ])

        skinTonePicker = picker

        picker.alpha = 0
        picker.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            picker.alpha = 1
            picker.transform = .identity
        }
    }

    private func dismissSkinTonePicker() {
        guard let picker = skinTonePicker else { return }
        skinTonePicker = nil
        UIView.animate(withDuration: 0.15, animations: {
            picker.alpha = 0
            picker.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            picker.removeFromSuperview()
        }
    }
}

private extension UIColor {
    var perceivedBrightness: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            var white: CGFloat = 0
            return getWhite(&white, alpha: &alpha) ? white : 1
        }

        return ((red * 299) + (green * 587) + (blue * 114)) / 1000
    }
}

// MARK: - Emoji Cell

private class EmojiCell: UICollectionViewCell {
    private let emojiLabel = UILabel()
    private var longPressAction: (() -> Void)?
    private var longPressGesture: UILongPressGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        emojiLabel.font = .systemFont(ofSize: 32)
        emojiLabel.textAlignment = .center
        contentView.addSubview(emojiLabel)
        NSLayoutConstraint.activate([
            emojiLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(emoji: String, fontSize: CGFloat = 32) {
        emojiLabel.text = emoji
        emojiLabel.font = .systemFont(ofSize: fontSize)
    }

    func enableLongPress(action: @escaping () -> Void) {
        longPressAction = action
        if longPressGesture == nil {
            let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            gesture.minimumPressDuration = 0.5
            contentView.addGestureRecognizer(gesture)
            longPressGesture = gesture
        }
    }

    func disableLongPress() {
        longPressAction = nil
        if let gesture = longPressGesture {
            contentView.removeGestureRecognizer(gesture)
            longPressGesture = nil
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            longPressAction?()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        emojiLabel.text = nil
        disableLongPress()
    }
}

// MARK: - Section Header

private class SectionHeaderView: UICollectionReusableView {
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 14, weight: .bold)
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, theme: EmojiSheetTheme) {
        titleLabel.text = title
        titleLabel.textColor = theme.textSecondaryColor
        backgroundColor = theme.backgroundColor
    }
}
