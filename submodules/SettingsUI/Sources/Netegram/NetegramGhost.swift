import Foundation
import SwiftSignalKit

/// Netegram: the ghost-mode switches.
///
/// Every key here is mirrored in MTNetegramGhost.m, which reads them while deciding whether an
/// outgoing API call may leave the device. They live in UserDefaults rather than the account's
/// preferences because MTProtoKit sits far below the postbox and cannot reach it — and because
/// invisibility is a property of this device, not of the account.
public enum NetegramGhostKeys {
    public static let enabled = "netegram.ghost.enabled"
    public static let alwaysOnline = "netegram.ghost.alwaysOnline"
    public static let hideOnline = "netegram.ghost.hideOnline"
    public static let typing = "netegram.ghost.typing"
    public static let recordVoice = "netegram.ghost.recordVoice"
    public static let uploadVoice = "netegram.ghost.uploadVoice"
    public static let recordVideo = "netegram.ghost.recordVideo"
    public static let uploadVideo = "netegram.ghost.uploadVideo"
    public static let uploadPhoto = "netegram.ghost.uploadPhoto"
    public static let uploadFile = "netegram.ghost.uploadFile"
    public static let recordRound = "netegram.ghost.recordRound"
    public static let uploadRound = "netegram.ghost.uploadRound"
    public static let chooseSticker = "netegram.ghost.chooseSticker"
    public static let chooseLocation = "netegram.ghost.chooseLocation"
    public static let chooseContact = "netegram.ghost.chooseContact"
    public static let playGame = "netegram.ghost.playGame"
    public static let speaking = "netegram.ghost.speaking"
    public static let emojiInteraction = "netegram.ghost.emojiInteraction"
    public static let emojiSeen = "netegram.ghost.emojiSeen"
    public static let readReceipts = "netegram.ghost.readReceipts"
    public static let storyViews = "netegram.ghost.storyViews"
    public static let viewOnce = "netegram.ghost.viewOnce"
    public static let screenshots = "netegram.ghost.screenshots"
    public static let noAds = "netegram.ghost.noAds"
    public static let readOnAction = "netegram.ghost.readOnAction"
    public static let delayedSend = "netegram.ghost.delayedSend"
    public static let delayedSendSeconds = "netegram.ghost.delayedSendSeconds"
    public static let deviceName = "netegram.ghost.deviceName"
}

public enum NetegramGhostStrings {
    public static let title = "Режим призрака"
    public static let subtitle = "Ничего не сообщать о себе"

    public static let enabled = "Режим призрака"
    public static let enabledFooter = "Общий выключатель. Пока он выключен, всё ниже не действует — кроме скрытия рекламы и имени устройства."

    public static let statuses = "Что не показывать"
    public static let statusesFooter = "Собеседник не увидит перечисленное. Всё остальное уходит как обычно."

    public static let alwaysOnline = "Всегда онлайн"
    public static let alwaysOnlineFooter = "Приложение не сообщает, что вы ушли из него. Статус держится, пока сервер сам не решит, что вас давно не слышно, — обычно это несколько минут после закрытия."
    public static let hideOnline = "Онлайн-статус"
    public static let hideOnlineFooter = "Приложение не сообщает, что вы вернулись. Вы остаётесь «был давно», сколько бы ни сидели в чатах."

    public static let typing = "Набор текста"
    public static let recordVoice = "Запись голосового"
    public static let uploadVoice = "Отправка голосового"
    public static let recordVideo = "Запись видео"
    public static let uploadVideo = "Отправка видео"
    public static let uploadPhoto = "Отправка фото"
    public static let uploadFile = "Загрузка файлов"
    public static let recordRound = "Запись кружка"
    public static let uploadRound = "Отправка кружка"
    public static let chooseSticker = "Выбор стикера"
    public static let chooseLocation = "Выбор геопозиции"
    public static let chooseContact = "Выбор контакта"
    public static let playGame = "Игра"
    public static let speaking = "Голос в звонке"
    public static let emojiInteraction = "Анимации эмодзи"
    public static let emojiSeen = "Просмотр анимаций"

    public static let receipts = "Отметки о просмотре"
    public static let readReceipts = "Прочтение сообщений"
    public static let readReceiptsFooter = "Галочки у собеседника остаются одинарными, сколько бы вы ни перечитывали переписку."
    public static let storyViews = "Просмотр историй"
    public static let storyViewsFooter = "Ваше имя не появится в списке зрителей."
    public static let viewOnce = "Одноразовые"
    public static let viewOnceFooter = "Фото и голосовые «на один раз» открываются без отметки — таймер уничтожения не запускается, отправитель ничего не узнает."
    public static let screenshots = "Скриншоты"
    public static let screenshotsFooter = "В секретных чатах не уходит уведомление о снимке экрана."
    public static let readOnAction = "Читать при действиях"
    public static let readOnActionFooter = "Просто открыть чат — ничего не меняется. Но стоит ответить или поставить реакцию, и переписка отмечается прочитанной: молчаливый собеседник, который при этом отвечает, выглядит страннее любых галочек."

    public static let extras = "Прочее"
    public static let noAds = "Скрыть рекламу"
    public static let noAdsFooter = "Спонсорские сообщения в каналах не запрашиваются."
    public static let deviceName = "Имя устройства"
    public static let deviceNamePlaceholder = "Как в системе"
    public static let deviceNameFooter = "Под этим именем сеанс виден в списке активных устройств. Пустое поле возвращает настоящую модель. Применяется после перезапуска."
    public static let delayedSend = "Отложенная отправка"
    public static let delayedSendFooter = "Сообщение задерживается на указанное время, и его можно отменить, пока оно не ушло."
    public static let delayedSendSeconds = "Задержка"
}

public struct NetegramGhostSettings: Equatable {
    public let enabled: Bool
    public let flags: [String: Bool]
    public let delayedSendSeconds: Int32
    public let deviceName: String

    public init(enabled: Bool, flags: [String: Bool], delayedSendSeconds: Int32, deviceName: String) {
        self.enabled = enabled
        self.flags = flags
        self.delayedSendSeconds = delayedSendSeconds
        self.deviceName = deviceName
    }

    public func flag(_ key: String) -> Bool {
        return self.flags[key] ?? false
    }
}

public final class NetegramGhostPreferences {
    public static let shared = NetegramGhostPreferences()

    /// Every switch stored as a flag, so adding one does not mean touching the struct, the
    /// promise and three call sites.
    private static let flagKeys: [String] = [
        NetegramGhostKeys.alwaysOnline, NetegramGhostKeys.hideOnline,
        NetegramGhostKeys.typing, NetegramGhostKeys.recordVoice, NetegramGhostKeys.uploadVoice,
        NetegramGhostKeys.recordVideo, NetegramGhostKeys.uploadVideo, NetegramGhostKeys.uploadPhoto,
        NetegramGhostKeys.uploadFile, NetegramGhostKeys.recordRound, NetegramGhostKeys.uploadRound,
        NetegramGhostKeys.chooseSticker, NetegramGhostKeys.chooseLocation, NetegramGhostKeys.chooseContact,
        NetegramGhostKeys.playGame, NetegramGhostKeys.speaking, NetegramGhostKeys.emojiInteraction,
        NetegramGhostKeys.emojiSeen, NetegramGhostKeys.readReceipts, NetegramGhostKeys.storyViews,
        NetegramGhostKeys.viewOnce, NetegramGhostKeys.screenshots, NetegramGhostKeys.noAds,
        NetegramGhostKeys.readOnAction, NetegramGhostKeys.delayedSend
    ]

    private let promise: ValuePromise<NetegramGhostSettings>

    private init() {
        self.promise = ValuePromise(NetegramGhostPreferences.current(), ignoreRepeated: true)
    }

    public static func current() -> NetegramGhostSettings {
        let defaults = UserDefaults.standard
        var flags: [String: Bool] = [:]
        for key in NetegramGhostPreferences.flagKeys {
            flags[key] = defaults.bool(forKey: key)
        }
        let seconds = defaults.object(forKey: NetegramGhostKeys.delayedSendSeconds) as? Int ?? 5
        return NetegramGhostSettings(
            enabled: defaults.bool(forKey: NetegramGhostKeys.enabled),
            flags: flags,
            delayedSendSeconds: Int32(seconds),
            deviceName: defaults.string(forKey: NetegramGhostKeys.deviceName) ?? ""
        )
    }

    public var signal: Signal<NetegramGhostSettings, NoError> {
        return self.promise.get()
    }

    public func setEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: NetegramGhostKeys.enabled)
        self.promise.set(NetegramGhostPreferences.current())
    }

    /// Writing a flag, with the one rule the switches cannot express on their own: staying
    /// online and hiding that you are online are opposite instructions about the same call, so
    /// turning either on turns the other off rather than leaving both set and letting whichever
    /// branch runs first decide.
    public func setFlag(_ key: String, value: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key)
        if value {
            if key == NetegramGhostKeys.alwaysOnline {
                defaults.set(false, forKey: NetegramGhostKeys.hideOnline)
            } else if key == NetegramGhostKeys.hideOnline {
                defaults.set(false, forKey: NetegramGhostKeys.alwaysOnline)
            }
        }
        self.promise.set(NetegramGhostPreferences.current())
    }

    public func setDelayedSendSeconds(_ value: Int32) {
        UserDefaults.standard.set(Int(value), forKey: NetegramGhostKeys.delayedSendSeconds)
        self.promise.set(NetegramGhostPreferences.current())
    }

    public func setDeviceName(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: NetegramGhostKeys.deviceName)
        self.promise.set(NetegramGhostPreferences.current())
    }
}

/// Read at connection setup, where the real device model would otherwise be reported.
public func netegramCustomDeviceName() -> String? {
    let value = UserDefaults.standard.string(forKey: NetegramGhostKeys.deviceName) ?? ""
    return value.isEmpty ? nil : value
}
