# Netegram

Кастомный клиент Telegram для iOS — форк [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS) с собственным брендингом и дополнительными настройками оформления.

Собирается только на macOS: Xcode + Bazel.

---

## Что добавлено к оригиналу

### Ребрендинг

Все строки, которые видит обычный пользователь, переименованы `Telegram` → `Netegram`: интерфейс, название приложения, тексты системных разрешений на 19 языках.

Намеренно **не** тронуты:

- ключи локализации (`Chat.Context.Phone.NotOnTelegram` и др.) — по ним код ищет строки;
- домены `telegram.org`, `t.me`, `telegra.ph` — живые эндпоинты и юридические документы;
- идентификаторы `org.telegram.*`, схема `tg://`, JS-мост `TelegramWebviewProxy` — на последний завязаны mini-apps;
- сервисный аккаунт `Telegram Notifications` (peer `777000`), который присылает коды входа;
- названия других официальных клиентов — `Telegram Desktop`, `Telegram Web`, `Telegram for macOS`.

Переводы на языки кроме английского Telegram отдаёт с сервера в рантайме, поэтому в русском интерфейсе часть строк по-прежнему будет содержать «Telegram». Локально правятся только тексты разрешений iOS.

### Иконка приложения

Основная иконка — Netegram. Оригинальная артовка Telegram оставлена единственной альтернативой; остальные наборы (Black, Filled, Premium и пр.) удалены.

### Настройки → Netegram

Новая вкладка сразу после «Мой профиль», внутри — экран «Оформление» с двумя переключателями:

| Переключатель | По умолчанию | Что делает |
|---|---|---|
| Заменить логотип Telegram | выкл | Возвращает оригинальную иконку Telegram вместо Netegram |
| Кастомные иконки в настройках | выкл | Заменяет иконки строк настроек на кастомный набор |

Кастомный набор покрывает 12 строк: Мой профиль, Кошелёк, Избранное, Недавние звонки, Устройства, Папки с чатами, Уведомления и звуки, Конфиденциальность, Данные и память, Оформление, Энергосбережение, Язык.

При смене иконки приложения iOS показывает свой системный алерт — это ограничение `setAlternateIconName`, обойти штатно нельзя.

### Исправления, попутно найденные в оригинале

- **Переключение иконки приложения не работало.** `AppDelegate` передавал в `setAlternateIconName` строку `BlueIcon`, тогда как ключ в `AlternateIcons.plist` называется `Blue`.
- **`alternate_icon_folders` в `Telegram/BUILD` перечислял 12 папок**, из которых в открытом репозитории есть одна — остальные (`New1`, `Premium`, `WhiteFilledIcon` и др.) не выложены.

### Кеш сборки

В `.bazelrc` включён дисковый кеш в `~/.cache/netegram-bazel`. Bazel и сам продолжает прерванную сборку с места остановки, но его встроенный кеш лежит в output base и пропадает при `bazel clean` или свежем клоне — дисковый это переживает. Плюс `--keep_going`, чтобы ошибка в одной цели не отменяла работу, которая ещё могла бы досчитаться и лечь в кеш.

Кеш растёт неограниченно, изредка чистите папку вручную.

---

## Сборка

### 1. Свой api_id

Получите на [my.telegram.org/apps](https://my.telegram.org/apps). Ключи оригинального Telegram использовать нельзя.

### 2. Конфигурация

Файлы с ключами и данными подписи в репозиторий **не** попадают — они перечислены в `.gitignore`. После клона создайте их сами:

```bash
cp build-system/example-configuration/variables.bzl.example build-system/example-configuration/variables.bzl
```

Минимальный `build-system/my-configuration.json`:

```json
{
	"bundle_id": "org.<случайная строка>.netegram",
	"api_id": "<ваш api_id>",
	"api_hash": "<ваш api_hash>",
	"team_id": "<Apple Team ID>",
	"app_center_id": "0",
	"is_internal_build": "false",
	"is_appstore_build": "false",
	"appstore_id": "0",
	"app_specific_url_scheme": "tg",
	"premium_iap_product_id": "",
	"enable_siri": false,
	"enable_icloud": false
}
```

Случайная строка для bundle id: `openssl rand -hex 8`.
Team ID: `Keychain Access` → `Certificates` → ваш сертификат `Apple Development` → `Organizational Unit`.

### 3. Проект Xcode

```bash
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/.cache/netegram-bazel" \
    generateProject \
    --configurationPath=build-system/my-configuration.json \
    --xcodeManagedCodesigning
```

Для сборки только под симулятор подпись не нужна — добавьте `--disableProvisioningProfiles`.

### 4. IPA

```bash
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/.cache/netegram-bazel" \
    build \
    --configurationPath=build-system/my-configuration.json \
    --codesigningInformationPath=<папка с профилями> \
    --buildNumber=100001 \
    --configuration=release_arm64
```

Каждый релиз собирается конкретной версией Xcode (см. `versions.json`). Проверку можно обойти флагом `--overrideXcodeVersion`.

---

## Известные проблемы

**Xcode зависает на `build-request.json not updated yet`** — отмените сборку и запустите заново.

**`Telegram_xcodeproj: no such package`** после перезагрузки системы — перегенерируйте проект (шаг 3).

---

## Лицензия и требования

Проект основан на Telegram-iOS и распространяется на тех же условиях — исходный код форка должен оставаться открытым.

Требования Telegram к сторонним клиентам: использовать собственный `api_id`, не выдавать приложение за официальное, изучить [security guidelines](https://core.telegram.org/mtproto/security_guidelines) и бережно обращаться с данными пользователей.

Учтите, что оригинальная иконка Telegram, доступная в настройках как альтернативная, остаётся их товарным знаком — для публикации в App Store её лучше убрать.
