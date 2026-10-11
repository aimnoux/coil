# Coil

iOS-трекер привычек. Цель v1 — функционально повторить Android-приложение
**Loop Habit Tracker** (github.com/iSoron/uhabits), но с нативным iOS-дизайном
(SwiftUI, системные компоненты, Human Interface Guidelines) и синхронизацией через iCloud.
Приложение полностью бесплатное: без рекламы, покупок и подписок.

Общение с владельцем проекта — на русском.

## Правила

- **Не копировать код, иконки и графику Loop.** Loop распространяется под GPLv3: перенос его
  кода, даже переводом с Kotlin на Swift, сделает Coil производной работой. Повторяем только
  поведение и функции, реализация пишется с нуля.
- **SwiftData-модели сразу совместимы с CloudKit** (iCloud включим после оплаты Apple Developer Program):
  - у каждого свойства есть значение по умолчанию, либо оно опциональное;
  - никаких `@Attribute(.unique)`;
  - все связи опциональные, без delete rule `.deny`.
- Перед релизом с iCloud нужно задеплоить схему CloudKit в Production (CloudKit Console).
- Виджеты и iCloud требуют платного аккаунта (App Groups / CloudKit), до этого — только локально.
- UI на английском, локализации (включая русскую) — через String Catalog.

## Проект

- Файл проекта генерируется **XcodeGen** из `project.yml`; `Coil.xcodeproj` в `.gitignore`.
  После добавления/удаления файлов или правки `project.yml` — запустить `xcodegen`.
- Bundle ID: `com.maxouni.coil`. Минимальная iOS: 18.0. Только iPhone, портретная ориентация.
- Тесты — Swift Testing, таргет `CoilTests`.

## Команды

```bash
xcodegen                                   # сгенерировать Coil.xcodeproj
open Coil.xcodeproj                        # открыть в Xcode
xcodebuild -scheme Coil -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme Coil -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Процесс

Маленькие законченные шаги, коммит после каждой работающей функции.
