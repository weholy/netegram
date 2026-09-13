import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

public enum NetegramDiagnosticsStrings {
    public static let title = "Диагностика"
    public static let subtitle = "Что реально работает прямо сейчас"
}

private final class NetegramDiagnosticsArguments {
}

private enum NetegramDiagnosticsEntry: ItemListNodeEntry {
    /// section index, title
    case sectionHeader(Int32, String)
    /// section index, item index, combined "glyph + title\ndetail" text
    case item(Int32, Int32, String)

    var section: ItemListSectionId {
        switch self {
        case let .sectionHeader(section, _), let .item(section, _, _):
            return ItemListSectionId(section)
        }
    }

    var stableId: Int32 {
        switch self {
        case let .sectionHeader(section, _):
            return section * 100
        case let .item(section, index, _):
            return section * 100 + 1 + index
        }
    }

    static func <(lhs: NetegramDiagnosticsEntry, rhs: NetegramDiagnosticsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .sectionHeader(_, title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .item(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func netegramDiagnosticsGlyph(_ status: NetegramDiagnosticStatus) -> String {
    switch status {
    case .ok:
        return "✓"
    case .warning:
        return "⚠"
    case .problem:
        return "✗"
    }
}

private func netegramDiagnosticsEntries() -> [NetegramDiagnosticsEntry] {
    var entries: [NetegramDiagnosticsEntry] = []
    for (sectionIndex, section) in NetegramDiagnostics.run().enumerated() {
        let sectionId = Int32(sectionIndex)
        entries.append(.sectionHeader(sectionId, section.title))
        for (itemIndex, diagnosticItem) in section.items.enumerated() {
            let text = "\(netegramDiagnosticsGlyph(diagnosticItem.status)) \(diagnosticItem.title)\n\(diagnosticItem.detail)"
            entries.append(.item(sectionId, Int32(itemIndex), text))
        }
    }
    return entries
}

/// Netegram: a read-only report, rebuilt fresh every time the screen opens.
///
/// No signal ties it to the settings it reports on — a diagnostics snapshot is meant to answer
/// "right now", the same way opening iOS's own Settings ▸ Storage shows a snapshot rather than
/// a live meter. Leaving and reopening the screen gets a fresh one.
public func netegramDiagnosticsController(context: AccountContext) -> ViewController {
    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(NetegramDiagnosticsStrings.title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: netegramDiagnosticsEntries(),
            style: .blocks,
            animateChanges: false
        )

        return (controllerState, (listState, NetegramDiagnosticsArguments()))
    }

    return ItemListController(context: context, state: signal)
}
