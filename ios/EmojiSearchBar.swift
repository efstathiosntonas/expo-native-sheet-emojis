import UIKit

protocol EmojiSearchBarDelegate: AnyObject {
    func searchBar(_ searchBar: EmojiSearchBar, didChangeText text: String)
    func searchBarDidBeginEditing(_ searchBar: EmojiSearchBar)
    func searchBarDidEndEditing(_ searchBar: EmojiSearchBar)
}

class EmojiSearchBar: UIView, UITextFieldDelegate {
    weak var delegate: EmojiSearchBarDelegate?

    private let containerView = UIView()
    private let iconView = UIImageView()
    private let textField = UITextField()
    private let clearButton = UIButton(type: .system)
    private var debounceTimer: Timer?
    private var currentTheme: EmojiSheetTheme?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = 20
        containerView.clipsToBounds = true
        addSubview(containerView)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "magnifyingglass")
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .gray
        containerView.addSubview(iconView)

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Search emoji"
        textField.borderStyle = .none
        textField.font = .systemFont(ofSize: 16)
        textField.textAlignment = .natural
        textField.returnKeyType = .search
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        containerView.addSubview(textField)

        // Clear button (X) — hidden until text is entered
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        clearButton.tintColor = .gray
        clearButton.isHidden = true
        clearButton.accessibilityLabel = "Clear search"
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        containerView.addSubview(clearButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            clearButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            clearButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 28),
            clearButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    func applyTheme(_ theme: EmojiSheetTheme) {
        currentTheme = theme
        let searchTextColor = theme.searchTextColor ?? theme.textColor
        let placeholderColor = theme.placeholderTextColor ?? theme.textSecondaryColor

        containerView.backgroundColor = theme.searchBarBackgroundColor
        textField.textColor = searchTextColor
        textField.attributedPlaceholder = NSAttributedString(
            string: textField.placeholder ?? "Search emoji",
            attributes: [.foregroundColor: placeholderColor]
        )
        iconView.tintColor = placeholderColor
        clearButton.tintColor = placeholderColor
        textField.tintColor = theme.selectionColor
    }

    func applyLayoutDirection(_ attribute: UISemanticContentAttribute) {
        semanticContentAttribute = attribute
        containerView.semanticContentAttribute = attribute
        textField.semanticContentAttribute = attribute
        clearButton.semanticContentAttribute = attribute
        textField.textAlignment = .natural
    }

    @objc private func textFieldDidChange() {
        updateClearButtonVisibility()
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.searchBar(self, didChangeText: self.textField.text ?? "")
        }
    }

    @objc private func clearTapped() {
        textField.text = ""
        updateClearButtonVisibility()
        debounceTimer?.invalidate()
        delegate?.searchBar(self, didChangeText: "")
    }

    private func updateClearButtonVisibility() {
        let hasText = !(textField.text ?? "").isEmpty
        clearButton.isHidden = !hasText
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        delegate?.searchBarDidBeginEditing(self)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        delegate?.searchBarDidEndEditing(self)
    }

    func setPlaceholder(_ text: String) {
        textField.placeholder = text
        if let theme = currentTheme {
            let placeholderColor = theme.placeholderTextColor ?? theme.textSecondaryColor
            textField.attributedPlaceholder = NSAttributedString(
                string: text,
                attributes: [.foregroundColor: placeholderColor]
            )
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
