import UIKit

class EmojiSkinTonePicker: UIView {
    var onEmojiSelected: ((_ emoji: String, _ modifier: String?) -> Void)?

    private let baseEmoji: String
    private let emojiId: String
    private var buttons: [UIButton] = []

    private static let skinToneModifiers: [String] = [
        "\u{1F3FB}", "\u{1F3FC}", "\u{1F3FD}", "\u{1F3FE}", "\u{1F3FF}",
    ]

    init(baseEmoji: String, emojiId: String, theme: EmojiSheetTheme) {
        self.baseEmoji = baseEmoji
        self.emojiId = emojiId
        super.init(frame: .zero)
        setupViews(theme: theme)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews(theme: EmojiSheetTheme) {
        backgroundColor = theme.searchBarBackgroundColor
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)

        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.spacing = 2
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])

        // Base emoji (no modifier)
        let baseButton = createButton(emoji: baseEmoji, tag: 0)
        stackView.addArrangedSubview(baseButton)
        buttons.append(baseButton)

        // Skin tone variants
        for (index, modifier) in Self.skinToneModifiers.enumerated() {
            let toned = EmojiGridView.applyingSkinTone(modifier, to: baseEmoji)
            let button = createButton(emoji: toned, tag: index + 1)
            stackView.addArrangedSubview(button)
            buttons.append(button)
        }

        // Highlight saved selection
        if let savedTone = UserDefaults.standard.string(forKey: "EmojiSkinTone_\(emojiId)"),
           let savedIndex = Self.skinToneModifiers.firstIndex(of: savedTone)
        {
            highlightButton(at: savedIndex + 1, theme: theme)
        } else {
            highlightButton(at: 0, theme: theme)
        }
    }

    private func createButton(emoji: String, tag: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(emoji, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 28)
        button.tag = tag
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        button.layer.cornerRadius = 10
        return button
    }

    private func highlightButton(at index: Int, theme: EmojiSheetTheme) {
        guard index < buttons.count else { return }
        buttons[index].backgroundColor = theme.accentColor.withAlphaComponent(0.25)
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        let tag = sender.tag
        if tag == 0 {
            // Base emoji, no modifier
            onEmojiSelected?(baseEmoji, nil)
        } else {
            let modifier = Self.skinToneModifiers[tag - 1]
            let toned = EmojiGridView.applyingSkinTone(modifier, to: baseEmoji)
            onEmojiSelected?(toned, modifier)
        }
    }
}
