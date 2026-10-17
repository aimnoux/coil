import Foundation

/// Text in both supported languages. Templates are data, so they carry their own translations
/// instead of filling the string catalog with hundreds of entries.
struct Bilingual: Hashable {
    let en: String
    let ru: String

    init(_ en: String, _ ru: String) {
        self.en = en
        self.ru = ru
    }

    var text: String {
        Locale.current.language.languageCode?.identifier == "ru" ? ru : en
    }
}

/// A ready-made habit to start from.
struct HabitTemplate: Identifiable, Hashable {
    let name: Bilingual
    let question: Bilingual
    let icon: String
    let color: Int
    var kind: HabitKind = .yesNo
    var frequency: Frequency = .daily
    var unit: Bilingual?
    var target: Double = 0
    var targetType: TargetType = .atLeast
    var timed = false
    var timerMinutes = 0
    var challengeDays = 0
    var health: HealthMetric?
    /// Minutes after midnight.
    var reminder: Int?

    var id: String { name.en }

    var draft: HabitDraft {
        var d = HabitDraft()
        d.kind = kind
        d.name = name.text
        d.question = question.text
        d.iconName = icon
        d.colorIndex = color
        d.schedule = ScheduleDraft(frequency)
        d.targetPeriod = TargetPeriod(frequency)
        d.unit = unit?.text ?? ""
        d.targetValue = kind == .measurable ? target : nil
        d.targetType = targetType
        d.isTimed = timed
        d.timerMinutes = timerMinutes
        d.challengeDays = challengeDays
        if HealthSync.isSupported, let health {
            d.healthMetric = health
            if kind == .yesNo { d.healthThreshold = target > 0 ? target : health.suggestedTarget }
        }
        if let reminder {
            d.reminderEnabled = true
            d.reminderTimes = [reminder]
        }
        return d
    }

    /// One line describing the schedule or target, for the template list.
    var summary: String {
        switch kind {
        case .quit:
            return challengeDays > 0
                ? String(localized: "Quit · \(challengeDays) days")
                : String(localized: "Quitting")
        case .measurable:
            let comparison = targetType == .atLeast ? String(localized: "At least") : String(localized: "At most")
            let unitText = timed ? String(localized: "min") : (unit?.text ?? "")
            var text = "\(comparison) \(Formatting.number(target)) \(unitText) \(Formatting.targetPeriod(frequency))"
            if challengeDays > 0 { text += " · " + String(localized: "\(challengeDays) days") }
            return text
        case .yesNo:
            var text = Formatting.frequency(frequency)
            if challengeDays > 0 { text += " · " + String(localized: "\(challengeDays) days") }
            return text
        }
    }

    func matches(_ query: String) -> Bool {
        query.isEmpty
            || name.en.localizedCaseInsensitiveContains(query)
            || name.ru.localizedCaseInsensitiveContains(query)
    }
}

struct TemplateCategory: Identifiable {
    let title: Bilingual
    let icon: String
    let templates: [HabitTemplate]
    var id: String { title.en }
}

// Color indexes: 0 red, 1 coral, 2 orange, 3 amber, 4 yellow, 5 lime, 6 green, 7 mint, 8 teal,
// 9 cyan, 10 blue, 11 indigo, 12 purple, 13 magenta, 14 pink, 15 rose, 16 brown, 17 sand,
// 18 slate, 19 graphite.
// swiftlint:disable line_length
enum HabitTemplates {
    private typealias T = HabitTemplate
    private typealias B = Bilingual

    private static let min = B("min", "мин")
    private static let glasses = B("glasses", "стак.")
    private static let pages = B("pages", "стр.")
    private static let km = B("km", "км")
    private static let times = B("times", "раз")
    private static let words = B("words", "слов")
    private static let hours = B("h", "ч")

    static let popular = TemplateCategory(title: B("Popular", "Популярные"), icon: "star", templates: [
        T(name: B("Drink water", "Пить воду"), question: B("How many glasses of water today?", "Сколько стаканов воды сегодня?"), icon: "drop", color: 9, kind: .measurable, unit: glasses, target: 8, health: .water),
        T(name: B("Exercise", "Тренировка"), question: B("Did you exercise today?", "Была сегодня тренировка?"), icon: "figure.run", color: 6, frequency: Frequency(3, 7)),
        T(name: B("Read", "Чтение"), question: B("How many pages did you read?", "Сколько страниц прочитали?"), icon: "book", color: 3, kind: .measurable, unit: pages, target: 20),
        T(name: B("Meditate", "Медитация"), question: B("How long did you meditate?", "Сколько минут медитировали?"), icon: "brain.head.profile", color: 12, kind: .measurable, target: 10, timed: true, timerMinutes: 10, health: .mindfulMinutes),
        T(name: B("Walk 8,000 steps", "8 000 шагов"), question: B("Did you walk 8,000 steps?", "Прошли 8 000 шагов?"), icon: "figure.walk", color: 7, kind: .measurable, unit: B("steps", "шагов"), target: 8000, health: .steps),
        T(name: B("Sleep 8 hours", "Спать 8 часов"), question: B("Did you get 8 hours of sleep?", "Спали 8 часов?"), icon: "bed.double", color: 11, kind: .measurable, unit: hours, target: 8, health: .sleepHours),
        T(name: B("Wake up early", "Ранний подъём"), question: B("Did you wake up on time?", "Встали вовремя?"), icon: "sunrise", color: 2),
        T(name: B("Journal", "Дневник"), question: B("Did you write in your journal?", "Писали сегодня в дневник?"), icon: "pencil.and.scribble", color: 17, reminder: 21 * 60 + 30),
        T(name: B("No smoking", "Не курить"), question: B("Stayed smoke-free today?", "Сегодня без сигарет?"), icon: "nosign", color: 18, kind: .quit),
        T(name: B("Learn a language", "Изучать язык"), question: B("How long did you practise?", "Сколько минут занимались?"), icon: "character.book.closed", color: 10, kind: .measurable, target: 15, timed: true, timerMinutes: 15),
    ])

    static let health = TemplateCategory(title: B("Health", "Здоровье"), icon: "heart", templates: [
        T(name: B("Take vitamins", "Пить витамины"), question: B("Did you take your vitamins?", "Выпили витамины?"), icon: "pills", color: 4, reminder: 9 * 60),
        T(name: B("Take medication", "Принять лекарство"), question: B("Did you take your medication?", "Приняли лекарство?"), icon: "cross.case", color: 0, reminder: 9 * 60),
        T(name: B("Floss", "Зубная нить"), question: B("Did you floss today?", "Пользовались зубной нитью?"), icon: "mouth", color: 7, reminder: 22 * 60),
        T(name: B("Brush teeth twice", "Чистить зубы дважды"), question: B("Did you brush your teeth twice?", "Почистили зубы дважды?"), icon: "sparkles", color: 9),
        T(name: B("Skincare", "Уход за кожей"), question: B("Did you do your skincare routine?", "Сделали уход за кожей?"), icon: "drop.fill", color: 15),
        T(name: B("Sunscreen", "Солнцезащитный крем"), question: B("Did you put on sunscreen?", "Нанесли солнцезащитный крем?"), icon: "sun.max", color: 3),
        T(name: B("Eye breaks", "Перерывы для глаз"), question: B("Did you rest your eyes every hour?", "Делали перерывы для глаз?"), icon: "eye", color: 8),
        T(name: B("Good posture", "Ровная осанка"), question: B("Did you watch your posture?", "Следили за осанкой?"), icon: "figure.stand", color: 10),
        T(name: B("Weigh in", "Взвешиваться"), question: B("Did you weigh in this week?", "Взвесились на этой неделе?"), icon: "scalemass", color: 18, frequency: .weekly),
        T(name: B("Stand every hour", "Вставать каждый час"), question: B("Did you stand at least 10 hours?", "Вставали хотя бы 10 часов?"), icon: "figure.stand", color: 5, kind: .measurable, unit: hours, target: 10, health: .standHours),
        T(name: B("Drink 2 liters", "Выпивать 2 литра"), question: B("How much water did you drink?", "Сколько воды выпили?"), icon: "waterbottle", color: 9, kind: .measurable, unit: B("L", "л"), target: 2, health: .water),
        T(name: B("Cold shower", "Холодный душ"), question: B("Did you take a cold shower?", "Приняли холодный душ?"), icon: "snowflake", color: 9),
    ])

    static let fitness = TemplateCategory(title: B("Fitness", "Спорт"), icon: "figure.run", templates: [
        T(name: B("Workout", "Тренировка в зале"), question: B("Did you work out?", "Сходили на тренировку?"), icon: "dumbbell", color: 6, frequency: Frequency(3, 7)),
        T(name: B("Run", "Бег"), question: B("How far did you run?", "Сколько пробежали?"), icon: "figure.run", color: 0, kind: .measurable, frequency: .weekly, unit: km, target: 15, health: .distance),
        T(name: B("Exercise 30 minutes", "30 минут активности"), question: B("Did you get 30 minutes of exercise?", "Было 30 минут активности?"), icon: "figure.outdoor.cycle", color: 5, kind: .measurable, unit: min, target: 30, health: .exerciseMinutes),
        T(name: B("Yoga", "Йога"), question: B("How long did you practise yoga?", "Сколько минут йоги?"), icon: "figure.yoga", color: 12, kind: .measurable, target: 20, timed: true, timerMinutes: 20),
        T(name: B("Stretch", "Растяжка"), question: B("How long did you stretch?", "Сколько минут растяжки?"), icon: "figure.flexibility", color: 14, kind: .measurable, target: 10, timed: true, timerMinutes: 10),
        T(name: B("Push-ups", "Отжимания"), question: B("How many push-ups did you do?", "Сколько раз отжались?"), icon: "figure.strengthtraining.traditional", color: 1, kind: .measurable, unit: times, target: 50),
        T(name: B("Squats", "Приседания"), question: B("How many squats did you do?", "Сколько раз присели?"), icon: "figure.cross.training", color: 2, kind: .measurable, unit: times, target: 50),
        T(name: B("Plank", "Планка"), question: B("How long did you hold the plank?", "Сколько стояли в планке?"), icon: "figure.core.training", color: 16, kind: .measurable, target: 3, timed: true),
        T(name: B("Cycling", "Велосипед"), question: B("How far did you ride?", "Сколько проехали?"), icon: "bicycle", color: 8, kind: .measurable, frequency: .weekly, unit: km, target: 50),
        T(name: B("Swim", "Плавание"), question: B("Did you swim today?", "Плавали сегодня?"), icon: "figure.pool.swim", color: 9, frequency: Frequency(2, 7)),
        T(name: B("Climb stairs", "Подниматься по лестнице"), question: B("How many floors did you climb?", "Сколько этажей прошли?"), icon: "figure.stairs", color: 3, kind: .measurable, unit: B("floors", "этажей"), target: 10, health: .flightsClimbed),
        T(name: B("Burn 400 kcal", "Сжечь 400 ккал"), question: B("Did you burn 400 active calories?", "Сожгли 400 активных калорий?"), icon: "flame", color: 0, kind: .measurable, unit: B("kcal", "ккал"), target: 400, health: .activeEnergy),
        T(name: B("Go for a walk", "Прогулка"), question: B("Did you go for a walk?", "Гуляли сегодня?"), icon: "figure.hiking", color: 6),
        T(name: B("Dance", "Танцы"), question: B("Did you dance today?", "Танцевали сегодня?"), icon: "figure.dance", color: 13, frequency: Frequency(2, 7)),
    ])

    static let nutrition = TemplateCategory(title: B("Nutrition", "Питание"), icon: "carrot", templates: [
        T(name: B("Eat vegetables", "Есть овощи"), question: B("How many servings of vegetables?", "Сколько порций овощей?"), icon: "carrot", color: 2, kind: .measurable, unit: B("servings", "порц."), target: 5),
        T(name: B("Eat fruit", "Есть фрукты"), question: B("Did you eat fruit today?", "Ели сегодня фрукты?"), icon: "apple.logo", color: 0),
        T(name: B("Cook at home", "Готовить дома"), question: B("Did you cook at home?", "Готовили дома?"), icon: "frying.pan", color: 3, frequency: Frequency(5, 7)),
        T(name: B("Healthy breakfast", "Полезный завтрак"), question: B("Did you have a healthy breakfast?", "Был полезный завтрак?"), icon: "cup.and.saucer", color: 4),
        T(name: B("Protein goal", "Норма белка"), question: B("How much protein did you eat?", "Сколько белка съели?"), icon: "fish", color: 15, kind: .measurable, unit: B("g", "г"), target: 100),
        T(name: B("No food after 8 pm", "Не есть после 20:00"), question: B("Did you skip eating after 8 pm?", "Обошлись без еды после 20:00?"), icon: "moon.stars", color: 11),
        T(name: B("Intermittent fasting", "Интервальное голодание"), question: B("Did you keep your fasting window?", "Соблюдали окно голодания?"), icon: "hourglass", color: 17),
        T(name: B("Log meals", "Записывать еду"), question: B("Did you log your meals?", "Записали приёмы пищи?"), icon: "list.bullet.clipboard", color: 5),
        T(name: B("Coffee limit", "Не больше 2 чашек кофе"), question: B("How many cups of coffee?", "Сколько чашек кофе?"), icon: "cup.and.heat.waves", color: 16, kind: .measurable, unit: B("cups", "чаш."), target: 2, targetType: .atMost),
        T(name: B("Green tea", "Зелёный чай"), question: B("Did you drink green tea?", "Пили зелёный чай?"), icon: "leaf", color: 6),
    ])

    static let sleep = TemplateCategory(title: B("Sleep", "Сон"), icon: "moon.zzz", templates: [
        T(name: B("Bed by 11 pm", "Лечь до 23:00"), question: B("Were you in bed by 11 pm?", "Легли до 23:00?"), icon: "bed.double", color: 11, reminder: 22 * 60 + 30),
        T(name: B("Wake up at 7", "Подъём в 7:00"), question: B("Did you get up at 7?", "Встали в 7:00?"), icon: "alarm", color: 2),
        T(name: B("Sleep 7.5 hours", "Спать 7,5 часов"), question: B("Did you sleep 7.5 hours?", "Спали 7,5 часов?"), icon: "moon.zzz", color: 12, kind: .measurable, unit: hours, target: 7.5, health: .sleepHours),
        T(name: B("No screens before bed", "Без экранов перед сном"), question: B("No screens in the last hour before bed?", "Последний час перед сном без экранов?"), icon: "iphone.slash", color: 18),
        T(name: B("Make the bed", "Заправить кровать"), question: B("Did you make your bed?", "Заправили кровать?"), icon: "bed.double", color: 7),
        T(name: B("Evening wind-down", "Вечерний ритуал"), question: B("Did you wind down before bed?", "Сделали вечерний ритуал?"), icon: "moon.stars", color: 13),
        T(name: B("Morning sunlight", "Утренний свет"), question: B("Did you get sunlight in the morning?", "Были утром на солнце?"), icon: "sun.horizon", color: 3),
    ])

    static let mind = TemplateCategory(title: B("Mindfulness", "Осознанность"), icon: "brain.head.profile", templates: [
        T(name: B("Meditate 10 minutes", "Медитация 10 минут"), question: B("How long did you meditate?", "Сколько минут медитировали?"), icon: "brain.head.profile", color: 12, kind: .measurable, target: 10, timed: true, timerMinutes: 10, health: .mindfulMinutes),
        T(name: B("Gratitude", "Благодарность"), question: B("Did you write three things you're grateful for?", "Записали три вещи, за которые благодарны?"), icon: "heart.text.square", color: 14, reminder: 21 * 60),
        T(name: B("Breathing exercise", "Дыхательная практика"), question: B("Did you do a breathing exercise?", "Сделали дыхательную практику?"), icon: "wind", color: 8, kind: .measurable, target: 5, timed: true, timerMinutes: 5),
        T(name: B("Mood check-in", "Отметить настроение"), question: B("How are you feeling today?", "Как вы себя чувствуете?"), icon: "face.smiling", color: 4),
        T(name: B("Digital detox hour", "Час без гаджетов"), question: B("Did you spend an hour offline?", "Провели час без гаджетов?"), icon: "iphone.slash", color: 18),
        T(name: B("Affirmations", "Аффирмации"), question: B("Did you say your affirmations?", "Проговорили аффирмации?"), icon: "sparkles", color: 13),
        T(name: B("Time in nature", "Время на природе"), question: B("Did you spend time in nature?", "Побыли на природе?"), icon: "tree", color: 6),
        T(name: B("Pray", "Молитва"), question: B("Did you pray today?", "Молились сегодня?"), icon: "hands.and.sparkles", color: 17),
        T(name: B("Visualize goals", "Визуализация целей"), question: B("Did you visualize your goals?", "Визуализировали цели?"), icon: "target", color: 10),
    ])

    static let learning = TemplateCategory(title: B("Learning", "Обучение"), icon: "graduationcap", templates: [
        T(name: B("Read 30 minutes", "Читать 30 минут"), question: B("How long did you read?", "Сколько минут читали?"), icon: "books.vertical", color: 3, kind: .measurable, target: 30, timed: true, timerMinutes: 30),
        T(name: B("Read 20 pages", "Читать 20 страниц"), question: B("How many pages did you read?", "Сколько страниц прочитали?"), icon: "book", color: 2, kind: .measurable, unit: pages, target: 20),
        T(name: B("Language practice", "Иностранный язык"), question: B("How long did you practise?", "Сколько минут занимались языком?"), icon: "translate", color: 10, kind: .measurable, target: 15, timed: true, timerMinutes: 15),
        T(name: B("Learn new words", "Учить новые слова"), question: B("How many new words did you learn?", "Сколько новых слов выучили?"), icon: "abc", color: 9, kind: .measurable, unit: words, target: 10),
        T(name: B("Flashcards", "Карточки"), question: B("Did you review your flashcards?", "Повторили карточки?"), icon: "rectangle.stack", color: 11),
        T(name: B("Practise an instrument", "Музыкальный инструмент"), question: B("How long did you practise?", "Сколько минут занимались?"), icon: "pianokeys", color: 12, kind: .measurable, target: 30, timed: true, timerMinutes: 30),
        T(name: B("Online course", "Онлайн-курс"), question: B("Did you study your course?", "Занимались по курсу?"), icon: "graduationcap", color: 8, frequency: Frequency(4, 7)),
        T(name: B("Code", "Программирование"), question: B("How long did you code?", "Сколько программировали?"), icon: "chevron.left.forwardslash.chevron.right", color: 6, kind: .measurable, target: 60, timed: true),
        T(name: B("Write 500 words", "Писать 500 слов"), question: B("How many words did you write?", "Сколько слов написали?"), icon: "pencil", color: 16, kind: .measurable, unit: words, target: 500),
        T(name: B("Audiobook or podcast", "Аудиокнига или подкаст"), question: B("Did you listen to something useful?", "Послушали что-то полезное?"), icon: "headphones", color: 13),
        T(name: B("Watch a lecture", "Смотреть лекцию"), question: B("Did you watch a lecture?", "Посмотрели лекцию?"), icon: "play.rectangle", color: 0, frequency: Frequency(3, 7)),
    ])

    static let productivity = TemplateCategory(title: B("Productivity", "Продуктивность"), icon: "checklist", templates: [
        T(name: B("Plan the day", "Спланировать день"), question: B("Did you plan your day?", "Спланировали день?"), icon: "checklist", color: 10, reminder: 8 * 60),
        T(name: B("Review the day", "Подвести итоги дня"), question: B("Did you review your day?", "Подвели итоги дня?"), icon: "text.badge.checkmark", color: 11, reminder: 21 * 60),
        T(name: B("Deep work", "Глубокая работа"), question: B("How long did you focus?", "Сколько времени в фокусе?"), icon: "target", color: 12, kind: .measurable, target: 90, timed: true, timerMinutes: 90),
        T(name: B("Pomodoros", "Помидоры"), question: B("How many pomodoros did you complete?", "Сколько помидоров сделали?"), icon: "timer", color: 0, kind: .measurable, unit: times, target: 4),
        T(name: B("Top 3 tasks", "Три главные задачи"), question: B("Did you finish your three main tasks?", "Сделали три главные задачи?"), icon: "3.circle", color: 2),
        T(name: B("Inbox zero", "Разобрать почту"), question: B("Did you clear your inbox?", "Разобрали почту?"), icon: "tray", color: 9),
        T(name: B("Weekly review", "Обзор недели"), question: B("Did you do your weekly review?", "Сделали обзор недели?"), icon: "calendar", color: 17, frequency: .weekly),
        T(name: B("No phone first hour", "Без телефона первый час"), question: B("No phone in the first hour after waking?", "Первый час после пробуждения без телефона?"), icon: "iphone.slash", color: 18),
        T(name: B("Tidy desk", "Порядок на столе"), question: B("Did you tidy your desk?", "Навели порядок на столе?"), icon: "lamp.desk", color: 7),
    ])

    static let finance = TemplateCategory(title: B("Finance", "Финансы"), icon: "banknote", templates: [
        T(name: B("Track expenses", "Записывать расходы"), question: B("Did you log today's expenses?", "Записали расходы?"), icon: "creditcard", color: 6, reminder: 21 * 60),
        T(name: B("Save money", "Откладывать деньги"), question: B("How much did you save?", "Сколько отложили?"), icon: "banknote", color: 5, kind: .measurable, frequency: Frequency(1, 30), unit: B("₽", "₽"), target: 10000),
        T(name: B("Budget review", "Проверить бюджет"), question: B("Did you review your budget?", "Проверили бюджет?"), icon: "chart.pie", color: 10, frequency: .weekly),
        T(name: B("Invest", "Инвестировать"), question: B("Did you invest this month?", "Инвестировали в этом месяце?"), icon: "chart.line.uptrend.xyaxis", color: 8, frequency: Frequency(1, 30)),
        T(name: B("No impulse buys", "Без импульсивных покупок"), question: B("No impulse purchases today?", "Сегодня без импульсивных покупок?"), icon: "cart", color: 0, kind: .quit),
        T(name: B("Bring lunch", "Брать обед с собой"), question: B("Did you bring lunch from home?", "Взяли обед из дома?"), icon: "takeoutbag.and.cup.and.straw", color: 3, frequency: Frequency(5, 7)),
    ])

    static let relationships = TemplateCategory(title: B("Relationships", "Отношения"), icon: "person.2", templates: [
        T(name: B("Call parents", "Звонить родителям"), question: B("Did you call your parents?", "Позвонили родителям?"), icon: "phone", color: 14, frequency: Frequency(2, 7)),
        T(name: B("Message a friend", "Написать другу"), question: B("Did you reach out to a friend?", "Написали другу?"), icon: "message", color: 9),
        T(name: B("Quality time", "Время с близкими"), question: B("Did you spend quality time with loved ones?", "Провели время с близкими?"), icon: "heart", color: 15),
        T(name: B("Play with kids", "Играть с детьми"), question: B("Did you play with the kids?", "Поиграли с детьми?"), icon: "figure.and.child.holdinghands", color: 4),
        T(name: B("Date night", "Свидание"), question: B("Did you have a date night?", "Было свидание?"), icon: "wineglass", color: 13, frequency: .weekly),
        T(name: B("Family dinner", "Семейный ужин"), question: B("Did you have dinner together?", "Ужинали вместе?"), icon: "fork.knife", color: 2),
        T(name: B("Compliment someone", "Сделать комплимент"), question: B("Did you compliment someone?", "Сделали кому-то комплимент?"), icon: "hand.thumbsup", color: 5),
        T(name: B("Walk the dog", "Гулять с собакой"), question: B("Did you walk the dog?", "Погуляли с собакой?"), icon: "dog", color: 16),
    ])

    static let home = TemplateCategory(title: B("Home", "Дом"), icon: "house", templates: [
        T(name: B("Tidy up 15 minutes", "Уборка 15 минут"), question: B("Did you tidy up?", "Навели порядок?"), icon: "bubbles.and.sparkles", color: 7, kind: .measurable, target: 15, timed: true, timerMinutes: 15),
        T(name: B("Do the dishes", "Помыть посуду"), question: B("Did you do the dishes?", "Помыли посуду?"), icon: "sink", color: 9),
        T(name: B("Laundry", "Стирка"), question: B("Did you do the laundry?", "Постирали?"), icon: "washer", color: 10, frequency: Frequency(2, 7)),
        T(name: B("Water plants", "Полить цветы"), question: B("Did you water the plants?", "Полили цветы?"), icon: "leaf.fill", color: 6, frequency: Frequency(1, 3)),
        T(name: B("Take out trash", "Вынести мусор"), question: B("Did you take out the trash?", "Вынесли мусор?"), icon: "trash", color: 18, frequency: Frequency(2, 7)),
        T(name: B("Deep clean", "Генеральная уборка"), question: B("Did you clean the place?", "Сделали уборку?"), icon: "house", color: 17, frequency: .weekly),
        T(name: B("Declutter one thing", "Избавиться от одной вещи"), question: B("Did you declutter something?", "Избавились от лишней вещи?"), icon: "shippingbox", color: 16),
    ])

    static let creativity = TemplateCategory(title: B("Creativity", "Творчество"), icon: "paintpalette", templates: [
        T(name: B("Draw", "Рисование"), question: B("Did you draw today?", "Рисовали сегодня?"), icon: "paintbrush", color: 13),
        T(name: B("Write fiction", "Писать прозу"), question: B("How many words did you write?", "Сколько слов написали?"), icon: "book.closed", color: 12, kind: .measurable, unit: words, target: 300),
        T(name: B("Take a photo", "Фото дня"), question: B("Did you take a photo you like?", "Сделали удачное фото?"), icon: "camera", color: 10),
        T(name: B("Make music", "Писать музыку"), question: B("Did you make music?", "Занимались музыкой?"), icon: "music.note", color: 11, frequency: Frequency(3, 7)),
        T(name: B("Craft or DIY", "Рукоделие"), question: B("Did you make something?", "Сделали что-то своими руками?"), icon: "scissors", color: 2, frequency: .weekly),
        T(name: B("Sing", "Петь"), question: B("Did you sing today?", "Пели сегодня?"), icon: "mic", color: 14),
    ])

    static let selfCare = TemplateCategory(title: B("Self-care", "Забота о себе"), icon: "heart.circle", templates: [
        T(name: B("Me time", "Время для себя"), question: B("Did you have time for yourself?", "Было время для себя?"), icon: "sofa", color: 15),
        T(name: B("Hot bath", "Тёплая ванна"), question: B("Did you take a relaxing bath?", "Приняли расслабляющую ванну?"), icon: "bathtub", color: 9, frequency: .weekly),
        T(name: B("Read for fun", "Читать для удовольствия"), question: B("Did you read something for fun?", "Почитали для удовольствия?"), icon: "book", color: 4),
        T(name: B("Learn to say no", "Говорить «нет»"), question: B("Did you protect your time today?", "Отстояли сегодня своё время?"), icon: "hand.raised", color: 0),
        T(name: B("Smile in the mirror", "Улыбнуться себе"), question: B("Did you smile at yourself?", "Улыбнулись себе в зеркале?"), icon: "face.smiling", color: 3),
    ])

    static let quit = TemplateCategory(title: B("Quit a Habit", "Бросить привычку"), icon: "nosign", templates: [
        T(name: B("No smoking", "Не курить"), question: B("Stayed smoke-free today?", "Сегодня без сигарет?"), icon: "nosign", color: 18, kind: .quit),
        T(name: B("No vaping", "Без вейпа"), question: B("Stayed vape-free today?", "Сегодня без вейпа?"), icon: "smoke", color: 19, kind: .quit),
        T(name: B("No alcohol", "Без алкоголя"), question: B("Stayed alcohol-free today?", "Сегодня без алкоголя?"), icon: "wineglass", color: 13, kind: .quit),
        T(name: B("No sugar", "Без сахара"), question: B("Stayed away from sweets today?", "Обошлись сегодня без сладкого?"), icon: "birthday.cake", color: 15, kind: .quit),
        T(name: B("No fast food", "Без фастфуда"), question: B("No fast food today?", "Сегодня без фастфуда?"), icon: "takeoutbag.and.cup.and.straw", color: 2, kind: .quit),
        T(name: B("No junk snacks", "Без вредных перекусов"), question: B("No junk snacks today?", "Сегодня без вредных перекусов?"), icon: "fork.knife", color: 1, kind: .quit),
        T(name: B("No late-night snacking", "Не есть на ночь"), question: B("No late-night snacking?", "Не ели на ночь?"), icon: "moon", color: 11, kind: .quit),
        T(name: B("No social media", "Без соцсетей"), question: B("Stayed off social media today?", "Сегодня без соцсетей?"), icon: "iphone.slash", color: 10, kind: .quit),
        T(name: B("No doomscrolling", "Без думскроллинга"), question: B("No endless scrolling today?", "Сегодня без бесконечной ленты?"), icon: "hand.raised.slash", color: 8, kind: .quit),
        T(name: B("Less screen time", "Меньше экранного времени"), question: B("How many hours on your phone?", "Сколько часов в телефоне?"), icon: "iphone", color: 18, kind: .measurable, unit: hours, target: 2, targetType: .atMost),
        T(name: B("No video games", "Без видеоигр"), question: B("No gaming today?", "Сегодня без игр?"), icon: "gamecontroller", color: 12, kind: .quit),
        T(name: B("No TV binge", "Без сериалов взахлёб"), question: B("No binge-watching today?", "Сегодня без сериалов взахлёб?"), icon: "tv", color: 16, kind: .quit),
        T(name: B("No nail biting", "Не грызть ногти"), question: B("No nail biting today?", "Сегодня не грызли ногти?"), icon: "hand.raised", color: 14, kind: .quit),
        T(name: B("No swearing", "Не ругаться"), question: B("No swearing today?", "Сегодня без ругательств?"), icon: "bubble.left.and.exclamationmark.bubble.right", color: 0, kind: .quit),
        T(name: B("No caffeine", "Без кофеина"), question: B("No caffeine today?", "Сегодня без кофеина?"), icon: "cup.and.heat.waves", color: 17, kind: .quit),
        T(name: B("No impulse shopping", "Без спонтанных покупок"), question: B("No impulse shopping today?", "Сегодня без спонтанных покупок?"), icon: "cart", color: 3, kind: .quit),
        T(name: B("No procrastination", "Без прокрастинации"), question: B("Did you avoid procrastinating?", "Удалось не прокрастинировать?"), icon: "hourglass", color: 4, kind: .quit),
        T(name: B("No complaining", "Не жаловаться"), question: B("No complaining today?", "Сегодня без жалоб?"), icon: "speaker.slash", color: 7, kind: .quit),
    ])

    static let challenges = TemplateCategory(title: B("Challenges", "Челленджи"), icon: "flag.checkered", templates: [
        T(name: B("21 days of meditation", "21 день медитации"), question: B("Did you meditate today?", "Медитировали сегодня?"), icon: "brain.head.profile", color: 12, challengeDays: 21),
        T(name: B("30 days without sugar", "30 дней без сахара"), question: B("Stayed away from sweets today?", "Обошлись сегодня без сладкого?"), icon: "birthday.cake", color: 15, kind: .quit, challengeDays: 30),
        T(name: B("30 days without alcohol", "30 дней без алкоголя"), question: B("Stayed alcohol-free today?", "Сегодня без алкоголя?"), icon: "wineglass", color: 13, kind: .quit, challengeDays: 30),
        T(name: B("30 days of push-ups", "30 дней отжиманий"), question: B("How many push-ups today?", "Сколько раз отжались?"), icon: "figure.strengthtraining.traditional", color: 1, kind: .measurable, unit: times, target: 30, challengeDays: 30),
        T(name: B("30 days of journaling", "30 дней дневника"), question: B("Did you write in your journal?", "Писали в дневник?"), icon: "pencil.and.scribble", color: 17, challengeDays: 30),
        T(name: B("30 days of cold showers", "30 дней холодного душа"), question: B("Did you take a cold shower?", "Приняли холодный душ?"), icon: "snowflake", color: 9, challengeDays: 30),
        T(name: B("30 days of 10,000 steps", "30 дней по 10 000 шагов"), question: B("Did you walk 10,000 steps?", "Прошли 10 000 шагов?"), icon: "figure.walk", color: 7, kind: .measurable, unit: B("steps", "шагов"), target: 10000, challengeDays: 30, health: .steps),
        T(name: B("66 days to build a habit", "66 дней на новую привычку"), question: B("Did you keep your new habit today?", "Соблюдали новую привычку?"), icon: "sparkles", color: 4, challengeDays: 66),
        T(name: B("7-day digital detox", "7 дней цифрового детокса"), question: B("Did you stay off social media?", "Обошлись без соцсетей?"), icon: "iphone.slash", color: 18, kind: .quit, challengeDays: 7),
        T(name: B("100 days of code", "100 дней кода"), question: B("Did you code today?", "Программировали сегодня?"), icon: "chevron.left.forwardslash.chevron.right", color: 6, challengeDays: 100),
        T(name: B("100 days of drawing", "100 дней рисования"), question: B("Did you draw today?", "Рисовали сегодня?"), icon: "paintbrush", color: 13, challengeDays: 100),
        T(name: B("365 days of reading", "365 дней чтения"), question: B("Did you read today?", "Читали сегодня?"), icon: "books.vertical", color: 3, challengeDays: 365),
        T(name: B("40 days of gratitude", "40 дней благодарности"), question: B("What are you grateful for today?", "За что вы благодарны сегодня?"), icon: "heart.text.square", color: 14, challengeDays: 40),
        T(name: B("14 days without fast food", "14 дней без фастфуда"), question: B("No fast food today?", "Сегодня без фастфуда?"), icon: "takeoutbag.and.cup.and.straw", color: 2, kind: .quit, challengeDays: 14),
    ])

    static let categories: [TemplateCategory] = [
        popular, health, fitness, nutrition, sleep, mind, learning, productivity,
        finance, relationships, home, creativity, selfCare, quit, challenges,
    ]

    static var count: Int { categories.reduce(0) { $0 + $1.templates.count } }
}
// swiftlint:enable line_length
