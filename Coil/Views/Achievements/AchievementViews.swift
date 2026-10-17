import SwiftUI

extension Achievement {
    var title: String {
        switch kind {
        case .streak(let n): String(localized: "\(n)-day streak")
        case .cleanStreak(let n): String(localized: "\(n) days clean")
        case .completions(1): String(localized: "First step")
        case .completions(let n): String(localized: "\(n) times")
        case .strength(let p): String(localized: "\(p)% strength")
        case .perfectMonth: String(localized: "Perfect month")
        case .comeback: String(localized: "Comeback")
        case .challenge(let n): String(localized: "\(n)-day challenge")
        case .habitsCreated(1): String(localized: "First habit")
        case .habitsCreated(let n): String(localized: "\(n) habits")
        case .allDoneInADay: String(localized: "Clean sweep")
        }
    }

    var detail: String {
        switch kind {
        case .streak(let n): String(localized: "Keep the habit \(n) days in a row.")
        case .cleanStreak(let n): String(localized: "Stay clean for \(n) days in a row.")
        case .completions(1): String(localized: "Check off the habit for the first time.")
        case .completions(let n): String(localized: "Complete the habit \(n) times.")
        case .strength(let p): String(localized: "Reach \(p)% habit strength.")
        case .perfectMonth: String(localized: "Keep the habit every day of a calendar month.")
        case .comeback: String(localized: "Come back after a break of a week or more and keep going for 7 days.")
        case .challenge(let n): String(localized: "Complete a \(n)-day challenge without missing a day.")
        case .habitsCreated(1): String(localized: "Create your first habit.")
        case .habitsCreated(let n): String(localized: "Track \(n) habits.")
        case .allDoneInADay: String(localized: "Complete every habit in one day.")
        }
    }

    var systemImage: String {
        switch kind {
        case .streak: "flame.fill"
        case .cleanStreak: "leaf.fill"
        case .completions(1): "shoeprints.fill"
        case .completions: "checkmark.seal.fill"
        case .strength: "bolt.heart.fill"
        case .perfectMonth: "calendar.badge.checkmark"
        case .comeback: "arrow.uturn.up.circle.fill"
        case .challenge: "flag.checkered"
        case .habitsCreated: "square.stack.3d.up.fill"
        case .allDoneInADay: "sparkles"
        }
    }

    /// Soft bronze, silver and gold.
    var tierColor: Color {
        switch tier {
        case 2: Color(hex: 0xE6C46A)
        case 1: Color(hex: 0xB9C0CC)
        default: Color(hex: 0xD9A57A)
        }
    }
}

/// A round medal; locked medals are gray with a progress ring.
struct AchievementBadge: View {
    let achievement: Achievement
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            if achievement.isUnlocked {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [achievement.tierColor.opacity(0.75), achievement.tierColor],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: achievement.tierColor.opacity(0.45), radius: 6, y: 2)
                Image(systemName: achievement.systemImage)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Circle().fill(Color(.tertiarySystemFill))
                Circle()
                    .trim(from: 0, to: max(0.001, achievement.progress))
                    .stroke(achievement.tierColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(1.5)
                Image(systemName: achievement.systemImage)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(Text(achievement.title))
        .accessibilityValue(Text(achievement.isUnlocked ? String(localized: "Unlocked") : Formatting.percent(achievement.progress)))
    }
}

/// Earned medals and the next goals on the habit screen.
struct AchievementsCard: View {
    let habit: Habit
    let stats: HabitStats

    var body: some View {
        let all = AchievementEngine.achievements(for: stats, challenge: habit.challenge)
        let unlocked = all.filter(\.isUnlocked).sorted { ($0.unlocked ?? stats.today) > ($1.unlocked ?? stats.today) }
        let next = all.filter { !$0.isUnlocked }.sorted { $0.progress > $1.progress }.prefix(3)
        Card("Achievements") {
            NavigationLink {
                AchievementListView(title: habit.name, achievements: all)
            } label: {
                Text("\(unlocked.count) of \(all.count)")
                    .font(.subheadline.weight(.medium))
            }
        } content: {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(unlocked.prefix(8)) + Array(next)) { achievement in
                        VStack(spacing: 6) {
                            AchievementBadge(achievement: achievement)
                            Text(achievement.title)
                                .font(.caption2.weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
                                .frame(width: 72)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

/// Every achievement with its date or progress.
struct AchievementListView: View {
    let title: String
    let achievements: [Achievement]

    var body: some View {
        List {
            let unlocked = achievements.filter(\.isUnlocked)
            let locked = achievements.filter { !$0.isUnlocked }
            if !unlocked.isEmpty {
                Section("Unlocked") {
                    ForEach(unlocked) { row($0) }
                }
            }
            if !locked.isEmpty {
                Section("Next Goals") {
                    ForEach(locked.sorted { $0.progress > $1.progress }) { row($0) }
                }
            }
        }
        .navigationTitle(title)
    }

    private func row(_ achievement: Achievement) -> some View {
        HStack(spacing: 14) {
            AchievementBadge(achievement: achievement, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.body.weight(.medium))
                Text(achievement.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let day = achievement.unlocked {
                    Text(Formatting.fullDate(day))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(achievement.tierColor)
                } else {
                    ProgressView(value: achievement.progress)
                        .tint(achievement.tierColor)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Announces a newly earned achievement.
@MainActor
enum Celebration {
    /// Compares a habit's achievements before and after a change and celebrates any new one.
    static func check(_ habit: Habit, before: Set<Achievement.Kind>) {
        let after = AchievementEngine.achievements(for: habit.stats(), challenge: habit.challenge)
        guard let earned = after.first(where: { $0.isUnlocked && !before.contains($0.kind) }) else { return }
        UndoCenter.shared.celebrate("\(earned.title) · \(habit.name)", systemImage: earned.systemImage)
    }

    static func unlockedKinds(_ habit: Habit) -> Set<Achievement.Kind> {
        Set(AchievementEngine.achievements(for: habit.stats(), challenge: habit.challenge).filter(\.isUnlocked).map(\.kind))
    }
}
