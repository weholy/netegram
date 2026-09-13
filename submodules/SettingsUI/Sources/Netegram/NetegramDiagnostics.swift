import Foundation
import NetegramStore
import TelegramCore
import TextFormat

/// Netegram: an honest answer to "does this actually work right now".
///
/// Every other Netegram screen shows what is *configured*: a switch, a chosen style, a list of
/// chats. None of that proves the mechanism behind it is actually functioning on this install —
/// the fork's worst bug (settings reading back empty in the notification service) was invisible
/// from every settings screen, because every one of them was reading the same broken store the
/// bug was in. This screen instead runs small, real checks — write a value and read it back,
/// count what a tracker actually holds — so a working feature and a silently broken one no
/// longer look identical.
public enum NetegramDiagnosticStatus {
    /// Working, or in a normal off state that is not a problem.
    case ok
    /// Configured in a way that will not do what it looks like it does.
    case warning
    /// The mechanism itself is not functioning.
    case problem
}

public struct NetegramDiagnosticItem {
    public let title: String
    public let status: NetegramDiagnosticStatus
    public let detail: String

    public init(title: String, status: NetegramDiagnosticStatus, detail: String) {
        self.title = title
        self.status = status
        self.detail = detail
    }
}

public struct NetegramDiagnosticSection {
    public let title: String
    public let items: [NetegramDiagnosticItem]

    public init(title: String, items: [NetegramDiagnosticItem]) {
        self.title = title
        self.items = items
    }
}

public enum NetegramDiagnostics {
    /// Runs every check fresh. Cheap enough to call on every screen open — the most expensive
    /// part is one file write and read, the same size as any single settings change.
    public static func run() -> [NetegramDiagnosticSection] {
        return [
            NetegramDiagnostics.storageSection(),
            NetegramDiagnostics.ghostSection(),
            NetegramDiagnostics.autoFormatSection(),
            NetegramDiagnostics.fakeActivitySection(),
            NetegramDiagnostics.deletedMessagesSection(),
        ]
    }

    // MARK: - Storage

    /// The single most important section. Every other check downstream assumes this one
    /// passes — a switch that "does nothing" almost always traces back to here.
    private static func storageSection() -> NetegramDiagnosticSection {
        var items: [NetegramDiagnosticItem] = []

        let sandboxPrefix = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.path
        if let directory = NGStore.storageDirectory() {
            if let sandboxPrefix, directory.hasPrefix(sandboxPrefix) {
                items.append(NetegramDiagnosticItem(
                    title: "Общий контейнер",
                    status: .problem,
                    detail: "Не найдена общая группа приложения — настройки хранятся только в папке самого приложения. Расширение уведомлений их не увидит, скрытые удаления не будут перехватываться в фоне."
                ))
            } else {
                items.append(NetegramDiagnosticItem(
                    title: "Общий контейнер",
                    status: .ok,
                    detail: "Настройки в общем контейнере — доступны и приложению, и расширению уведомлений."
                ))
            }
        } else {
            items.append(NetegramDiagnosticItem(
                title: "Общий контейнер",
                status: .problem,
                detail: "Не удалось получить доступ ни к общему контейнеру, ни к папке приложения."
            ))
        }

        let probeKey = "netegram.diagnostics.probe"
        let probeValue = Int(Date.timeIntervalSinceReferenceDate * 1000)
        NGStore.setObject(probeValue, forKey: probeKey)
        let readBack = NGStore.object(forKey: probeKey) as? Int
        NGStore.removeObject(forKey: probeKey)
        if readBack == probeValue {
            items.append(NetegramDiagnosticItem(title: "Запись и чтение", status: .ok, detail: "Значение записано и прочитано обратно без искажений."))
        } else {
            items.append(NetegramDiagnosticItem(title: "Запись и чтение", status: .problem, detail: "Записанное значение не удалось прочитать обратно — настройки могут не сохраняться."))
        }

        return NetegramDiagnosticSection(title: "ХРАНИЛИЩЕ", items: items)
    }

    // MARK: - Ghost mode

    private static func ghostSection() -> NetegramDiagnosticSection {
        let settings = NetegramGhostPreferences.current()
        var items: [NetegramDiagnosticItem] = []

        let totalOn = netegramGhostRows.filter { settings.flag($0.key) }.count
        items.append(NetegramDiagnosticItem(
            title: "Включено функций",
            status: .ok,
            detail: "\(totalOn) из \(netegramGhostRows.count), по всем разделам."
        ))

        if settings.flag(NetegramGhostKeys.alwaysOnline) && settings.flag(NetegramGhostKeys.hideOnline) {
            items.append(NetegramDiagnosticItem(
                title: "Всегда онлайн / Скрыть онлайн",
                status: .problem,
                detail: "Включены оба одновременно — это противоречие, применяется только «Скрыть онлайн»."
            ))
        } else {
            items.append(NetegramDiagnosticItem(title: "Всегда онлайн / Скрыть онлайн", status: .ok, detail: "Конфликта нет."))
        }

        if settings.flags[NetegramGhostKeys.scheduleAlwaysOnlineEnabled] == true {
            items.append(NetegramDiagnostics.scheduleItem(title: "Расписание «Всегда онлайн»", start: settings.scheduleAlwaysOnlineStart, end: settings.scheduleAlwaysOnlineEnd))
        }
        if settings.flags[NetegramGhostKeys.scheduleHideOnlineEnabled] == true {
            items.append(NetegramDiagnostics.scheduleItem(title: "Расписание «Скрыть онлайн»", start: settings.scheduleHideOnlineStart, end: settings.scheduleHideOnlineEnd))
        }

        let trustedCount = settings.peerList(NetegramGhostKeys.trustedChats).count
        if trustedCount > 0 {
            items.append(NetegramDiagnosticItem(title: "Доверенные чаты", status: .ok, detail: "\(trustedCount) — для них режим призрака не действует вовсе."))
        }

        return NetegramDiagnosticSection(title: "РЕЖИМ ПРИЗРАКА", items: items)
    }

    /// A schedule with equal start and end reads as "on" in the switch but is inert wherever
    /// it is checked (MTGhostIsWithinSchedule treats a zero-length window as off) — this is
    /// the one way a Ghost Mode switch can honestly show "on" while doing nothing.
    private static func scheduleItem(title: String, start: Int32, end: Int32) -> NetegramDiagnosticItem {
        if start == end {
            return NetegramDiagnosticItem(title: title, status: .warning, detail: "Включено, но начало и конец совпадают — расписание никогда не сработает.")
        }
        return NetegramDiagnosticItem(title: title, status: .ok, detail: "Активно с \(netegramFormatTimeOfDay(start)) до \(netegramFormatTimeOfDay(end)).")
    }

    // MARK: - Autoformat

    private static func autoFormatSection() -> NetegramDiagnosticSection {
        let item: NetegramDiagnosticItem
        if let style = NetegramAutoFormat.style {
            item = NetegramDiagnosticItem(title: "Автоформатирование", status: .ok, detail: "Активен стиль «\(style.title)» — применяется при наборе и при отправке.")
        } else {
            item = NetegramDiagnosticItem(title: "Автоформатирование", status: .ok, detail: "Выключено — стиль не выбран.")
        }
        return NetegramDiagnosticSection(title: "АВТОФОРМАТ", items: [item])
    }

    // MARK: - Fake activity

    private static func fakeActivitySection() -> NetegramDiagnosticSection {
        let settings = NetegramFakePreferences.current()
        var items: [NetegramDiagnosticItem] = []

        if settings.activityEnabled && settings.activityPeers.isEmpty {
            items.append(NetegramDiagnosticItem(title: "Показ действия", status: .warning, detail: "Включено, но чаты не выбраны — показывать действие некому."))
        } else if settings.activityEnabled {
            items.append(NetegramDiagnosticItem(title: "Показ действия", status: .ok, detail: "«\(settings.kind.title)» — показывается в \(settings.activityPeers.count) чат(ах)."))
        } else {
            items.append(NetegramDiagnosticItem(title: "Показ действия", status: .ok, detail: "Выключено."))
        }

        if settings.readEnabled && settings.readPeers.isEmpty {
            items.append(NetegramDiagnosticItem(title: "Чтение без открытия", status: .warning, detail: "Включено, но чаты не выбраны — читать нечего."))
        } else if settings.readEnabled {
            items.append(NetegramDiagnosticItem(title: "Чтение без открытия", status: .ok, detail: "Активно для \(settings.readPeers.count) чат(ов)."))
        } else {
            items.append(NetegramDiagnosticItem(title: "Чтение без открытия", status: .ok, detail: "Выключено."))
        }

        return NetegramDiagnosticSection(title: "ФЕЙК-АКТИВНОСТЬ", items: items)
    }

    // MARK: - Deleted messages

    private static func deletedMessagesSection() -> NetegramDiagnosticSection {
        let item = NetegramDiagnosticItem(
            title: "Отслеживается сообщений",
            status: .ok,
            detail: "\(NetegramDeletedMessages.count) — столько удалённых сообщений сейчас помнит это устройство."
        )
        return NetegramDiagnosticSection(title: "УДАЛЁННЫЕ СООБЩЕНИЯ", items: [item])
    }
}
