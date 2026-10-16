# Публикация в App Store

Черновики всех текстов и ответов для App Store Connect. Лимиты символов указаны в скобках.

## Основное

| Поле | Значение |
|---|---|
| Название (30) | `Coil: Habit Tracker` |
| Bundle ID | `com.maxouni.coil` |
| SKU | `coil-ios` |
| Основной язык | English (U.S.), плюс локализация Russian |
| Категория | Productivity (дополнительная: Health & Fitness) |
| Цена | Бесплатно |
| Copyright | `2026 <ваше имя>` |

### Подзаголовок (30)

- EN: `Build habits, see your strength`
- RU: `Привычки и их сила каждый день`

### Ключевые слова (100, через запятую без пробелов)

- EN: `habit,tracker,routine,streak,goals,daily,loop,check,list,productivity,self,improvement,reminder,journal`
- RU: `привычки,трекер,цели,рутина,серия,ежедневник,чеклист,мотивация,саморазвитие,напоминания,дисциплина`

> Слово `loop` в ключевых словах допустимо: это общее слово. Но **не используйте «Loop Habit Tracker»
> в названии, подзаголовке и описании**: это чужая торговая марка (guideline 4.1 и 5.2).

### Описание — English (до 4000)

```
Coil helps you build good habits and keep them — with a clear picture of how strong each habit really is.

CHECK OFF YOUR DAY
• See all your habits and the last few days at a glance
• Tap to check off, skip a sick day, or mark a miss
• Swipe back through older days to fill in what you forgot

HABIT STRENGTH, NOT JUST STREAKS
Every repetition makes a habit stronger and every miss makes it a little weaker — but one bad day doesn't wipe out months of progress. Coil's habit strength takes your schedule into account, so a weekly habit isn't punished on the days it isn't due.

FLEXIBLE SCHEDULES
• Every day, every few days, 3 times a week, 10 times a month, or any custom rhythm
• Measurable habits: pages read, glasses of water, kilometers run — with "at least" or "at most" targets

DETAILED STATISTICS
• Habit strength chart and history by week, month, quarter or year
• A calendar of your whole history — tap any day to change it
• Best streaks and the weekdays you're most consistent on
• Progress towards your target for the day, week, month and year

REMINDERS
Get a reminder at the time and on the days you choose. Check off the habit right from the notification, or ask to be reminded later.

YOUR DATA STAYS YOURS
• No account, no ads, no tracking — Coil collects no data
• Export to CSV or a full backup at any time
• Moving from Android? Import your full backup from Loop Habit Tracker

Works with Siri and Shortcuts. Light and dark mode. Completely free.
```

### Описание — Русский (до 4000)

```
Coil помогает формировать полезные привычки и не бросать их — и показывает, насколько каждая привычка на самом деле сильна.

ОТМЕЧАЙТЕ СВОЙ ДЕНЬ
• Все привычки и последние дни на одном экране
• Одно касание — выполнено; можно пропустить день болезни или отметить неудачу
• Листайте назад, чтобы заполнить забытые дни

СИЛА ПРИВЫЧКИ, А НЕ ТОЛЬКО СЕРИИ
Каждое повторение укрепляет привычку, каждый пропуск немного ослабляет — но один плохой день не перечёркивает месяцы прогресса. Сила привычки учитывает ваше расписание: еженедельная привычка не слабеет в дни, когда её не нужно делать.

ГИБКОЕ РАСПИСАНИЕ
• Каждый день, раз в несколько дней, 3 раза в неделю, 10 раз в месяц или любой свой ритм
• Измеримые привычки: страницы, стаканы воды, километры — с целью «не меньше» или «не больше»

ПОДРОБНАЯ СТАТИСТИКА
• График силы привычки и история по неделям, месяцам, кварталам и годам
• Календарь всей истории — любой день можно изменить касанием
• Лучшие серии и дни недели, в которые вы стабильнее всего
• Прогресс к цели за день, неделю, месяц и год

НАПОМИНАНИЯ
Напоминание в нужное время и в выбранные дни. Отметьте привычку прямо из уведомления или попросите напомнить позже.

ВАШИ ДАННЫЕ — ТОЛЬКО ВАШИ
• Без аккаунта, рекламы и слежки — Coil не собирает данные
• Экспорт в CSV и полная резервная копия в любой момент
• Переходите с Android? Импортируйте полную копию из Loop Habit Tracker

Работает с Siri и «Командами». Светлая и тёмная тема. Полностью бесплатно.
```

### Что нового (для первой версии)

- EN: `First release of Coil. Thanks for trying it!`
- RU: `Первая версия Coil. Спасибо, что попробовали!`

## Ссылки

- **Privacy Policy URL** (обязательно): политика лежит в [docs/privacy-policy.md](privacy-policy.md).
  Ссылка должна открываться **публично**, а репозиторий приватный. Варианты: опубликовать файл
  на GitHub Pages из отдельного публичного репозитория, в Notion (Share → Publish), в Telegraph.
  Перед публикацией замените `CONTACT_EMAIL` на адрес для связи и обновите ссылку в
  [SettingsView.swift](../Coil/Views/Settings/SettingsView.swift) (секция «About»).
- **Support URL** (обязательно): подойдёт та же страница или Telegram-канал.

## App Privacy (анкета о данных)

Ответ: **Data Not Collected** («Данные не собираются»). Приложение ничего не отправляет разработчику;
iCloud-синхронизация идёт через личную базу пользователя и в анкете не считается сбором данных разработчиком.

## Возрастной рейтинг

На все вопросы анкеты (насилие, азартные игры, медицинская информация, неконтролируемый контент и т.д.)
ответ «Нет» → рейтинг **4+**.

## Шифрование (Export Compliance)

Уже отвечено в сборке: `ITSAppUsesNonExemptEncryption = NO` в [project.yml](../project.yml).
App Store Connect не будет задавать вопрос при каждой загрузке.

## Заметки для ревьюера (App Review Information → Notes)

```
Coil is a habit tracker. No account or login is needed.
To try it quickly: tap + to add a habit, then tap the checkmarks on the main screen.
Tap a habit's name to open its statistics.
Settings → Import Backup accepts a Coil backup or a database exported by the Android app Loop Habit Tracker (open-source, GPL); Coil does not contain any of its code.
```

## Скриншоты

Готовые скриншоты для iPhone 6.9" (1320×2868) лежат в [docs/screenshots](screenshots):
по 5 штук на русском (`ru/`) и английском (`en/`) — главный экран, экран привычки,
измеримая привычка, редактирование, тёмная тема. Их можно сразу загружать в App Store Connect.

Как переснять (например, после изменений интерфейса):

```bash
xcodegen
xcodebuild -scheme Coil -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath build build
D="iPhone 18 Pro Max"
xcrun simctl boot "$D"
xcrun simctl install "$D" build/Build/Products/Debug-iphonesimulator/Coil.app
xcrun simctl status_bar "$D" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4
# Русская версия (для английской: -AppleLanguages "(en)" -AppleLocale en_US)
xcrun simctl launch "$D" com.maxouni.coil -sampleData -AppleLanguages "(ru)" -AppleLocale ru_RU
xcrun simctl io "$D" screenshot 01-habits.png
```

Отладочные аргументы (работают только в Debug-сборке):
- `-sampleData` — демо-привычки во временной базе;
- `-screenshotHabit 0` — сразу открыть экран первой привычки (`2` — измеримая «Чтение»);
- `-screenshotEditor YES` — открыть редактирование первой привычки;
- тёмная тема: `xcrun simctl ui "$D" appearance dark`.

## Чек-лист перед отправкой

- [ ] Apple Developer Program оплачен, `DEVELOPMENT_TEAM` указан в `project.yml`
- [ ] `COIL_ICLOUD=true COIL_WIDGETS=true xcodegen`, проверено на устройстве ([ICLOUD.md](ICLOUD.md))
- [ ] Схема CloudKit задеплоена в Production
- [ ] `MARKETING_VERSION` и `CURRENT_PROJECT_VERSION` в `project.yml` (для каждой загрузки build +1)
- [ ] Политика конфиденциальности опубликована, ссылка в приложении обновлена
- [ ] Product → Archive → Distribute App → App Store Connect
- [ ] В App Store Connect: тексты, скриншоты, App Privacy, рейтинг, выбрать сборку → Submit for Review
