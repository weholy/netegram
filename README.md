# Netegram

Клиент Telegram для iOS с собственным брендингом и расширенными настройками оформления.

---

## Возможности

### Настройки → Netegram

Отдельный раздел в настройках, сразу после «Мой профиль».

### Оформление

**Заменить логотип Telegram** — возвращает оригинальную иконку Telegram вместо иконки Netegram. По умолчанию выключено.

**Кастомные иконки в настройках** — заменяет иконки строк настроек на собственный набор. Покрывает 12 строк: Мой профиль, Кошелёк, Избранное, Недавние звонки, Устройства, Папки с чатами, Уведомления и звуки, Конфиденциальность, Данные и память, Оформление, Энергосбережение, Язык. По умолчанию выключено.

### Liquid Glass

**Liquid Glass повсюду** — жидкое стекло на панелях, шапках, кнопках и блоках по всему приложению: тулбары и адресная строка браузера, навигационные бары, поисковые поля, бейджи в списке чатов, элементы управления галереей, панель вложений.

**Liquid Glass на сообщения** — прозрачные пузырьки сообщений.

**Liquid Glass на Inline-кнопки в ботах** — прозрачные кнопки под сообщениями ботов.

### Иконка приложения

Основная иконка — Netegram. Оригинальная иконка Telegram доступна как альтернативная в разделе «Оформление → Иконка приложения».

---

## Состояние

| Возможность | Состояние |
|---|---|
| Ребрендинг интерфейса | готово |
| Иконка приложения | готово |
| Раздел настроек Netegram | готово |
| Заменить логотип Telegram | готово |
| Кастомные иконки в настройках | готово |
| Liquid Glass повсюду | готово |
| Liquid Glass на сообщения | переключатель есть, отрисовка не реализована |
| Liquid Glass на Inline-кнопки | переключатель есть, отрисовка не реализована |

Пузырьки сообщений и кнопки ботов рисуются заранее подготовленными изображениями, а не через слой стекла, поэтому для них нужен отдельный путь отрисовки.

Жидкое стекло использует `UIGlassEffect` из iOS 26. На более ранних версиях включается запасной путь — обычное полупрозрачное размытие.

Переводы интерфейса на языки кроме английского приходят с сервера в момент запуска, поэтому часть строк там остаётся неизменённой.

---

## Сборка

Требуется macOS 26 и Xcode 26.2 (см. `versions.json`). Собрать под Windows или Linux нельзя.

### 1. Свой api_id

Получите на [my.telegram.org/apps](https://my.telegram.org/apps).

### 2. Конфигурация

Файлы с ключами и данными подписи в репозиторий не входят — они перечислены в `.gitignore`. После клона создайте `build-system/my-configuration.json`:

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

Случайная строка: `openssl rand -hex 8`.
Team ID: `Keychain Access` → `Certificates` → сертификат `Apple Development` → `Organizational Unit`.

Для переменных Bazel скопируйте `build-system/example-configuration/variables.bzl.example` в `variables.bzl` и заполните.

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

### Кеш

В `.bazelrc` включён дисковый кеш в `~/.cache/netegram-bazel`. Он переживает `bazel clean` и свежий клон, поэтому прерванная сборка продолжается с места остановки. Кеш растёт неограниченно — изредка чистите папку вручную.

### Сборка на GitHub Actions

Workflow `.github/workflows/build.yml` собирает неподписанный IPA на раннере `macos-26` и складывает его в артефакты сборки. Перед первым запуском задайте секреты `API_ID` и `API_HASH` в `Settings → Secrets and variables → Actions`.

---

## Известные проблемы

**Xcode зависает на `build-request.json not updated yet`** — отмените сборку и запустите заново.

**`Telegram_xcodeproj: no such package`** после перезагрузки — перегенерируйте проект.

---

## Лицензия

Проект основан на [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS) и распространяется на тех же условиях: исходный код должен оставаться открытым.

Требования к сторонним клиентам: использовать собственный `api_id`, не выдавать приложение за официальное, соблюдать [security guidelines](https://core.telegram.org/mtproto/security_guidelines).

Оригинальная иконка Telegram, доступная как альтернативная, остаётся товарным знаком Telegram — для публикации в App Store её лучше убрать.
