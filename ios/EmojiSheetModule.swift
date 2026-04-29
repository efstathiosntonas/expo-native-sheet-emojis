import ExpoModulesCore
import UIKit

public class EmojiSheetModule: Module {
    private var overlayWindow: UIWindow?
    private var currentPromise: Promise?
    private weak var sheetViewController: SheetViewController?

    public func definition() -> ModuleDefinition {
        Name("EmojiSheet")

        Events("onSheetOpened")

        OnCreate {
            EmojiSheetUIView.warmCache()
        }

        AsyncFunction("present") { (options: [String: Any], promise: Promise) in
            self.presentSheet(options: options, promise: promise)
        }
        .runOnQueue(DispatchQueue.main)

        AsyncFunction("dismiss") {
            self.dismissSheet(cancelled: true)
        }
        .runOnQueue(DispatchQueue.main)

        AsyncFunction("clearRecents") {
            UserDefaults.standard.removeObject(forKey: "EmojiSheet_FrequentlyUsed")
        }

        AsyncFunction("clearSkinTonePreferences") {
            let defaults = UserDefaults.standard
            let allKeys = defaults.dictionaryRepresentation().keys
            for key in allKeys where key.hasPrefix("EmojiSkinTone_") {
                defaults.removeObject(forKey: key)
            }
        }

        View(EmojiSheetContentView.self) {
            Prop("theme") { (view, theme: String?) in
                let resolved: String
                if theme == "system" {
                    resolved = UITraitCollection.current.userInterfaceStyle == .dark ? "dark" : "light"
                } else {
                    resolved = theme ?? "light"
                }
                view.updateTheme(resolved)
            }
            Prop("categoryBarPosition") { (view, position: String?) in
                view.updateCategoryBarPosition(position ?? "top")
            }
            Prop("layoutDirection") { (view, direction: String?) in
                view.updateLayoutDirection(direction ?? "auto")
            }
            Prop("columns") { (view, columns: Int?) in
                view.updateColumns(columns ?? 7)
            }
            Prop("emojiSize") { (view, size: Double?) in
                view.updateEmojiSize(CGFloat(size ?? 32))
            }
            Prop("recentLimit") { (view, limit: Int?) in
                view.updateRecentLimit(limit ?? 30)
            }
            Prop("showSearch") { (view, show: Bool?) in
                view.updateShowSearch(show ?? true)
            }
            Prop("showRecents") { (view, show: Bool?) in
                view.updateShowRecents(show ?? true)
            }
            Prop("enableSkinTones") { (view, enable: Bool?) in
                view.updateEnableSkinTones(enable ?? true)
            }
            Prop("enableHaptics") { (view, enable: Bool?) in
                view.updateEnableHaptics(enable ?? true)
            }
            Prop("enableAnimations") { (view, enable: Bool?) in
                view.updateEnableAnimations(enable ?? false)
            }
            Prop("searchPlaceholder") { (view, text: String?) in
                if let text { view.updateSearchPlaceholder(text) }
            }
            Prop("noResultsText") { (view, text: String?) in
                if let text { view.updateNoResultsText(text) }
            }
            Prop("categoryNames") { (view, names: [String: String]?) in
                if let names { view.updateCategoryNames(names) }
            }
            Prop("excludeEmojis") { (view, ids: [String]?) in
                view.updateExcludeEmojis(ids ?? [])
            }
            Events("onEmojiSelected", "onDismiss", "onOpen")
        }
    }

    // MARK: - Presentation via dedicated UIWindow

    private func presentSheet(options: [String: Any], promise: Promise) {
        guard currentPromise == nil, sheetViewController == nil else {
            promise.resolve(["cancelled": true])
            return
        }

        if overlayWindow != nil {
            tearDownWindow()
        }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            promise.resolve(["cancelled": true])
            return
        }

        let themeString = options["theme"] as? String ?? "light"
        let isDark: Bool
        switch themeString {
        case "dark":
            isDark = true
        case "system":
            isDark = UITraitCollection.current.userInterfaceStyle == .dark
        default:
            isDark = false
        }

        // Parse new options
        let snapPoints = (options["snapPoints"] as? [Double]) ?? [0.5, 1.0]
        let columns = (options["columns"] as? Int) ?? 7
        let emojiSize = options["emojiSize"] as? Double ?? 32
        let showSearch = (options["showSearch"] as? Bool) ?? true
        let showRecents = (options["showRecents"] as? Bool) ?? true
        let enableSkinTones = (options["enableSkinTones"] as? Bool) ?? true
        let enableHaptics = (options["enableHaptics"] as? Bool) ?? true
        let enableAnimations = (options["enableAnimations"] as? Bool) ?? false
        let recentLimit = (options["recentLimit"] as? Int) ?? 30
        let gestureEnabled = (options["gestureEnabled"] as? Bool) ?? true
        let backdropOpacity = options["backdropOpacity"] as? Double ?? (isDark ? 0.4 : 0.22)
        let categoryBarPosition = (options["categoryBarPosition"] as? String) ?? "top"
        let layoutDirection = (options["layoutDirection"] as? String) ?? "auto"
        let categoryNames = options["categoryNames"] as? [String: String]
        let excludeEmojis = Set((options["excludeEmojis"] as? [String]) ?? [])

        // Resolve colors from options or defaults
        let bgColor = parseColor(options["backgroundColor"] as? String) ?? (isDark
            ? UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1)
            : .white)
        let searchBgColor = parseColor(options["searchBarBackgroundColor"] as? String) ?? (isDark
            ? UIColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1)
            : UIColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1))
        let searchTextColor = parseColor(options["searchTextColor"] as? String)
        let placeholderTextColor = parseColor(options["placeholderTextColor"] as? String)
        let selectionColor = parseColor(options["selectionColor"] as? String)
        let textColor = parseColor(options["textColor"] as? String) ?? (isDark ? .white : .black)
        let textSecondaryColor = parseColor(options["textSecondaryColor"] as? String) ?? (isDark
            ? UIColor(white: 1, alpha: 0.6)
            : UIColor(white: 0, alpha: 0.5))
        let accentColor = parseColor(options["accentColor"] as? String) ?? UIColor(red: 0.918, green: 0.271, blue: 0.471, alpha: 1)
        let dividerColor = parseColor(options["dividerColor"] as? String) ?? (isDark
            ? UIColor(white: 1, alpha: 0.15)
            : UIColor(red: 0.878, green: 0.878, blue: 0.878, alpha: 1))
        let categoryIconColor = parseColor(options["categoryIconColor"] as? String) ?? textSecondaryColor
        let categoryActiveIconColor = parseColor(options["categoryActiveIconColor"] as? String)
        let categoryActiveBackgroundColor = parseColor(options["categoryActiveBackgroundColor"] as? String)
        let handleColor = parseColor(options["handleColor"] as? String)
        let categoryBarBackgroundColor = parseColor(options["categoryBarBackgroundColor"] as? String)

        let customTheme = EmojiSheetTheme(
            backgroundColor: bgColor,
            searchBarBackgroundColor: searchBgColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            dividerColor: dividerColor,
            accentColor: accentColor,
            categoryIconColor: categoryIconColor,
            categoryActiveIconColor: categoryActiveIconColor,
            categoryActiveBackgroundColor: categoryActiveBackgroundColor,
            handleColor: handleColor,
            categoryBarBackgroundColor: categoryBarBackgroundColor,
            searchTextColor: searchTextColor,
            placeholderTextColor: placeholderTextColor,
            selectionColor: selectionColor
        )

        // Create a dedicated window above the main app window
        let backdropColor = UIColor.black.withAlphaComponent(backdropOpacity)

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .normal + 1
        window.backgroundColor = .clear

        // Build the emoji picker
        let pickerView = EmojiSheetUIView()
        if let sp = options["searchPlaceholder"] as? String { pickerView.searchPlaceholder = sp }
        if let nr = options["noResultsText"] as? String { pickerView.noResultsText = nr }
        pickerView.columns = columns
        pickerView.emojiSize = CGFloat(emojiSize)
        pickerView.showSearch = showSearch
        pickerView.showRecents = showRecents
        pickerView.enableSkinTones = enableSkinTones
        pickerView.enableHaptics = enableHaptics
        pickerView.enableAnimations = enableAnimations
        pickerView.recentLimit = recentLimit
        pickerView.categoryBarPosition = categoryBarPosition
        pickerView.layoutDirection = layoutDirection
        pickerView.categoryNames = categoryNames
        pickerView.excludeEmojis = excludeEmojis
        pickerView.applyCustomTheme(customTheme)
        pickerView.onEmojiSelected = { [weak self] data in
            self?.currentPromise?.resolve(data)
            self?.currentPromise = nil
            self?.dismissSheet(cancelled: false)
        }

        let sheetVC = SheetViewController(
            backdropColor: backdropColor,
            sheetBackgroundColor: bgColor,
            theme: customTheme
        )
        sheetVC.mediumDetentRatio = CGFloat(snapPoints.first ?? 0.5)
        sheetVC.gestureEnabled = gestureEnabled
        sheetVC.embedPickerView(pickerView)
        sheetVC.onAppear = { [weak self] in
            self?.sendEvent("onSheetOpened", [:])
        }
        sheetVC.onDismiss = { [weak self] in
            if let promise = self?.currentPromise {
                promise.resolve(["cancelled": true])
                self?.currentPromise = nil
            }
            self?.tearDownWindow()
        }

        self.currentPromise = promise
        self.overlayWindow = window
        self.sheetViewController = sheetVC

        window.rootViewController = sheetVC
        window.makeKeyAndVisible()

        // If data is cached, load before the entry animation (no flash).
        // Otherwise load right after the controller is visible.
        if EmojiSheetUIView.hasCachedData {
            pickerView.loadDataAsync()
        } else {
            DispatchQueue.main.async {
                pickerView.loadDataAsync()
            }
        }
    }

    private func dismissSheet(cancelled: Bool) {
        if cancelled, let promise = currentPromise {
            promise.resolve(["cancelled": true])
            currentPromise = nil
        }

        if let sheetViewController {
            sheetViewController.dismissSheet { [weak self] in
                self?.tearDownWindow()
            }
        } else {
            tearDownWindow()
        }
    }

    private func tearDownWindow() {
        sheetViewController = nil
        let overlay = overlayWindow
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0 !== overlay }?
            .makeKeyAndVisible()
    }

    private func parseColor(_ hex: String?) -> UIColor? {
        guard let hex = hex, hex.hasPrefix("#"), hex.count >= 7 else { return nil }
        let start = hex.index(hex.startIndex, offsetBy: 1)
        let hexColor = String(hex[start...])
        guard let rgb = UInt64(hexColor, radix: 16) else { return nil }
        let hasAlpha = hexColor.count == 8
        if hasAlpha {
            return UIColor(
                red: CGFloat((rgb >> 24) & 0xFF) / 255,
                green: CGFloat((rgb >> 16) & 0xFF) / 255,
                blue: CGFloat((rgb >> 8) & 0xFF) / 255,
                alpha: CGFloat(rgb & 0xFF) / 255
            )
        }
        return UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Sheet VC

private final class SheetViewController: UIViewController, UIGestureRecognizerDelegate {
    private enum Layout {
        static let backdropAlpha: CGFloat = 1
        static let dismissTranslationThreshold: CGFloat = 120
        static let dismissVelocityThreshold: CGFloat = 1200
        static let expandTranslationThreshold: CGFloat = 72
        static let collapseTranslationThreshold: CGFloat = 72
        static let expandVelocityThreshold: CGFloat = -400
        static let collapseVelocityThreshold: CGFloat = 700
        static let minimumMediumVisibleHeight: CGFloat = 360
        static let sheetCornerRadius: CGFloat = 16
        static let sheetTopInset: CGFloat = 8
        static let grabberHeight: CGFloat = 5
        static let grabberTopInset: CGFloat = 8
        static let grabberWidth: CGFloat = 40
        static let fullHeightPanActivationZone: CGFloat = 40
    }

    private enum Detent {
        case medium
        case large
    }

    var onAppear: (() -> Void)?
    var onDismiss: (() -> Void)?
    var mediumDetentRatio: CGFloat = 0.5
    var gestureEnabled: Bool = true

    private let backdropView = UIView()
    private let sheetContainerView = UIView()
    private let grabberView = UIView()
    private let contentContainerView = UIView()
    private let backdropColor: UIColor
    private let sheetBackgroundColor: UIColor
    private let theme: EmojiSheetTheme
    private var isAnimatingDismissal = false
    private var hasPresented = false
    private var hasPreparedInitialState = false
    private var currentDetent: Detent = .medium
    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var sheetBottomConstraint: NSLayoutConstraint?
    private var keyboardObserver: NSObjectProtocol?
    private var keyboardOverlap: CGFloat = 0
    private var isSearchFocused = false
    private var detentBeforeSearchFocus: Detent?

    init(backdropColor: UIColor, sheetBackgroundColor: UIColor, theme: EmojiSheetTheme) {
        self.backdropColor = backdropColor
        self.sheetBackgroundColor = sheetBackgroundColor
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let keyboardObserver {
            NotificationCenter.default.removeObserver(keyboardObserver)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        registerForKeyboardNotifications()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasPresented else { return }
        hasPresented = true

        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: 0.96,
            initialSpringVelocity: 0.2,
            options: [.curveEaseOut]
        ) {
            self.backdropView.alpha = Layout.backdropAlpha
            self.sheetContainerView.transform = self.transform(for: self.currentDetent)
        } completion: { [weak self] _ in
            self?.onAppear?()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if !hasPresented, !hasPreparedInitialState {
            hasPreparedInitialState = true
            backdropView.alpha = 0
            sheetContainerView.transform = transformForDismissal()
            return
        }

        guard hasPresented, !isAnimatingDismissal else { return }
        sheetContainerView.transform = transform(for: currentDetent)
    }

    func embedPickerView(_ embeddedView: UIView) {
        embeddedView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.addSubview(embeddedView)

        if let pickerView = embeddedView as? EmojiSheetUIView {
            pickerView.onSearchFocusChanged = { [weak self] focused in
                self?.setSearchFocused(focused)
            }
            pickerView.onScrollIntentUp = { [weak self] in
                self?.handleScrollIntentUp()
            }
            pickerView.onPullDownAtTopDrag = { [weak self] distance in
                self?.updateSheetDrag(distance)
            }
            pickerView.onPullDownAtTopRelease = { [weak self] distance, velocity in
                self?.finishSheetDrag(distance, velocity: velocity)
            }
        }

        NSLayoutConstraint.activate([
            embeddedView.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
            embeddedView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
            embeddedView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
            embeddedView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor),
        ])
    }

    func dismissSheet(completion: @escaping () -> Void) {
        guard !isAnimatingDismissal else { return }
        isAnimatingDismissal = true

        UIView.animate(
            withDuration: 0.22,
            delay: 0,
            options: [.curveEaseIn]
        ) {
            self.backdropView.alpha = 0
            self.sheetContainerView.transform = self.transformForDismissal()
        } completion: { _ in
            completion()
        }
    }

    private func setDetent(_ detent: Detent, animated: Bool) {
        currentDetent = detent

        let updates = {
            self.sheetContainerView.transform = self.transform(for: detent)
            self.backdropView.alpha = Layout.backdropAlpha
        }

        if animated {
            UIView.animate(
                withDuration: 0.22,
                delay: 0,
                usingSpringWithDamping: 0.94,
                initialSpringVelocity: 0.15,
                options: [.curveEaseOut]
            ) {
                updates()
            }
        } else {
            updates()
        }
    }

    private func registerForKeyboardNotifications() {
        keyboardObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleKeyboardNotification(notification)
        }
    }

    private func handleKeyboardNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        else {
            return
        }

        let endFrame = endFrameValue.cgRectValue
        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        let curveRaw = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        let animationOptions = UIView.AnimationOptions(rawValue: curveRaw << 16)
            .union(.beginFromCurrentState)

        let overlap = keyboardOverlap(for: endFrame)
        let targetDetent: Detent

        if overlap > 0, isSearchFocused {
            targetDetent = .large
        } else if overlap == 0, !isSearchFocused, let previousDetent = detentBeforeSearchFocus {
            targetDetent = previousDetent
        } else {
            targetDetent = currentDetent
        }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: animationOptions
        ) {
            self.keyboardOverlap = overlap
            self.sheetBottomConstraint?.constant = -overlap
            self.sheetContainerView.transform = self.transform(for: targetDetent)
            self.backdropView.alpha = Layout.backdropAlpha
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.currentDetent = targetDetent
            if overlap == 0, !self.isSearchFocused {
                self.detentBeforeSearchFocus = nil
            }
        }
    }

    private func keyboardOverlap(for endFrame: CGRect) -> CGFloat {
        let convertedFrame = view.convert(endFrame, from: nil)
        let overlap = view.bounds.maxY - convertedFrame.minY
        return max(0, overlap - view.safeAreaInsets.bottom)
    }

    private func setSearchFocused(_ focused: Bool) {
        isSearchFocused = focused

        if focused {
            if detentBeforeSearchFocus == nil {
                detentBeforeSearchFocus = currentDetent
            }
            setDetent(.large, animated: true)
        } else if keyboardOverlap == 0, let previousDetent = detentBeforeSearchFocus {
            detentBeforeSearchFocus = nil
            setDetent(previousDetent, animated: true)
        }
    }

    private func handleScrollIntentUp() {
        guard !isAnimatingDismissal, currentDetent != .large else { return }
        setDetent(.large, animated: true)
    }

    private func updateSheetDrag(_ distance: CGFloat) {
        guard !isAnimatingDismissal, currentDetent == .large else { return }
        let adjustedDistance = max(0, distance * 0.7)
        sheetContainerView.layer.removeAllAnimations()
        sheetContainerView.transform = CGAffineTransform(translationX: 0, y: adjustedDistance)
        let dismissalDistance = max(sheetContainerView.bounds.height, 1)
        let progress = min(adjustedDistance / dismissalDistance, 1)
        backdropView.alpha = Layout.backdropAlpha * (1 - progress * 0.5)
    }

    private func finishSheetDrag(_ distance: CGFloat, velocity: CGFloat) {
        guard !isAnimatingDismissal, currentDetent == .large else { return }

        let dismissalThreshold = max(sheetContainerView.bounds.height * 0.5, 1)
        let shouldDismiss = distance >= dismissalThreshold || velocity >= 1400
        if shouldDismiss {
            dismissSheet { [weak self] in
                self?.onDismiss?()
            }
            return
        }

        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.1,
            options: [.curveEaseOut]
        ) {
            self.sheetContainerView.transform = self.transform(for: .large)
            self.backdropView.alpha = Layout.backdropAlpha
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGestureRecognizer,
              let panGesture = gestureRecognizer as? UIPanGestureRecognizer
        else {
            return true
        }

        let velocity = panGesture.velocity(in: sheetContainerView)
        guard abs(velocity.y) >= abs(velocity.x) else {
            return false
        }

        if currentDetent == .large {
            let location = panGesture.location(in: sheetContainerView)
            let activationHeight = Layout.grabberTopInset + Layout.grabberHeight + Layout.fullHeightPanActivationZone
            return location.y <= activationHeight
        }

        return true
    }

    private func setupViews() {
        view.backgroundColor = .clear

        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.backgroundColor = backdropColor
        backdropView.alpha = 0

        if gestureEnabled {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackdropTap))
            backdropView.addGestureRecognizer(tapGesture)
        }

        sheetContainerView.translatesAutoresizingMaskIntoConstraints = false
        sheetContainerView.backgroundColor = sheetBackgroundColor
        sheetContainerView.layer.cornerRadius = Layout.sheetCornerRadius
        sheetContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetContainerView.layer.masksToBounds = true

        grabberView.translatesAutoresizingMaskIntoConstraints = false
        grabberView.backgroundColor = theme.handleColor
        grabberView.layer.cornerRadius = Layout.grabberHeight / 2

        contentContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.backgroundColor = .clear

        view.addSubview(backdropView)
        view.addSubview(sheetContainerView)
        sheetContainerView.addSubview(contentContainerView)
        sheetContainerView.addSubview(grabberView)

        if gestureEnabled {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleSheetPan(_:)))
            panGesture.delegate = self
            sheetContainerView.addGestureRecognizer(panGesture)
            panGestureRecognizer = panGesture
        }

        let sheetBottomConstraint = sheetContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        self.sheetBottomConstraint = sheetBottomConstraint

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            sheetContainerView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: Layout.sheetTopInset
            ),
            sheetContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheetBottomConstraint,

            grabberView.topAnchor.constraint(
                equalTo: sheetContainerView.topAnchor,
                constant: Layout.grabberTopInset
            ),
            grabberView.centerXAnchor.constraint(equalTo: sheetContainerView.centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: Layout.grabberWidth),
            grabberView.heightAnchor.constraint(equalToConstant: Layout.grabberHeight),

            contentContainerView.topAnchor.constraint(equalTo: sheetContainerView.topAnchor),
            contentContainerView.leadingAnchor.constraint(equalTo: sheetContainerView.leadingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: sheetContainerView.trailingAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: sheetContainerView.bottomAnchor),
        ])
    }

    @objc private func handleBackdropTap() {
        dismissSheet { [weak self] in
            self?.onDismiss?()
        }
    }

    @objc private func handleSheetPan(_ gesture: UIPanGestureRecognizer) {
        guard !isAnimatingDismissal else { return }

        let baseTranslation = translation(for: currentDetent)
        let rawTranslation = baseTranslation + gesture.translation(in: view).y
        let translationY = min(max(rawTranslation, 0), dismissalTranslation)
        let mediumTranslation = translation(for: .medium)
        let dismissableDistance = max(dismissalTranslation - mediumTranslation, 1)
        let dismissProgress = max(0, translationY - mediumTranslation) / dismissableDistance

        switch gesture.state {
        case .changed:
            sheetContainerView.transform = CGAffineTransform(translationX: 0, y: translationY)
            backdropView.alpha = Layout.backdropAlpha * (1 - dismissProgress)
        case .ended, .cancelled:
            let velocityY = gesture.velocity(in: view).y
            let shouldDismiss =
                translationY > mediumTranslation + Layout.dismissTranslationThreshold ||
                velocityY > Layout.dismissVelocityThreshold

            if shouldDismiss {
                dismissSheet { [weak self] in
                    self?.onDismiss?()
                }
            } else {
                let targetDetent: Detent

                switch currentDetent {
                case .medium:
                    let shouldExpand =
                        translationY <= max(0, mediumTranslation - Layout.expandTranslationThreshold) ||
                        velocityY <= Layout.expandVelocityThreshold
                    targetDetent = shouldExpand ? .large : .medium
                case .large:
                    let shouldCollapse =
                        translationY >= Layout.collapseTranslationThreshold ||
                        velocityY >= Layout.collapseVelocityThreshold
                    targetDetent = shouldCollapse ? .medium : .large
                }

                setDetent(targetDetent, animated: true)
            }
        default:
            break
        }
    }

    private var dismissalTranslation: CGFloat {
        sheetContainerView.bounds.height + view.safeAreaInsets.bottom + 24
    }

    private func transform(for detent: Detent) -> CGAffineTransform {
        CGAffineTransform(translationX: 0, y: translation(for: detent))
    }

    private func transformForDismissal() -> CGAffineTransform {
        CGAffineTransform(translationX: 0, y: dismissalTranslation)
    }

    private func translation(for detent: Detent) -> CGFloat {
        switch detent {
        case .large:
            return 0
        case .medium:
            let containerHeight = max(sheetContainerView.bounds.height, 0)
            let visibleHeight = max(
                Layout.minimumMediumVisibleHeight,
                containerHeight * mediumDetentRatio
            )
            return max(0, containerHeight - min(visibleHeight, containerHeight))
        }
    }
}
