# Coil

iOS-трекер привычек. Цель v1 — функционально повторить Android-приложение
**Loop Habit Tracker** (github.com/iSoron/uhabits), но с нативным iOS-дизайном
(SwiftUI, системные компоненты, Human Interface Guidelines) и синхронизацией через iCloud.
Приложение полностью бесплатное: без рекламы, покупок и подписок.

Общение с владельцем проекта — на русском. Документация в `docs/` и README — на русском.

## Правила

- **Не копировать код, иконки и графику Loop.** Loop распространяется под GPLv3: перенос его
  кода, даже переводом с Kotlin на Swift, сделает Coil производной работой. Повторяем только
  поведение и функции, реализация пишется с нуля. Читать формат базы Loop для импорта — можно.
- **SwiftData-модели совместимы с CloudKit:**
  - у каждого свойства есть значение по умолчанию, либо оно опциональное;
  - никаких `@Attribute(.unique)`;
  - все связи опциональные, без delete rule `.deny`;
  - после релиза поля не переименовывать и не удалять.
- Логика (сила привычки, серии, частота) — в `Coil/Domain`, чистые типы без SwiftData, с тестами.
  Вьюхи получают `HabitStats` через `habit.stats(today:)`.
- Дни хранятся как `Day` (индекс дня от 2001-01-01), не как `Date`, чтобы не зависеть от часового пояса.
- В проекте `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Типы, которые нужны вне главного актора
  (domain, Transferable, Codable для бэкапов, данные виджетов), помечены `nonisolated`.
- UI на английском, переводы — в `scripts/localize.py` (словарь `RU`). После добавления строк:
  собрать с `COIL_WIDGETS=true`, затем `python3 scripts/localize.py`; скрипт покажет строки без перевода.

## Проект

- Файл проекта генерируется **XcodeGen** из `project.yml`; `Coil.xcodeproj` в `.gitignore`.
  После добавления/удаления файлов или правки `project.yml` — запустить `xcodegen`.
- Платные возможности подключаются include-файлами по переменным окружения:
  - `widgets.yml` (`COIL_WIDGETS=true`) — расширение `CoilWidgets` + App Group;
  - `icloud.yml` (`COIL_ICLOUD=true`) — CloudKit, флаг компиляции `ICLOUD`.
  По умолчанию оба выключены, чтобы приложение подписывалось бесплатным Apple ID.
- Bundle ID: `com.maxouni.coil`. App Group: `group.com.maxouni.coil`. iCloud: `iCloud.com.maxouni.coil`.
- Минимальная iOS: 18.0. Только iPhone, портретная ориентация.
- Тесты — Swift Testing, таргет `CoilTests`. В тестах держать ссылку на `ModelContainer`,
  а не только на `mainContext`, иначе контейнер освобождается и тест падает.

## Команды

```bash
xcodegen                                   # сгенерировать Coil.xcodeproj
xcodebuild -scheme Coil -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build build
xcodebuild -scheme Coil -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build test
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Coil.app
xcrun simctl launch booted com.maxouni.coil -sampleData                      # демо-данные в памяти
xcrun simctl launch booted com.maxouni.coil -sampleData -AppleLanguages "(ru)" -AppleLocale ru_RU
```

## Документация

- `docs/INSTALL_ON_IPHONE.md` — бесплатная установка на свой iPhone, перенос данных из Loop
- `docs/ICLOUD.md`, `docs/WIDGETS.md` — включение платных возможностей
- `docs/APP_STORE.md` — тексты, ключевые слова, анкеты, скриншоты, чек-лист публикации
- `docs/privacy-policy.md` — политика конфиденциальности (нужно опубликовать публично)

## Процесс

Маленькие законченные шаги, коммит после каждой работающей функции.
