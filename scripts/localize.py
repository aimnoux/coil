#!/usr/bin/env python3
"""Builds Coil/Resources/Localizable.xcstrings from the strings extracted during a build.

Usage (after an `xcodebuild ... build` with -derivedDataPath build):
    python3 scripts/localize.py

Keys come from the compiler's .stringsdata output; Russian translations live below.
Keys without a translation are reported so nothing is silently left in English.
"""
import glob
import json
import sys

STRINGSDATA = "build/Build/Intermediates.noindex/Coil.build/Debug-iphonesimulator/*.build/Objects-normal/arm64/*.stringsdata"
OUTPUT = "Coil/Resources/Localizable.xcstrings"

# Keys that are identical in every language and need no translation.
UNTRANSLATED = {" ", "%@", "%@ %@", "%@ / %@ %@", "%@.csv", "0", "—"}


def plural(**forms):
    return {"plural": forms}


# Russian plural categories: one (1, 21), few (2–4, 22–24), many (5–20, 25–30), other (fractions).
RU = {
    "%lld days": plural(one="%lld день", few="%lld дня", many="%lld дней", other="%lld дня"),
    "%lld days, %@ – %@": "%1$lld дн., %2$@ – %3$@",
    "%lld times in %lld days": "%1$lld × за %2$lld дн.",
    "%lld times per month": plural(one="%lld раз в месяц", few="%lld раза в месяц", many="%lld раз в месяц", other="%lld раза в месяц"),
    "%lld times per week": plural(one="%lld раз в неделю", few="%lld раза в неделю", many="%lld раз в неделю", other="%lld раза в неделю"),
    "About": "О приложении",
    "Add Habit": "Добавить привычку",
    "Added %lld habits, updated %lld, imported %lld entries.": "Добавлено привычек: %1$lld, обновлено: %2$lld, импортировано отметок: %3$lld.",
    "All done for today": "На сегодня всё",
    "Allow Notifications": "Разрешить уведомления",
    "Allow Skipping Days": "Разрешить пропуск дней",
    "Amber": "Янтарный",
    "Appearance": "Оформление",
    "Archive": "В архив",
    "Archived": "В архиве",
    "At least": "Не меньше",
    "At most": "Не больше",
    "Best Streaks": "Лучшие серии",
    "Blue": "Синий",
    "Brown": "Коричневый",
    "Build good habits by checking them off every day. Your progress turns into habit strength over time.":
        "Формируйте полезные привычки, отмечая их каждый день. Со временем прогресс превращается в силу привычки.",
    "Calendar": "Календарь",
    "Cancel": "Отменить",
    "Check it off when you do it. For example: did you exercise today?":
        "Отмечайте, когда сделали. Например: занимались ли вы сегодня спортом?",
    "Checkmarks": "Отметки",
    "Clear Entry": "Удалить отметку",
    "Coil is free, has no ads and collects no data. Inspired by Loop Habit Tracker.":
        "Coil бесплатный, без рекламы и не собирает данные. Вдохновлён Loop Habit Tracker.",
    "Color": "Цвет",
    "Completed habits are hidden.": "Выполненные привычки скрыты.",
    "Coral": "Коралловый",
    "Count": "Количество",
    "Custom": "Своя",
    "Cyan": "Голубой",
    "Dark": "Тёмная",
    "Data": "Данные",
    "Date": "Дата",
    "Day": "День",
    "Delete": "Удалить",
    "Delete %@": "Удалить «%@»",
    "Delete Habit": "Удалить привычку",
    "Delete this habit?": "Удалить эту привычку?",
    "Did you exercise today?": "Занимались сегодня спортом?",
    "Done": "Готово",
    "Done for this period": "Выполнено за период",
    "Edit": "Изменить",
    "Edit Habit": "Изменить привычку",
    "Every": "Каждые",
    "Every %lld days": plural(one="Каждый %lld день", few="Каждые %lld дня", many="Каждые %lld дней", other="Каждые %lld дня"),
    "Every day": "Каждый день",
    "Every few days": "Раз в несколько дней",
    "Every month": "Каждый месяц",
    "Every week": "Каждую неделю",
    "Exercise": "Спорт",
    "Export CSV": "Экспорт в CSV",
    "Export Full Backup": "Экспорт полной копии",
    "Export as CSV": "Экспорт в CSV",
    "First Day of Week": "Первый день недели",
    "Frequency": "Частота",
    "Goal": "Цель",
    "Graphite": "Графитовый",
    "Green": "Зелёный",
    "Group By": "Группировать",
    "Habit Strength": "Сила привычки",
    "Habit archived": "Привычка в архиве",
    "Habit restored": "Привычка восстановлена",
    "Habit strength": "Сила привычки",
    "Habit strength takes the frequency into account: a weekly habit isn't hurt by the days it isn't due.":
        "Сила привычки учитывает частоту: еженедельная привычка не слабеет в дни, когда её не нужно выполнять.",
    "Habits": "Привычки",
    "Hide Completed": "Скрыть выполненные",
    "History": "История",
    "How many pages did you read today?": "Сколько страниц вы прочитали сегодня?",
    "Import Backup": "Импорт копии",
    "Import Complete": "Импорт завершён",
    "Import Failed": "Не удалось импортировать",
    "Import a Coil backup, or the full backup (.db file) from Loop Habit Tracker for Android: in Loop, open Settings → Export full backup.":
        "Импортируйте копию Coil или полную резервную копию (файл .db) из Loop Habit Tracker для Android: в Loop откройте «Настройки» → «Экспорт полной копии».",
    "In days": "За дней",
    "Indigo": "Индиго",
    "Its whole history will be deleted. This can't be undone.": "Вся история привычки будет удалена. Это нельзя отменить.",
    "Light": "Светлая",
    "Lime": "Лаймовый",
    "Magenta": "Пурпурный",
    "Manual": "Вручную",
    "Measurable": "Измеримая",
    "Mint": "Мятный",
    "Month": "Месяц",
    "More": "Ещё",
    "Name": "Название",
    "New Habit": "Новая привычка",
    "No Habits Yet": "Привычек пока нет",
    "No entry": "Нет отметки",
    "No streaks yet. Check off the habit on consecutive days to start one.":
        "Серий пока нет. Отмечайте привычку несколько дней подряд, чтобы начать серию.",
    "Not done": "Не выполнено",
    "Notes": "Заметки",
    "Notifications Are Off": "Уведомления выключены",
    "Notifications Are On": "Уведомления включены",
    "Notifications are turned off for Coil. Turn them on in the Settings app to get reminders.":
        "Уведомления для Coil выключены. Включите их в приложении «Настройки», чтобы получать напоминания.",
    "Now": "Сейчас",
    "Off": "Выкл.",
    "On": "Вкл.",
    "Once a month": "Раз в месяц",
    "Once a week": "Раз в неделю",
    "Orange": "Оранжевый",
    "Overview": "Обзор",
    "Period": "Период",
    "Pink": "Розовый",
    "Press and Hold to Check Off": "Отмечать долгим нажатием",
    "Press and hold to check off": "Нажмите и удерживайте, чтобы отметить",
    "Privacy Policy": "Политика конфиденциальности",
    "Purple": "Фиолетовый",
    "Quarter": "Квартал",
    "Question": "Вопрос",
    "Read": "Чтение",
    "Red": "Красный",
    "Remind Me Later": "Напомнить позже",
    "Remind Me Later After": "Напомнить позже через",
    "Reminder": "Напоминание",
    "Reminders": "Напоминания",
    "Reorder Habits": "Изменить порядок",
    "Repeat": "Повтор",
    "Rose": "Розовый светлый",
    "Sand": "Песочный",
    "Save": "Сохранить",
    "Score": "Сила",
    "Set a reminder for each habit in its settings. From a reminder you can check off the habit or ask to be reminded later.":
        "Напоминание настраивается для каждой привычки отдельно. Прямо из напоминания можно отметить привычку или попросить напомнить позже.",
    "Settings": "Настройки",
    "Show Archived": "Показать архив",
    "Show Question Marks": "Показывать вопросительные знаки",
    "Shows statistics": "Показывает статистику",
    "Skip This Day": "Пропустить день",
    "Skipped": "Пропущено",
    "Skipped days, like a sick day or holiday, don't break your streak or lower habit strength. Question marks show days you haven't entered yet, so they look different from days you marked as not done.":
        "Пропущенные дни, например болезнь или отпуск, не прерывают серию и не снижают силу привычки. Вопросительные знаки показывают дни без отметки, чтобы их можно было отличить от дней, отмеченных как невыполненные.",
    "Slate": "Сланцевый",
    "Sort By": "Сортировка",
    "Sort and Filter": "Сортировка и фильтр",
    "Status": "Статус",
    "Streak": "Серия",
    "Strength": "Сила",
    "System": "Системная",
    "Tap a day to change it.": "Нажмите на день, чтобы изменить отметку.",
    "Tap a day to change its value.": "Нажмите на день, чтобы изменить значение.",
    "Target": "Цель",
    "Teal": "Бирюзовый",
    "The day counts as done as long as you stay under the target.": "День засчитывается, если вы не превысили цель.",
    "The day counts as done once you reach the target.": "День засчитывается, когда вы достигли цели.",
    "The file couldn't be read.": "Не удалось прочитать файл.",
    "The question appears in reminders.": "Вопрос показывается в напоминаниях.",
    "Theme": "Тема",
    "This isn't a Coil backup or a Loop Habit Tracker database.": "Это не копия Coil и не база данных Loop Habit Tracker.",
    "This month": "Этот месяц",
    "This quarter": "Этот квартал",
    "This week": "Эта неделя",
    "This year": "Этот год",
    "Time": "Время",
    "Time to keep your streak going.": "Пора продолжить серию.",
    "Times": "Раз",
    "Times done": "Выполнено раз",
    "Times per month": "Раз в месяц",
    "Times per week": "Раз в неделю",
    "Today": "Сегодня",
    "Today on the Right": "Сегодня справа",
    "Total": "Всего",
    "Track a number every day. For example: how many pages did you read?":
        "Записывайте число каждый день. Например: сколько страниц вы прочитали?",
    "Type": "Тип",
    "Unarchive": "Из архива",
    "Unit": "Единица",
    "Version": "Версия",
    "Week": "Неделя",
    "Why this habit matters, tips, anything": "Зачем вам эта привычка, советы, что угодно",
    "Year": "Год",
    "Yellow": "Жёлтый",
    "Yes or No": "Да или нет",
    "Your habits are stored only on this device. Export a backup from time to time to keep them safe.":
        "Привычки хранятся только на этом устройстве. Время от времени делайте резервную копию, чтобы их не потерять.",
    "Your habits sync across your devices through your private iCloud account.":
        "Привычки синхронизируются между вашими устройствами через ваш личный iCloud.",
    "every %lld days": plural(one="каждый %lld день", few="каждые %lld дня", many="каждые %lld дней", other="каждые %lld дня"),
    "iCloud Sync": "Синхронизация iCloud",
    "pages, km, glasses…": "страницы, км, стаканы…",
    "per day": "в день",
    "per month": "в месяц",
    "per week": "в неделю",
    "strength": "сила",
    # Intents and widgets
    "%@: strength %@, streak %lld days. %@": "%1$@: сила %2$@, серия %3$lld дн. %4$@",
    "Add a habit in Coil": "Добавьте привычку в Coil",
    "Already done today.": "Сегодня уже выполнено.",
    "Amount": "Значение",
    "Check off a habit and see its strength.": "Отмечайте привычку и следите за её силой.",
    "Check off today's habits from the Home Screen.": "Отмечайте привычки прямо с экрана «Домой».",
    "Checks off a habit for today.": "Отмечает привычку как выполненную сегодня.",
    "Choose Habit": "Выбрать привычку",
    "Choose the habit to show.": "Выберите привычку для виджета.",
    "Done! %@ streak: %lld days.": "Готово! Серия «%1$@»: %2$lld дн.",
    "For measurable habits: the value to record.": "Для измеримых привычек: значение, которое нужно записать.",
    "Get Habit Status": "Узнать статус привычки",
    "Habit": "Привычка",
    "Habit ID": "ID привычки",
    "Habit Status": "Статус привычки",
    "Mark ${habit} as done": "Отметить ${habit} как выполненную",
    "Mark Habit as Done": "Отметить привычку",
    "Mark as Done": "Отметить",
    "Meditate": "Медитация",
    "Not done yet today.": "Сегодня ещё не выполнено.",
    "Strength %@ · %lld days": "Сила %1$@ · %2$lld дн.",
    "Tells you a habit's strength and current streak.": "Сообщает силу привычки и текущую серию.",
    "Toggle Habit": "Переключить привычку",
    "Wake up early": "Ранний подъём",
    # Sample data
    "Did you meditate today?": "Медитировали сегодня?",
    "How many pages did you read?": "Сколько страниц прочитали?",
    "Did you wake up before 7?": "Встали раньше семи?",
    "Drink water": "Пить воду",
    "How many glasses of water?": "Сколько стаканов воды?",
    "Call parents": "Звонок родителям",
    "Did you call your parents?": "Звонили родителям?",
    "Coffee": "Кофе",
    "How many cups of coffee?": "Сколько чашек кофе?",
    "pages": "стр.",
    "glasses": "стак.",
    "cups": "чаш.",
}

# English plural forms for keys that need them.
EN = {
    "%lld days": plural(one="%lld day", other="%lld days"),
    "Every %lld days": plural(one="Every day", other="Every %lld days"),
    "every %lld days": plural(one="every day", other="every %lld days"),
    "%lld times per week": plural(one="Once a week", other="%lld times per week"),
    "%lld times per month": plural(one="Once a month", other="%lld times per month"),
}


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def localization(value):
    if isinstance(value, dict) and "plural" in value:
        return {"variations": {"plural": {k: unit(v) for k, v in value["plural"].items()}}}
    return unit(value)


def main():
    keys = set()
    for path in glob.glob(STRINGSDATA):
        if "CoilTests" in path:
            continue
        data = json.load(open(path))
        for item in data.get("tables", {}).get("Localizable", []):
            keys.add(item["key"])
    if not keys:
        sys.exit("No .stringsdata found — build the app first.")

    strings = {}
    missing = []
    for key in sorted(keys):
        if key in UNTRANSLATED:
            strings[key] = {"shouldTranslate": False}
            continue
        entry = {"extractionState": "manual", "localizations": {}}
        if key in EN:
            entry["localizations"]["en"] = localization(EN[key])
        if key in RU:
            entry["localizations"]["ru"] = localization(RU[key])
        else:
            missing.append(key)
        strings[key] = entry

    catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    with open(OUTPUT, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    print(f"Wrote {len(strings)} strings to {OUTPUT}")
    if missing:
        print("Missing Russian translations:")
        for key in missing:
            print(f"  {key!r}")


if __name__ == "__main__":
    main()
