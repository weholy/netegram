import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

public enum NetegramNavBarStrings {
    public static let width = "Ширина"
    public static let widthFooter = "Насколько панель уже экрана."
    public static let height = "Высота"
    public static let heightFooter = "Насколько панель толще обычной."
    public static let preview = "Предосмотр"
    public static let previewFooter = "Показывает панель внизу экрана, чтобы видеть изменения не выходя из настроек."
    public static let reset = "Вернуть обычный размер"
}

/// A copy of the bottom bar, drawn to show what the settings above will do.
///
/// It has to be a copy: the real bar exists in exactly one instance and belongs to the tab
/// controller, so it cannot be borrowed and put on a settings screen. The copy follows the
/// same hidden tabs and the same two scales, but it is a picture of the bar, not the bar.
final class NetegramNavBarPreviewView: UIView {
    private let barView = UIView()
    private let closeButton = UIButton(type: .system)
    private var itemViews: [UIView] = []

    private var tabs: [NetegramNavTab] = []
    private var widthScale: CGFloat = 1.0
    private var heightScale: CGFloat = 1.0
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose

        super.init(frame: CGRect())

        self.barView.layer.cornerRadius = 22.0
        self.barView.layer.cornerCurve = .continuous
        self.barView.clipsToBounds = true
        self.addSubview(self.barView)

        self.closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        self.closeButton.addTarget(self, action: #selector(self.closeTapped), for: .touchUpInside)
        self.addSubview(self.closeButton)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    @objc private func closeTapped() {
        self.onClose()
    }

    func update(theme: PresentationTheme, hiddenTabs: [String], widthScale: CGFloat, heightScale: CGFloat) {
        self.widthScale = widthScale
        self.heightScale = heightScale

        // Never empty, for the same reason the real bar is never empty: a bar with nothing in
        // it would be a preview of something the app refuses to build.
        var tabs = NetegramNavTab.previewOrder.filter { !hiddenTabs.contains($0.rawValue) }
        if tabs.isEmpty {
            tabs = [.chats]
        }

        if tabs != self.tabs {
            self.tabs = tabs
            for view in self.itemViews {
                view.removeFromSuperview()
            }
            self.itemViews = tabs.map { tab in
                let container = UIView()

                let icon = UIImageView(image: UIImage(systemName: tab.previewIconName))
                icon.contentMode = .scaleAspectFit
                icon.tag = 1
                container.addSubview(icon)

                let label = UILabel()
                label.text = tab.previewTitle
                label.font = UIFont.systemFont(ofSize: 10.0, weight: .medium)
                label.textAlignment = .center
                label.tag = 2
                container.addSubview(label)

                self.barView.addSubview(container)
                return container
            }
        }

        self.barView.backgroundColor = theme.rootController.tabBar.backgroundColor
        self.closeButton.tintColor = theme.list.itemSecondaryTextColor
        for (index, container) in self.itemViews.enumerated() {
            let isSelected = self.tabs[index] == .chats
            let color = isSelected ? theme.rootController.tabBar.selectedIconColor : theme.rootController.tabBar.iconColor
            (container.viewWithTag(1) as? UIImageView)?.tintColor = color
            (container.viewWithTag(2) as? UILabel)?.textColor = isSelected ? theme.rootController.tabBar.selectedTextColor : theme.rootController.tabBar.textColor
        }

        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let sideInset: CGFloat = 8.0
        let baseHeight: CGFloat = 56.0
        let barHeight = floor(baseHeight * self.heightScale)
        let barWidth = floor((self.bounds.width - sideInset * 2.0) * self.widthScale)
        let barFrame = CGRect(
            x: floor((self.bounds.width - barWidth) / 2.0),
            y: self.bounds.height - barHeight - 12.0,
            width: barWidth,
            height: barHeight
        )
        self.barView.frame = barFrame
        self.barView.layer.cornerRadius = min(22.0, barHeight / 2.0)

        self.closeButton.frame = CGRect(x: barFrame.maxX - 14.0, y: barFrame.minY - 14.0, width: 28.0, height: 28.0)

        guard !self.itemViews.isEmpty else {
            return
        }
        let itemWidth = barFrame.width / CGFloat(self.itemViews.count)
        for (index, container) in self.itemViews.enumerated() {
            container.frame = CGRect(x: CGFloat(index) * itemWidth, y: 0.0, width: itemWidth, height: barFrame.height)
            let iconSize = floor(26.0 * self.heightScale)
            container.viewWithTag(1)?.frame = CGRect(
                x: floor((itemWidth - iconSize) / 2.0),
                y: floor(barFrame.height * 0.16),
                width: iconSize,
                height: iconSize
            )
            container.viewWithTag(2)?.frame = CGRect(
                x: 0.0,
                y: floor(barFrame.height * 0.16) + iconSize + 1.0,
                width: itemWidth,
                height: 12.0
            )
        }
    }
}

extension NetegramNavTab {
    /// Left to right, as the real bar arranges them.
    static var previewOrder: [NetegramNavTab] {
        return [.contacts, .calls, .chats, .settings]
    }

    var previewTitle: String {
        switch self {
        case .calls:
            return "Звонки"
        case .contacts:
            return "Контакты"
        case .chats:
            return "Чаты"
        case .settings:
            return "Настройки"
        }
    }

    var previewIconName: String {
        switch self {
        case .calls:
            return "phone"
        case .contacts:
            return "person.crop.circle"
        case .chats:
            return "bubble.left.and.bubble.right"
        case .settings:
            return "gearshape"
        }
    }
}

private final class NetegramNavBarArguments {
    let toggleTab: (NetegramNavTab, Bool) -> Void
    let updateWidth: (Int) -> Void
    let updateHeight: (Int) -> Void
    let togglePreview: (Bool) -> Void
    let reset: () -> Void

    init(toggleTab: @escaping (NetegramNavTab, Bool) -> Void, updateWidth: @escaping (Int) -> Void, updateHeight: @escaping (Int) -> Void, togglePreview: @escaping (Bool) -> Void, reset: @escaping () -> Void) {
        self.toggleTab = toggleTab
        self.updateWidth = updateWidth
        self.updateHeight = updateHeight
        self.togglePreview = togglePreview
        self.reset = reset
    }
}

private enum NetegramNavBarEntry: ItemListNodeEntry {
    case tab(Int, NetegramNavTab, Bool)
    case tabFooter(Int, String)
    case width(Int)
    case widthFooter
    case height(Int)
    case heightFooter
    case preview(Bool)
    case previewFooter
    case reset

    /// One section per row, so each setting is its own block with its caption underneath.
    var section: ItemListSectionId {
        switch self {
        case let .tab(index, _, _), let .tabFooter(index, _):
            return ItemListSectionId(index)
        case .width, .widthFooter:
            return ItemListSectionId(100)
        case .height, .heightFooter:
            return ItemListSectionId(101)
        case .preview, .previewFooter:
            return ItemListSectionId(102)
        case .reset:
            return ItemListSectionId(103)
        }
    }

    var stableId: Int32 {
        switch self {
        case let .tab(index, _, _):
            return Int32(index * 2)
        case let .tabFooter(index, _):
            return Int32(index * 2 + 1)
        case .width: return 100
        case .widthFooter: return 101
        case .height: return 102
        case .heightFooter: return 103
        case .preview: return 104
        case .previewFooter: return 105
        case .reset: return 106
        }
    }

    static func <(lhs: NetegramNavBarEntry, rhs: NetegramNavBarEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramNavBarArguments
        switch self {
        case let .tab(_, tab, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: tab.title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleTab(tab, value)
            })
        case let .tabFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .width(percent):
            // The slider counts from zero, so the stored percentage is shifted into its range
            // and back rather than the slider being taught about percentages.
            return NetegramStarsSliderItem(theme: presentationData.theme, title: "\(NetegramNavBarStrings.width): \(percent)%", value: percent - 50, maxValue: 100, enabled: true, sectionId: self.section, updated: { value in
                arguments.updateWidth(value + 50)
            })
        case .widthFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramNavBarStrings.widthFooter), sectionId: self.section)
        case let .height(percent):
            return NetegramStarsSliderItem(theme: presentationData.theme, title: "\(NetegramNavBarStrings.height): \(percent)%", value: percent - 50, maxValue: 100, enabled: true, sectionId: self.section, updated: { value in
                arguments.updateHeight(value + 50)
            })
        case .heightFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramNavBarStrings.heightFooter), sectionId: self.section)
        case let .preview(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramNavBarStrings.preview, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.togglePreview(value)
            })
        case .previewFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramNavBarStrings.previewFooter), sectionId: self.section)
        case .reset:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: NetegramNavBarStrings.reset, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.reset()
            })
        }
    }
}

public func netegramNavBarController(context: AccountContext) -> ViewController {
    var presentRestartImpl: (() -> Void)?
    var updatePreviewImpl: ((Bool) -> Void)?

    let previewVisible = ValuePromise<Bool>(false, ignoreRepeated: true)

    let arguments = NetegramNavBarArguments(toggleTab: { tab, value in
        NetegramLookPreferences.shared.setNavTabHidden(tab, hidden: value)
        presentRestartImpl?()
    }, updateWidth: { percent in
        NetegramLookPreferences.shared.setNavBarWidth(percent)
    }, updateHeight: { percent in
        NetegramLookPreferences.shared.setNavBarHeight(percent)
    }, togglePreview: { value in
        previewVisible.set(value)
        updatePreviewImpl?(value)
    }, reset: {
        NetegramLookPreferences.shared.setNavBarWidth(100)
        NetegramLookPreferences.shared.setNavBarHeight(100)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        NetegramLookPreferences.shared.signal,
        previewVisible.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, settings, isPreviewVisible -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [NetegramNavBarEntry] = []
        for (index, tab) in NetegramNavTab.previewOrder.enumerated() {
            entries.append(.tab(index, tab, settings.hiddenNavTabs.contains(tab.rawValue)))
            entries.append(.tabFooter(index, tab.footer))
        }
        entries.append(.width(settings.navBarWidth))
        entries.append(.widthFooter)
        entries.append(.height(settings.navBarHeight))
        entries.append(.heightFooter)
        entries.append(.preview(isPreviewVisible))
        entries.append(.previewFooter)
        entries.append(.reset)

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramLookStrings.navBarTitle),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)

    presentRestartImpl = { [weak controller] in
        netegramPresentRestartToast(context: context, controller: controller, text: NetegramRestartStrings.navBar)
    }

    var previewView: NetegramNavBarPreviewView?
    let previewDisposable = MetaDisposable()

    updatePreviewImpl = { [weak controller] isVisible in
        guard let controller else {
            return
        }
        if !isVisible {
            previewDisposable.set(nil)
            previewView?.removeFromSuperview()
            previewView = nil
            return
        }
        if previewView == nil {
            let view = NetegramNavBarPreviewView(onClose: {
                previewVisible.set(false)
                updatePreviewImpl?(false)
            })
            view.isUserInteractionEnabled = true
            controller.view.addSubview(view)
            previewView = view
        }
        // Kept in step with the settings rather than updated from the toggles, so it also
        // follows a change made anywhere else while the preview is open.
        previewDisposable.set((combineLatest(queue: .mainQueue(),
            context.sharedContext.presentationData,
            NetegramLookPreferences.shared.signal
        )
        |> deliverOnMainQueue).start(next: { [weak controller] presentationData, settings in
            guard let controller, let previewView else {
                return
            }
            previewView.frame = controller.view.bounds
            previewView.update(
                theme: presentationData.theme,
                hiddenTabs: settings.hiddenNavTabs,
                widthScale: CGFloat(settings.navBarWidth) / 100.0,
                heightScale: CGFloat(settings.navBarHeight) / 100.0
            )
        }))
    }

    return controller
}
