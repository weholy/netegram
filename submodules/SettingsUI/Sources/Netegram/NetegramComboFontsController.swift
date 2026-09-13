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
import TextFormat

public enum NetegramComboFontsStrings {
    public static let title = "Комбо-шрифты"
    public static let subtitle = "Разный стиль на каждую букву"

    public static let enabledTitle = "Включить"
    public static let enabledFooter = "Каждая буква получает свой стиль из выбранных ниже. Отменяет обычный автоформат — они не работают одновременно."

    public static let stylesHeader = "СТИЛИ"
    public static let stylesFooter = "Выберите от 1 до 6. Пока не выбран ни один, комбо-шрифты не действуют, даже если включены выше."
}

private struct NetegramComboFontsState: Equatable {
    let enabled: Bool
    let styles: [NetegramTextStyle]
}

private final class NetegramComboFontsArguments {
    let updateEnabled: (Bool) -> Void
    let updateStyleChosen: (NetegramTextStyle, Bool) -> Void

    init(updateEnabled: @escaping (Bool) -> Void, updateStyleChosen: @escaping (NetegramTextStyle, Bool) -> Void) {
        self.updateEnabled = updateEnabled
        self.updateStyleChosen = updateStyleChosen
    }
}

private enum NetegramComboFontsEntry: ItemListNodeEntry {
    case enabled(Bool)
    case enabledFooter
    case stylesHeader
    case style(index: Int, style: NetegramTextStyle, chosen: Bool)
    case stylesFooter

    var section: ItemListSectionId {
        switch self {
        case .enabled, .enabledFooter:
            return 0
        case .stylesHeader, .style, .stylesFooter:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case .enabled:
            return 0
        case .enabledFooter:
            return 1
        case .stylesHeader:
            return 2
        case let .style(index, _, _):
            return Int32(3 + index)
        case .stylesFooter:
            return Int32(3 + NetegramTextStyle.allCases.count)
        }
    }

    static func <(lhs: NetegramComboFontsEntry, rhs: NetegramComboFontsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramComboFontsArguments
        switch self {
        case let .enabled(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: NetegramComboFontsStrings.enabledTitle, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateEnabled(value)
            })
        case .enabledFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramComboFontsStrings.enabledFooter), sectionId: self.section)
        case .stylesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: NetegramComboFontsStrings.stylesHeader, sectionId: self.section)
        case let .style(_, style, chosen):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: style.title, value: chosen, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateStyleChosen(style, value)
            })
        case .stylesFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramComboFontsStrings.stylesFooter), sectionId: self.section)
        }
    }
}

private func netegramComboFontsCurrentState() -> NetegramComboFontsState {
    return NetegramComboFontsState(enabled: NetegramComboFonts.isEnabled, styles: NetegramComboFonts.chosenStyles)
}

public func netegramComboFontsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise<NetegramComboFontsState>(netegramComboFontsCurrentState(), ignoreRepeated: true)

    let arguments = NetegramComboFontsArguments(updateEnabled: { value in
        NetegramComboFonts.setEnabled(value)
        statePromise.set(netegramComboFontsCurrentState())
    }, updateStyleChosen: { style, chosen in
        NetegramComboFonts.setStyleChosen(style, chosen: chosen)
        statePromise.set(netegramComboFontsCurrentState())
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [NetegramComboFontsEntry] = [.enabled(state.enabled), .enabledFooter, .stylesHeader]
        for (index, style) in NetegramTextStyle.allCases.enumerated() {
            entries.append(.style(index: index, style: style, chosen: state.styles.contains(style)))
        }
        entries.append(.stylesFooter)

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramComboFontsStrings.title),
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

    return ItemListController(context: context, state: signal)
}
