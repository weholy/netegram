import Foundation
import NetegramStore
import SwiftSignalKit

/// Netegram: the ghost-mode switches.
///
/// Every key here is mirrored where it is read — MTNetegramGhost.m for outgoing calls,
/// NetegramAntiFeatures.swift for incoming updates, DeviceLocationManager for the position.
/// They live in NGStore rather than the account's preferences because those readers sit far
/// below the postbox, and because invisibility describes this device, not the account.
///
/// There is deliberately no master switch. Each row stands on its own, so turning one on never
/// depends on remembering to turn something else on first.
public enum NetegramGhostKeys {
    public static let alwaysOnline = "netegram.ghost.alwaysOnline"
    public static let hideOnline = "netegram.ghost.hideOnline"
    public static let typing = "netegram.ghost.typing"
    public static let recordVoice = "netegram.ghost.recordVoice"
    public static let uploadVoice = "netegram.ghost.uploadVoice"
    public static let recordRound = "netegram.ghost.recordRound"
    public static let uploadRound = "netegram.ghost.uploadRound"
    public static let recordVideo = "netegram.ghost.recordVideo"
    public static let uploadVideo = "netegram.ghost.uploadVideo"
    public static let uploadPhoto = "netegram.ghost.uploadPhoto"
    public static let uploadFile = "netegram.ghost.uploadFile"
    public static let chooseSticker = "netegram.ghost.chooseSticker"
    public static let chooseLocation = "netegram.ghost.chooseLocation"
    public static let chooseContact = "netegram.ghost.chooseContact"
    public static let playGame = "netegram.ghost.playGame"
    public static let speaking = "netegram.ghost.speaking"
    public static let emojiInteraction = "netegram.ghost.emojiInteraction"
    public static let emojiSeen = "netegram.ghost.emojiSeen"
    public static let readReceipts = "netegram.ghost.readReceipts"
    public static let readMentions = "netegram.ghost.readMentions"
    public static let readOnAction = "netegram.ghost.readOnAction"
    public static let storyViews = "netegram.ghost.storyViews"
    public static let viewOnce = "netegram.ghost.viewOnce"
    public static let screenshots = "netegram.ghost.screenshots"
    public static let noAds = "netegram.ghost.noAds"
    public static let allowSaving = "netegram.ghost.allowSaving"
    public static let hideStories = "netegram.ghost.hideStories"
    public static let confirmCalls = "netegram.ghost.confirmCalls"
    public static let sendAsVoice = "netegram.ghost.sendAsVoice"
    public static let fastDownload = "netegram.ghost.fastDownload"
    public static let delayedSend = "netegram.ghost.delayedSend"
    public static let delayedSendSeconds = "netegram.ghost.delayedSendSeconds"
    public static let deviceName = "netegram.ghost.deviceName"

    public static let locationEnabled = "netegram.location.enabled"
    public static let locationLatitude = "netegram.location.latitude"
    public static let locationLongitude = "netegram.location.longitude"

    public static let antiRevoke = "netegram.anti.revoke"
    public static let antiEdit = "netegram.anti.edit"
    public static let antiAutoDelete = "netegram.anti.autoDelete"

    // MARK: New

    /// Reported to the server in place of the real OS version / UI language. Text fields, not
    /// switches — see NetegramIdentitySpoofController.
    public static let systemVersion = "netegram.ghost.systemVersion"
    public static let langCode = "netegram.ghost.langCode"

    /// Locally hides that someone else is typing to you — the one switch in this whole screen
    /// about what you see rather than what others see.
    public static let hideIncomingTyping = "netegram.ghost.hideIncomingTyping"

    /// Peer-id lists (decimal strings of the raw `PeerId.toInt64()` value — same convention as
    /// NetegramFakeActivity's peer lists). A chat on `trustedChats` is exempt from every one of
    /// the three lists below at once; the specific lists are for exempting a chat from just one
    /// thing.
    public static let trustedChats = "netegram.ghost.trustedChats"
    public static let typingExceptions = "netegram.ghost.typingExceptions"
    public static let readExceptions = "netegram.ghost.readExceptions"
    public static let storyViewExceptions = "netegram.ghost.storyViewExceptions"

    /// HH:MM-HH:MM windows, stored as minutes-since-midnight, during which the corresponding
    /// switch above applies even if the switch itself is off. A window that wraps past
    /// midnight is valid (e.g. 23:00-07:00).
    public static let scheduleAlwaysOnlineEnabled = "netegram.ghost.scheduleAlwaysOnlineEnabled"
    public static let scheduleAlwaysOnlineStart = "netegram.ghost.scheduleAlwaysOnlineStart"
    public static let scheduleAlwaysOnlineEnd = "netegram.ghost.scheduleAlwaysOnlineEnd"
    public static let scheduleHideOnlineEnabled = "netegram.ghost.scheduleHideOnlineEnabled"
    public static let scheduleHideOnlineStart = "netegram.ghost.scheduleHideOnlineStart"
    public static let scheduleHideOnlineEnd = "netegram.ghost.scheduleHideOnlineEnd"
}

public enum NetegramGhostStrings {
    public static let title = "Режим призрака"
    public static let subtitle = "Что о вас видят другие"

    public static let deviceName = "Имя устройства"
    public static let deviceNamePlaceholder = "Как в системе"
    public static let deviceNameFooter = "Так устройство называется в списке сеансов."

    public static let delayedSendSeconds = "Задержка"

    public static let locationPick = "Выбрать на карте"
    public static let locationReset = "Сбросить точку"
    public static let locationNotSet = "не выбрана"
    public static let locationPickTitle = "Точка на карте"
    public static let locationApply = "Готово"
    public static let locationCancel = "Отмена"

    public static let systemVersionTitle = "Версия ОС"
    public static let systemVersionPlaceholder = "Настоящая"
    public static let systemVersionFooter = "Что видит собеседник в списке сеансов вместо настоящей версии iOS. Пустое поле — без подмены."
    public static let langCodeTitle = "Язык для сервера"
    public static let langCodePlaceholder = "Настоящий"
    public static let langCodeFooter = "Код языка (например, en, de) — влияет только на то, что видит сервер, не на язык интерфейса. Пустое поле — без подмены."

    public static let hideIncomingTypingTitle = "Не видеть чужой набор текста"
    public static let hideIncomingTypingFooter = "«Печатает…» от собеседников не показывается вам. Не влияет на то, что видят о вас."

    public static let trustedChatsTitle = "Доверенные чаты"
    public static let trustedChatsFooter = "Для этих людей режим призрака не действует вовсе — ни один из пунктов ниже, во всех вкладках."
    public static let exceptionsCountEmpty = "никого"
    public static let choosePeersTitle = "Выбрать чаты"
    public static let choosePeersPlaceholder = "Поиск"

    public static let typingExceptionsTitle = "Исключения"
    public static let typingExceptionsFooter = "Этим людям видно, что вы печатаете, даже если переключатель выше выключен."
    public static let readExceptionsTitle = "Исключения"
    public static let readExceptionsFooter = "Этим людям видны отметки о прочтении и упоминаниях, даже если переключатели выше выключены."
    public static let storyExceptionsTitle = "Исключения"
    public static let storyExceptionsFooter = "У этих людей вы остаётесь в списке зрителей историй, даже если переключатель выше выключен."

    public static let scheduleAlwaysOnlineTitle = "По расписанию"
    public static let scheduleAlwaysOnlineFooter = "В это время вы всегда в сети, даже если переключатель выше выключен."
    public static let scheduleHideOnlineTitle = "По расписанию"
    public static let scheduleHideOnlineFooter = "В это время статус «в сети» скрыт, даже если переключатель выше выключен."
    public static let scheduleFrom = "С"
    public static let scheduleTo = "До"
}

/// One row per screen; a screen is everything sharing a category. Splitting a ~40-item list
/// into these is what makes "is X on" answerable by opening one thing instead of scrolling
/// past thirty unrelated switches.
public enum NetegramGhostCategory: CaseIterable, Equatable {
    case deletedMessages
    case hiddenViewing
    case presence
    case activityIndicators
    case identitySpoof
    case trustedChats
    case misc

    public var title: String {
        switch self {
        case .deletedMessages: return "Удалённые сообщения"
        case .hiddenViewing: return "Скрытый просмотр"
        case .presence: return "Присутствие"
        case .activityIndicators: return "Индикаторы действий"
        case .identitySpoof: return "Подмена личности"
        case .trustedChats: return "Доверенные чаты"
        case .misc: return "Прочее"
        }
    }

    public var subtitle: String {
        switch self {
        case .deletedMessages: return "Что остаётся после удаления и правок"
        case .hiddenViewing: return "Прочтение, истории, скриншоты"
        case .presence: return "Онлайн, печать, расписание"
        case .activityIndicators: return "Запись, отправка, выбор"
        case .identitySpoof: return "Устройство, ОС, язык, геопозиция"
        case .trustedChats: return "Кому режим призрака не применяется"
        case .misc: return "Звонки, реклама, скорость"
        }
    }
}

/// One switch: what it is called and what it does, in one sentence.
///
/// Descriptions are written for someone deciding whether to flip the switch, not for someone
/// maintaining the code. "Скрывает набор текста" answers the question; an explanation of which
/// API call gets suppressed does not.
public struct NetegramGhostRow {
    public let key: String
    public let title: String
    public let footer: String
    public let category: NetegramGhostCategory

    public init(key: String, title: String, footer: String, category: NetegramGhostCategory) {
        self.key = key
        self.title = title
        self.footer = footer
        self.category = category
    }
}

public let netegramGhostRows: [NetegramGhostRow] = [
    NetegramGhostRow(key: NetegramGhostKeys.alwaysOnline, title: "Всегда онлайн", footer: "Вы в сети, даже когда приложение закрыто.", category: .presence),
    NetegramGhostRow(key: NetegramGhostKeys.hideOnline, title: "Онлайн-статус", footer: "Скрывает, что вы в сети.", category: .presence),
    NetegramGhostRow(key: NetegramGhostKeys.typing, title: "Набор текста", footer: "Скрывает, что вы печатаете.", category: .presence),
    NetegramGhostRow(key: NetegramGhostKeys.hideIncomingTyping, title: NetegramGhostStrings.hideIncomingTypingTitle, footer: NetegramGhostStrings.hideIncomingTypingFooter, category: .presence),
    NetegramGhostRow(key: NetegramGhostKeys.speaking, title: "Голос в звонке", footer: "Скрывает, что вы говорите в групповом звонке.", category: .presence),

    NetegramGhostRow(key: NetegramGhostKeys.recordVoice, title: "Запись голосового", footer: "Скрывает, что вы записываете голосовое.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.uploadVoice, title: "Отправка голосового", footer: "Скрывает, что вы отправляете голосовое.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.recordRound, title: "Запись кружка", footer: "Скрывает, что вы записываете видеосообщение.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.uploadRound, title: "Отправка кружка", footer: "Скрывает, что вы отправляете видеосообщение.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.recordVideo, title: "Запись видео", footer: "Скрывает, что вы записываете видео.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.uploadVideo, title: "Отправка видео", footer: "Скрывает, что вы отправляете видео.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.uploadPhoto, title: "Отправка фото", footer: "Скрывает, что вы отправляете фото.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.uploadFile, title: "Загрузка файлов", footer: "Скрывает, что вы отправляете файл.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.chooseSticker, title: "Выбор стикера", footer: "Скрывает, что вы выбираете стикер.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.chooseLocation, title: "Выбор геопозиции", footer: "Скрывает, что вы выбираете геопозицию.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.chooseContact, title: "Выбор контакта", footer: "Скрывает, что вы выбираете контакт.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.playGame, title: "Игра", footer: "Скрывает, что вы играете.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.emojiInteraction, title: "Анимации эмодзи", footer: "Собеседник не видит анимацию эмодзи.", category: .activityIndicators),
    NetegramGhostRow(key: NetegramGhostKeys.emojiSeen, title: "Просмотр анимаций", footer: "Не видно, что вы смотрели анимацию.", category: .activityIndicators),

    NetegramGhostRow(key: NetegramGhostKeys.readReceipts, title: "Прочтение сообщений", footer: "Галочки у собеседника остаются одинарными.", category: .hiddenViewing),
    NetegramGhostRow(key: NetegramGhostKeys.readMentions, title: "Прочтение упоминаний", footer: "Упоминания не отмечаются прочитанными.", category: .hiddenViewing),
    NetegramGhostRow(key: NetegramGhostKeys.readOnAction, title: "Читать при действиях", footer: "Чат читается, только когда вы ответили или поставили реакцию.", category: .hiddenViewing),
    NetegramGhostRow(key: NetegramGhostKeys.storyViews, title: "Просмотр историй", footer: "Вас не будет в списке зрителей.", category: .hiddenViewing),
    NetegramGhostRow(key: NetegramGhostKeys.viewOnce, title: "Одноразовые", footer: "Одноразовые медиа открываются тайно.", category: .hiddenViewing),
    NetegramGhostRow(key: NetegramGhostKeys.screenshots, title: "Скриншоты", footer: "Не сообщает о скриншотах в секретных чатах.", category: .hiddenViewing),
    NetegramGhostRow(key: NetegramGhostKeys.hideStories, title: "Скрыть ленту историй", footer: "Убирает ленту историй из списка чатов.", category: .hiddenViewing),

    NetegramGhostRow(key: NetegramGhostKeys.antiRevoke, title: "Не удалять удалённое", footer: "Удалённые сообщения остаются у вас.", category: .deletedMessages),
    NetegramGhostRow(key: NetegramGhostKeys.antiEdit, title: "Не применять правки", footer: "Изменённые сообщения остаются как были.", category: .deletedMessages),
    NetegramGhostRow(key: NetegramGhostKeys.antiAutoDelete, title: "Не удалять по таймеру", footer: "Исчезающие сообщения не исчезают.", category: .deletedMessages),

    NetegramGhostRow(key: NetegramGhostKeys.allowSaving, title: "Сохранение из закрытых чатов", footer: "Сохранять и пересылать можно отовсюду.", category: .misc),
    NetegramGhostRow(key: NetegramGhostKeys.confirmCalls, title: "Подтверждение звонков", footer: "Спрашивает, прежде чем позвонить.", category: .misc),
    NetegramGhostRow(key: NetegramGhostKeys.sendAsVoice, title: "Аудио как голосовое", footer: "Аудиофайлы уходят голосовыми.", category: .misc),
    NetegramGhostRow(key: NetegramGhostKeys.fastDownload, title: "Ускорить загрузку", footer: "Файлы качаются быстрее.", category: .misc),
    NetegramGhostRow(key: NetegramGhostKeys.noAds, title: "Скрыть рекламу", footer: "Убирает спонсорские сообщения в каналах.", category: .misc),
    NetegramGhostRow(key: NetegramGhostKeys.delayedSend, title: "Отложенная отправка", footer: "Сообщение уходит не сразу — его можно отменить.", category: .misc),

    NetegramGhostRow(key: NetegramGhostKeys.locationEnabled, title: "Подмена локации", footer: "Вместо вашей геопозиции — выбранная точка.", category: .identitySpoof),
]

/// The three per-category exception lists plus the blanket trusted-chats list all share this
/// shape — a picker leading to Telegram's own chat multiselection, and a footer explaining the
/// one thing this particular list is exempt from.
public struct NetegramGhostPeerListRow {
    public let key: String
    public let title: String
    public let footer: String

    public init(key: String, title: String, footer: String) {
        self.key = key
        self.title = title
        self.footer = footer
    }
}

public func netegramPeerListRow(forCategory category: NetegramGhostCategory) -> NetegramGhostPeerListRow? {
    switch category {
    case .presence:
        return NetegramGhostPeerListRow(key: NetegramGhostKeys.typingExceptions, title: NetegramGhostStrings.typingExceptionsTitle, footer: NetegramGhostStrings.typingExceptionsFooter)
    case .hiddenViewing:
        return NetegramGhostPeerListRow(key: NetegramGhostKeys.readExceptions, title: NetegramGhostStrings.readExceptionsTitle, footer: NetegramGhostStrings.readExceptionsFooter)
    case .trustedChats:
        return NetegramGhostPeerListRow(key: NetegramGhostKeys.trustedChats, title: NetegramGhostStrings.trustedChatsTitle, footer: NetegramGhostStrings.trustedChatsFooter)
    case .deletedMessages, .activityIndicators, .identitySpoof, .misc:
        return nil
    }
}

/// A second, independent exception list some categories carry alongside the primary one above
/// — right now just stories, living in the same "hidden viewing" screen as read receipts.
public func netegramSecondaryPeerListRow(forCategory category: NetegramGhostCategory) -> NetegramGhostPeerListRow? {
    switch category {
    case .hiddenViewing:
        return NetegramGhostPeerListRow(key: NetegramGhostKeys.storyViewExceptions, title: NetegramGhostStrings.storyExceptionsTitle, footer: NetegramGhostStrings.storyExceptionsFooter)
    default:
        return nil
    }
}

public struct NetegramGhostSettings: Equatable {
    public let flags: [String: Bool]
    public let delayedSendSeconds: Int32
    public let deviceName: String
    public let systemVersion: String
    public let langCode: String
    public let latitude: Double
    public let longitude: Double
    public let peerLists: [String: [Int64]]
    public let scheduleAlwaysOnlineStart: Int32
    public let scheduleAlwaysOnlineEnd: Int32
    public let scheduleHideOnlineStart: Int32
    public let scheduleHideOnlineEnd: Int32

    public init(flags: [String: Bool], delayedSendSeconds: Int32, deviceName: String, systemVersion: String, langCode: String, latitude: Double, longitude: Double, peerLists: [String: [Int64]], scheduleAlwaysOnlineStart: Int32, scheduleAlwaysOnlineEnd: Int32, scheduleHideOnlineStart: Int32, scheduleHideOnlineEnd: Int32) {
        self.flags = flags
        self.delayedSendSeconds = delayedSendSeconds
        self.deviceName = deviceName
        self.systemVersion = systemVersion
        self.langCode = langCode
        self.latitude = latitude
        self.longitude = longitude
        self.peerLists = peerLists
        self.scheduleAlwaysOnlineStart = scheduleAlwaysOnlineStart
        self.scheduleAlwaysOnlineEnd = scheduleAlwaysOnlineEnd
        self.scheduleHideOnlineStart = scheduleHideOnlineStart
        self.scheduleHideOnlineEnd = scheduleHideOnlineEnd
    }

    public func flag(_ key: String) -> Bool {
        return self.flags[key] ?? false
    }

    public var hasLocation: Bool {
        return self.latitude != 0.0 || self.longitude != 0.0
    }

    public func peerList(_ key: String) -> [Int64] {
        return self.peerLists[key] ?? []
    }
}

/// Every boolean this screen reads or writes, gathered in one place so NetegramGhostSettings.flags
/// covers everything the UI might ask for regardless of which category it belongs to.
private let netegramGhostAllFlagKeys: [String] = netegramGhostRows.map { $0.key } + [
    NetegramGhostKeys.scheduleAlwaysOnlineEnabled,
    NetegramGhostKeys.scheduleHideOnlineEnabled,
]

private let netegramGhostAllPeerListKeys: [String] = [
    NetegramGhostKeys.trustedChats,
    NetegramGhostKeys.typingExceptions,
    NetegramGhostKeys.readExceptions,
    NetegramGhostKeys.storyViewExceptions,
]

public final class NetegramGhostPreferences {
    public static let shared = NetegramGhostPreferences()

    private let promise: ValuePromise<NetegramGhostSettings>

    private init() {
        self.promise = ValuePromise(NetegramGhostPreferences.current(), ignoreRepeated: true)
    }

    /// Re-reads the store and pushes it out. Used after an import or a reset, where every
    /// value changed at once without going through any of the setters — including the one
    /// setter enforces that staying online and hiding online cannot both be on. An imported
    /// file can still contain both set, so that invariant is re-checked here rather than only
    /// at the point of writing a single flag: this runs after every bulk change and quietly
    /// turns hideOnline back off rather than leaving a contradiction nothing else will catch.
    public func republish() {
        if NGStore.bool(forKey: NetegramGhostKeys.alwaysOnline) && NGStore.bool(forKey: NetegramGhostKeys.hideOnline) {
            NGStore.setObject(false, forKey: NetegramGhostKeys.hideOnline)
        }
        self.promise.set(NetegramGhostPreferences.current())
    }

    public static func current() -> NetegramGhostSettings {
        var flags: [String: Bool] = [:]
        for key in netegramGhostAllFlagKeys {
            flags[key] = NGStore.bool(forKey: key)
        }
        var peerLists: [String: [Int64]] = [:]
        for key in netegramGhostAllPeerListKeys {
            peerLists[key] = (NGStore.stringArray(forKey: key) ?? []).compactMap(Int64.init)
        }
        let seconds = NGStore.object(forKey: NetegramGhostKeys.delayedSendSeconds) as? Int ?? 5
        return NetegramGhostSettings(
            flags: flags,
            delayedSendSeconds: Int32(seconds),
            deviceName: NGStore.string(forKey: NetegramGhostKeys.deviceName) ?? "",
            systemVersion: NGStore.string(forKey: NetegramGhostKeys.systemVersion) ?? "",
            langCode: NGStore.string(forKey: NetegramGhostKeys.langCode) ?? "",
            latitude: NGStore.double(forKey: NetegramGhostKeys.locationLatitude),
            longitude: NGStore.double(forKey: NetegramGhostKeys.locationLongitude),
            peerLists: peerLists,
            scheduleAlwaysOnlineStart: Int32(NGStore.integer(forKey: NetegramGhostKeys.scheduleAlwaysOnlineStart)),
            scheduleAlwaysOnlineEnd: Int32(NGStore.integer(forKey: NetegramGhostKeys.scheduleAlwaysOnlineEnd)),
            scheduleHideOnlineStart: Int32(NGStore.integer(forKey: NetegramGhostKeys.scheduleHideOnlineStart)),
            scheduleHideOnlineEnd: Int32(NGStore.integer(forKey: NetegramGhostKeys.scheduleHideOnlineEnd))
        )
    }

    public var signal: Signal<NetegramGhostSettings, NoError> {
        return self.promise.get()
    }

    /// The number of flags currently on, shown as a live count next to each category row in
    /// the parent list — the fastest way to answer "is anything even active here" without
    /// opening the screen. Takes an already-read snapshot rather than reading NGStore itself,
    /// so the parent list's row counts and its own settings signal never disagree.
    public static func activeCount(in category: NetegramGhostCategory, settings: NetegramGhostSettings) -> Int {
        var count = netegramGhostRows.filter { $0.category == category && settings.flag($0.key) }.count
        if category == .presence {
            if settings.flags[NetegramGhostKeys.scheduleAlwaysOnlineEnabled] == true { count += 1 }
            if settings.flags[NetegramGhostKeys.scheduleHideOnlineEnabled] == true { count += 1 }
        }
        if category == .identitySpoof {
            if !settings.deviceName.isEmpty { count += 1 }
            if !settings.systemVersion.isEmpty { count += 1 }
            if !settings.langCode.isEmpty { count += 1 }
            if settings.hasLocation { count += 1 }
        }
        if category == .trustedChats {
            count = settings.peerList(NetegramGhostKeys.trustedChats).count
        }
        return count
    }

    /// Writing a flag, with the one rule the switches cannot express on their own: staying
    /// online and hiding that you are online are opposite instructions about the same thing,
    /// so turning either on turns the other off.
    public func setFlag(_ key: String, value: Bool) {
        NGStore.setObject(value, forKey: key)
        if value {
            if key == NetegramGhostKeys.alwaysOnline {
                NGStore.setObject(false, forKey: NetegramGhostKeys.hideOnline)
            } else if key == NetegramGhostKeys.hideOnline {
                NGStore.setObject(false, forKey: NetegramGhostKeys.alwaysOnline)
            }
        }
        self.promise.set(NetegramGhostPreferences.current())
    }

    public func setDelayedSendSeconds(_ value: Int32) {
        NGStore.setObject(Int(value), forKey: NetegramGhostKeys.delayedSendSeconds)
        self.promise.set(NetegramGhostPreferences.current())
    }

    public func setDeviceName(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        NGStore.setObject(trimmed, forKey: NetegramGhostKeys.deviceName)
        self.promise.set(NetegramGhostPreferences.current())
    }

    public func setSystemVersion(_ value: String) {
        NGStore.setObject(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: NetegramGhostKeys.systemVersion)
        self.promise.set(NetegramGhostPreferences.current())
    }

    public func setLangCode(_ value: String) {
        NGStore.setObject(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), forKey: NetegramGhostKeys.langCode)
        self.promise.set(NetegramGhostPreferences.current())
    }

    public func setLocation(latitude: Double, longitude: Double) {
        NGStore.setObject(latitude, forKey: NetegramGhostKeys.locationLatitude)
        NGStore.setObject(longitude, forKey: NetegramGhostKeys.locationLongitude)
        self.promise.set(NetegramGhostPreferences.current())
    }

    /// Clearing the point also clears the switch: a spoof turned on with nowhere to be is a
    /// setting that silently does nothing.
    public func resetLocation() {
        NGStore.setObject(0.0, forKey: NetegramGhostKeys.locationLatitude)
        NGStore.setObject(0.0, forKey: NetegramGhostKeys.locationLongitude)
        NGStore.setObject(false, forKey: NetegramGhostKeys.locationEnabled)
        self.promise.set(NetegramGhostPreferences.current())
    }

    public func setPeerList(_ key: String, peerIds: [Int64]) {
        NGStore.setObject(peerIds.map { String($0) }, forKey: key)
        self.promise.set(NetegramGhostPreferences.current())
    }

    public func setScheduleEnabled(_ key: String, value: Bool) {
        NGStore.setObject(value, forKey: key)
        self.promise.set(NetegramGhostPreferences.current())
    }

    public func setScheduleWindow(startKey: String, endKey: String, startMinutes: Int32, endMinutes: Int32) {
        NGStore.setObject(Int(startMinutes), forKey: startKey)
        NGStore.setObject(Int(endMinutes), forKey: endKey)
        self.promise.set(NetegramGhostPreferences.current())
    }
}

/// Read at connection setup, where the real device model would otherwise be reported.
public func netegramCustomDeviceName() -> String? {
    let value = NGStore.string(forKey: NetegramGhostKeys.deviceName) ?? ""
    return value.isEmpty ? nil : value
}
