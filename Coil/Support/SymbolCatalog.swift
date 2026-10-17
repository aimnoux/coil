import SwiftUI

/// Habit icons to choose from, grouped by theme. All are SF Symbols available on iOS 18.
enum SymbolCatalog {
    struct Category: Identifiable {
        let title: LocalizedStringKey
        let symbols: [String]
        var id: String { symbols.first ?? "" }
    }

    static let categories: [Category] = [
        Category(title: "Health", symbols: [
            "heart", "heart.text.square", "cross.case", "pills", "bandage", "stethoscope",
            "lungs", "brain.head.profile", "eye", "ear", "allergens", "facemask",
            "thermometer.medium", "drop", "waterbottle", "mouth",
        ]),
        Category(title: "Fitness", symbols: [
            "figure.walk", "figure.run", "figure.hiking", "figure.outdoor.cycle", "bicycle",
            "figure.pool.swim", "figure.strengthtraining.traditional", "dumbbell", "figure.yoga",
            "figure.pilates", "figure.flexibility", "figure.core.training", "figure.dance",
            "figure.boxing", "figure.jumprope", "figure.stairs", "figure.climbing", "figure.skiing.downhill",
            "figure.tennis", "figure.soccer", "figure.basketball", "sportscourt", "stopwatch",
        ]),
        Category(title: "Food", symbols: [
            "fork.knife", "carrot", "leaf", "apple.logo", "cup.and.saucer", "mug", "wineglass",
            "birthday.cake", "frying.pan", "takeoutbag.and.cup.and.straw", "fish", "refrigerator",
        ]),
        Category(title: "Sleep & Rest", symbols: [
            "bed.double", "moon.zzz", "moon.stars", "sun.max", "sunrise", "sunset", "alarm",
            "powersleep", "zzz", "sofa",
        ]),
        Category(title: "Mind", symbols: [
            "brain", "sparkles", "wind", "leaf.circle", "figure.mind.and.body", "hands.and.sparkles",
            "face.smiling", "heart.circle", "hand.thumbsup", "lightbulb", "hourglass", "timer",
        ]),
        Category(title: "Learning", symbols: [
            "book", "books.vertical", "book.closed", "graduationcap", "pencil", "pencil.and.scribble",
            "highlighter", "character.book.closed", "globe", "translate", "abc", "function",
            "puzzlepiece", "atom", "magnifyingglass",
        ]),
        Category(title: "Work", symbols: [
            "laptopcomputer", "desktopcomputer", "keyboard", "chevron.left.forwardslash.chevron.right",
            "briefcase", "folder", "doc.text", "list.bullet.clipboard", "checklist", "calendar",
            "envelope", "tray", "chart.line.uptrend.xyaxis", "target", "flag", "clock",
        ]),
        Category(title: "Money", symbols: [
            "banknote", "creditcard", "dollarsign.circle", "rublesign.circle", "eurosign.circle",
            "chart.pie", "cart", "bag", "gift", "building.columns",
        ]),
        Category(title: "Home", symbols: [
            "house", "washer", "trash", "basket", "bubbles.and.sparkles", "sparkles.rectangle.stack",
            "lamp.desk", "key", "wrench.and.screwdriver", "hammer", "paintbrush", "tshirt",
        ]),
        Category(title: "People", symbols: [
            "person", "person.2", "person.3", "figure.and.child.holdinghands", "phone",
            "message", "bubble.left.and.bubble.right", "hand.wave", "heart.text.square.fill",
            "pawprint", "dog", "cat",
        ]),
        Category(title: "Creativity", symbols: [
            "paintpalette", "camera", "photo", "music.note", "guitars", "pianokeys", "mic",
            "film", "theatermasks", "scribble.variable", "pencil.tip", "scissors",
        ]),
        Category(title: "Nature", symbols: [
            "tree", "leaf.fill", "camera.macro", "mountain.2", "drop.fill", "snowflake",
            "sun.horizon", "cloud.sun", "flame", "bolt", "globe.europe.africa", "water.waves",
        ]),
        Category(title: "Quitting", symbols: [
            "nosign", "smoke", "xmark.octagon", "hand.raised", "iphone.slash", "gamecontroller",
            "tv", "wineglass.fill", "cup.and.heat.waves", "takeoutbag.and.cup.and.straw.fill",
            "bell.slash", "hand.raised.slash",
        ]),
        Category(title: "Other", symbols: [
            "star", "bookmark", "tag", "pin", "paperplane", "car", "airplane", "tram",
            "map", "location", "shield", "crown", "trophy", "medal", "rosette", "circle.hexagongrid",
        ]),
    ]
}
