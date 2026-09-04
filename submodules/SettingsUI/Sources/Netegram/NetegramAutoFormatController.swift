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

public enum NetegramAutoFormatStrings {
    public static let title = "Автоформат"
    public static let subtitle = "Каким шрифтом набирается текст"
    public static let header = "СТИЛЬ ПО УМОЛЧАНИЮ"
    public static let footer = "Выбранные стили применяются ко всему, что вы печатаете в чатах и подписях, — сразу в поле ввода, а не только в отправленном сообщении. Форматирование, поставленное вручную, остаётся как есть. Стили складываются: жирный и курсив вместе дают жирный курсив.\n\nЦитата и блок кода сюда не входят — это не шрифт, а форма блока."
}

private final class NetegramAutoFormatArguments {
    let updateStyle: (NetegramTextStyle, Bool) -> Void

    init(updateStyle: @escaping (NetegramTextStyle, Bool) -> Void) {
        self.updateStyle = updateStyle
    }
}

/// One block for the whole list rather than a block per row: these are alternatives within one
/// decision — how your text looks — and reading them as a group is the point.
private enum NetegramAutoFormatEntry: ItemListNodeEntry {
    case header
    case style(index: Int, style: NetegramTextStyle, value: Bool)
    case footer

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .style(index, _, _):
            return Int32(1 + index)
        case .footer:
            return Int32(1 + NetegramTextStyle.allCases.count)
        }
    }

    static func <(lhs: NetegramAutoFormatEntry, rhs: NetegramAutoFormatEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NetegramAutoFormatArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: NetegramAutoFormatStrings.header, sectionId: self.section)
        case let .style(_, style, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: style.title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateStyle(style, value)
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain(NetegramAutoFormatStrings.footer), sectionId: self.section)
        }
    }
}

public func netegramAutoFormatController(context: AccountContext) -> ViewController {
    // The styles live in TextFormat, which has no promise of its own — it is read from layout
    // paths and has no business owning a signal. The screen keeps its own, seeded from the
    // store and pushed on every toggle.
    let statePromise = ValuePromise<[NetegramTextStyle]>(NetegramAutoFormat.styles, ignoreRepeated: true)

    let arguments = NetegramAutoFormatArguments(updateStyle: { style, value in
        NetegramAutoFormat.setEnabled(value, style: style)
        statePromise.set(NetegramAutoFormat.styles)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, enabled -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [NetegramAutoFormatEntry] = [.header]
        for (index, style) in NetegramTextStyle.allCases.enumerated() {
            entries.append(.style(index: index, style: style, value: enabled.contains(style)))
        }
        entries.append(.footer)

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramAutoFormatStrings.title),
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
