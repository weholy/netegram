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

public enum NetegramBackgroundStrings {
    public static let title = "Фон приложения"
    public static let videoTitle = "Видео-фон"
    public static let videoFooter = "Видео проигрывается позади всех экранов. Интерфейс становится полупрозрачным, чтобы фон был виден."
    public static let photoTitle = "Фото-фон"
    public static let photoFooter = "Изображение позади всех экранов. Расходует заметно меньше батареи, чем видео."
    public static let choose = "Выбрать из галереи"
    public static let chosen = "Выбрано"
    public static let restartTitle = "Требуется перезапуск"
    public static let restartText = "Закройте приложение полностью и откройте снова, чтобы фон применился ко всем экранам."
    public static let ok = "Понятно"
}

private let backgroundModeKey = "netegram.background.mode"
private let backgroundPathKey = "netegram.background.path"

/// Which background the client draws behind every screen.
public enum NetegramBackgroundMode: Int32 {
    case none = 0
    case photo = 1
    case video = 2
}

public struct NetegramBackgroundState: Equatable {
    public let mode: NetegramBackgroundMode
    public let path: String

    public init(mode: NetegramBackgroundMode, path: String) {
        self.mode = mode
        self.path = path
    }

    public var hasMedia: Bool {
        return !self.path.isEmpty
    }
}

/// Device-local background settings.
///
/// Photo and video are mutually exclusive: one background layer is drawn, so turning one on
/// turns the other off rather than leaving two conflicting sources selected.
public final class NetegramBackgroundSettings {
    public static let shared = NetegramBackgroundSettings()

    private let promise: ValuePromise<NetegramBackgroundState>

    private init() {
        self.promise = ValuePromise(NetegramBackgroundSettings.current(), ignoreRepeated: true)
    }

    public static func current() -> NetegramBackgroundState {
        let defaults = UserDefaults.standard
        let rawMode = Int32(defaults.integer(forKey: backgroundModeKey))
        return NetegramBackgroundState(
            mode: NetegramBackgroundMode(rawValue: rawMode) ?? .none,
            path: defaults.string(forKey: backgroundPathKey) ?? ""
        )
    }

    public var signal: Signal<NetegramBackgroundState, NoError> {
        return self.promise.get()
    }

    public func setMode(_ mode: NetegramBackgroundMode) {
        UserDefaults.standard.set(Int(mode.rawValue), forKey: backgroundModeKey)
        self.promise.set(NetegramBackgroundSettings.current())
    }

    public func setPath(_ path: String) {
        UserDefaults.standard.set(path, forKey: backgroundPathKey)
        self.promise.set(NetegramBackgroundSettings.current())
    }
}

// MARK: - Screen

private final class NetegramBackgroundArguments {
    let updateVideo: (Bool) -> Void
    let updatePhoto: (Bool) -> Void
    let choose: () -> Void

    init(updateVideo: @escaping (Bool) -> Void, updatePhoto: @escaping (Bool) -> Void, choose: @escaping () -> Void) {
        self.updateVideo = updateVideo
        self.updatePhoto = updatePhoto
        self.choose = choose
    }
}

private enum NetegramBackgroundSection: Int32 {
    case video
    case photo
    case media
}

private enum NetegramBackgroundEntry: ItemListNodeEntry {
    case video(Bool)
    case videoFooter
    case photo(Bool)
    case photoFooter
    case choose(String)

    var section: ItemListSectionId {
        switch self {
        case .video, .videoFooter:
            return NetegramBackgroundSection.video.rawValue
        case .photo, .photoFooter:
            return NetegramBackgroundSection.photo.rawValue
        case .choose:
            return NetegramBackgroundSection.media.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .video:
            return 0
        case .videoFooter:
            return 1
        case .photo:
            return 2
        case .photoFooter:
            return 3
        case .choose:
            return 4
        }
    }

    static func <(lhs: NetegramBackgroundEntry, rhs: NetegramBackgroundEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramBackgroundArguments
        switch self {
        case let .video(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramBackgroundStrings.videoTitle, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateVideo(value)
            })
        case .videoFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramBackgroundStrings.videoFooter), sectionId: self.section)
        case let .photo(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramBackgroundStrings.photoTitle, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updatePhoto(value)
            })
        case .photoFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramBackgroundStrings.photoFooter), sectionId: self.section)
        case let .choose(current):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: NetegramBackgroundStrings.choose, label: current, sectionId: self.section, style: .blocks, action: {
                arguments.choose()
            })
        }
    }
}

/// The picker row only appears once a mode is on, so it slides in and out with the toggle.
private func netegramBackgroundEntries(state: NetegramBackgroundState) -> [NetegramBackgroundEntry] {
    var entries: [NetegramBackgroundEntry] = [
        .video(state.mode == .video),
        .videoFooter,
        .photo(state.mode == .photo),
        .photoFooter
    ]
    if state.mode != .none {
        entries.append(.choose(state.hasMedia ? NetegramBackgroundStrings.chosen : ""))
    }
    return entries
}

public func netegramBackgroundController(context: AccountContext) -> ViewController {
    var presentRestartImpl: (() -> Void)?

    let arguments = NetegramBackgroundArguments(updateVideo: { value in
        NetegramBackgroundSettings.shared.setMode(value ? .video : .none)
    }, updatePhoto: { value in
        // Only one background layer is drawn, so enabling one mode disables the other.
        NetegramBackgroundSettings.shared.setMode(value ? .photo : .none)
    }, choose: {
        presentRestartImpl?()
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        NetegramBackgroundSettings.shared.signal
    )
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramBackgroundStrings.title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: netegramBackgroundEntries(state: state),
            style: .blocks,
            animateChanges: true
        )

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentRestartImpl = { [weak controller] in
        guard let controller else {
            return
        }
        controller.present(
            textAlertController(context: context, title: NetegramBackgroundStrings.restartTitle, text: NetegramBackgroundStrings.restartText, actions: [
                TextAlertAction(type: .defaultAction, title: NetegramBackgroundStrings.ok, action: {})
            ]),
            in: .window(.root)
        )
    }
    return controller
}
