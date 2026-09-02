import Foundation

let EMOJI_GROUPS: [(name: String, glyphs: [String])] = [
    (name: String(localized: "Dagritme"), glyphs: [
        "🛏️", "⏰", "🌅", "🪥", "🚿", "🛁", "🧼", "🧴", "🪮", "💇", "🚽", "🧻", "👕", "👖", "🧦", "👟",
        "🧥", "🧢", "🎒", "🚪", "🚗", "🚲", "🛴", "🌙", "😴", "📖", "🤗", "🧸", "🎧", "🪟"
    ]),
    (name: String(localized: "Eten"), glyphs: [
        "🍽️", "🥣", "🍞", "🥐", "🧀", "🥚", "🍎", "🍌", "🍓", "🥕", "🥪", "🍕", "🍝", "🥗", "🧃", "🥛",
        "🍪", "🍫", "🍇", "🥦", "🍚", "🍲", "🥞", "🧁"
    ]),
    (name: String(localized: "Spelen"), glyphs: [
        "🧸", "⚽", "🏀", "🎾", "🏊", "🚴", "🤸", "🎨", "🖍️", "🧩", "🎲", "🎮", "🎹", "🎸", "🪁", "🛝",
        "🏐", "🥋", "⛸️", "🏓", "🎯", "🪀", "🤾", "🩰"
    ]),
    (name: String(localized: "Huis"), glyphs: [
        "🧹", "🧺", "🪣", "🧽", "🛋️", "🪴", "🗑️", "🍳", "🧊", "📦", "🔑", "💡", "🧷", "🪥", "🔌", "🧴"
    ]),
    (name: String(localized: "Dieren"), glyphs: [
        "🦄", "🦖", "🐶", "🐱", "🦊", "🐼", "🐸", "🐙", "🦋", "🐝", "🦉", "🐢", "🐳", "🦁", "🐰", "🐥",
        "🦔", "🐧", "🐨", "🐷", "🐮", "🐒", "🐴", "🐬"
    ]),
    (name: String(localized: "Mensen"), glyphs: [
        "😀", "😊", "🥳", "🤗", "😎", "🤓", "🥰",
        "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧔", "🧔‍♀️", "👱", "👱‍♀️", "👱‍♂️",
        "👨‍🦰", "👩‍🦰", "🧑‍🦰", "👨‍🦱", "👩‍🦱", "🧑‍🦱", "👨‍🦳", "👩‍🦳", "🧑‍🦳", "👨‍🦲", "👩‍🦲", "🧑‍🦲",
        "🧓", "👴", "👵", "🧕", "👳", "👳‍♀️", "👲", "🤰", "🫃", "👼",
        "🙋", "🙋‍♂️", "💁", "💁‍♂️", "🤷", "🤷‍♂️", "🙆", "🙅", "🧏", "🧏‍♂️",
        "👮", "👮‍♀️", "👷", "👷‍♀️", "💂", "🕵️", "🕵️‍♀️",
        "🧑‍⚕️", "👩‍⚕️", "👨‍⚕️", "🧑‍🏫", "👩‍🏫", "👨‍🏫", "🧑‍🍳", "👩‍🍳", "👨‍🍳", "🧑‍🌾", "👩‍🌾", "👨‍🌾",
        "🧑‍🔧", "👩‍🔧", "👨‍🔧", "🧑‍💻", "👩‍💻", "👨‍💻", "🧑‍🚒", "👩‍🚒", "👨‍🚒", "🧑‍✈️", "👩‍✈️", "👨‍✈️",
        "🧑‍🚀", "👩‍🚀", "👨‍🚀", "🧑‍🎨", "🧑‍🔬", "🧑‍🎤", "🧑‍⚖️", "🧑‍💼", "🧑‍🏭",
        "🦸", "🦸‍♀️", "🦸‍♂️", "🦹", "🧙", "🧙‍♀️", "🧚", "🧚‍♂️", "🧜", "🧜‍♂️", "🧛", "🧝", "🧞", "🎅", "🤶", "🧑‍🎄",
        "🧑‍🦽", "🧑‍🦼", "🧑‍🦯", "🏋️", "🧘", "🚴", "🏊", "🤸", "🧗", "🏄",
        "🤖", "👻", "👽", "🧑‍🤝‍🧑", "👨‍👩‍👧‍👦"
    ]),
    (name: String(localized: "Dingen"), glyphs: [
        "⭐", "❤️", "📅", "🏫", "🏠", "🎁", "🎈", "🎉", "📷", "🎵", "☀️", "🌈", "❄️", "🌸", "🔔", "⏳",
        "📌", "✅", "🏆", "💧", "🔥", "🌟", "🚌", "✏️", "💻", "📱", "🖥️", "📺"
    ]),
]

/// Huidskleur, zoals je die in de kiezer kiest: één keuze voor de hele rij.
enum SkinTone: Int, CaseIterable {
    case none, light, mediumLight, medium, mediumDark, dark

    private static let modifiers: [Unicode.Scalar] = [
        "\u{1F3FB}", "\u{1F3FC}", "\u{1F3FD}", "\u{1F3FE}", "\u{1F3FF}",
    ]

    var scalar: Unicode.Scalar? { self == .none ? nil : Self.modifiers[rawValue - 1] }

    /// Een hand om de keuze mee te laten zien.
    var sample: String { apply(to: "✋") }

    static func isModifier(_ scalar: Unicode.Scalar) -> Bool { modifiers.contains(scalar) }

    /// De kleur zoals die nu in een icoon zit, of `.none`.
    static func of(_ glyph: String) -> SkinTone {
        for scalar in glyph.unicodeScalars {
            if let i = modifiers.firstIndex(of: scalar) { return SkinTone(rawValue: i + 1) ?? .none }
        }
        return .none
    }

    static var remembered: SkinTone {
        get { SkinTone(rawValue: UserDefaults.standard.integer(forKey: "skinTone")) ?? .none }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "skinTone") }
    }

    /// Zet deze kleur in een icoon: achter het eerste mensfiguur erin, in
    /// plaats van wat er al stond. Iconen met meer dan één figuur (hand in
    /// hand, een gezin) blijven zoals ze zijn; die hebben geen kleur.
    func apply(to glyph: String) -> String {
        let bare = Self.bare(glyph)
        guard Self.supportsTone(bare), let modifier = scalar else { return bare }
        var out = String.UnicodeScalarView()
        var placed = false
        var scalars = Array(bare.unicodeScalars)
        var i = 0
        while i < scalars.count {
            let s = scalars[i]
            out.append(s)
            if !placed, s.properties.isEmojiModifierBase {
                out.append(modifier)
                placed = true
                // Een variatiekiezer achter het figuur hoort weg zodra er een kleur staat.
                if i + 1 < scalars.count, scalars[i + 1] == "\u{FE0F}" { i += 1 }
            }
            i += 1
        }
        scalars = []
        return String(out)
    }

    /// Precies één figuur dat een kleur kan hebben.
    static func supportsTone(_ glyph: String) -> Bool {
        glyph.unicodeScalars.filter { $0.properties.isEmojiModifierBase }.count == 1
    }

    /// Zonder kleur, zoals het in de lijst staat.
    static func bare(_ glyph: String) -> String {
        var out = String.UnicodeScalarView()
        for s in glyph.unicodeScalars where !isModifier(s) { out.append(s) }
        var text = String(out)
        // 🕵️ staat in de lijst mét variatiekiezer; die komt terug als de kleur weggaat.
        if let scalar = text.unicodeScalars.first, text.unicodeScalars.count == 1,
           scalar.properties.isEmojiModifierBase, !scalar.properties.isEmojiPresentation {
            text += "\u{FE0F}"
        }
        return text
    }
}

/// Trefwoorden per icoon, zodat de app er zelf een kiest bij wat je typt.
/// Een woord telt als het begin van een woord in de naam overeenkomt; het
/// langste trefwoord wint, zodat "pizza eten" 🍕 geeft en niet 🍽️.
let EMOJI_KEYWORDS: [(glyph: String, words: [String])] = [
    ("🪥", ["tand", "tanden", "poets", "tandenpoetsen", "teeth", "brush"]),
    ("🦷", ["tandarts", "dentist"]),
    ("⏰", ["wakker", "opstaan", "wekker", "wake", "alarm"]),
    ("🛏️", ["bed", "naar bed", "bedtijd", "bedtime"]),
    ("😴", ["slapen", "slaap", "dutje", "sleep", "nap"]),
    ("🚿", ["douche", "douchen", "shower"]),
    ("🛁", ["bad", "baden", "bath"]),
    ("🧼", ["handen", "wassen", "zeep", "wash", "hands", "soap"]),
    ("🧴", ["smeren", "creme", "zonnebrand", "lotion", "sunscreen"]),
    ("🪮", ["haar", "kammen", "borstelen", "hair", "comb"]),
    ("💇", ["kapper", "haircut"]),
    ("🚽", ["plassen", "wc", "toilet", "poepen", "potje", "pee", "poop"]),
    ("👕", ["aankleden", "kleren", "omkleden", "shirt", "trui", "pyjama", "dress", "clothes"]),
    ("👖", ["broek", "pants"]),
    ("🧦", ["sokken", "sok", "socks"]),
    ("👟", ["schoenen", "schoen", "shoes"]),
    ("🧥", ["jas", "coat", "jacket"]),
    ("🧢", ["pet", "muts", "hat", "cap"]),
    ("🎒", ["tas", "rugzak", "spullen", "inpakken", "bag", "pack"]),
    ("🚪", ["weggaan", "vertrekken", "deur", "leave"]),
    ("🚗", ["auto", "rijden", "car", "drive"]),
    ("🚲", ["fiets", "fietsen", "bike", "cycle"]),
    ("🛴", ["step", "scooter"]),
    ("🚌", ["bus"]),
    ("🚶", ["lopen", "wandelen", "walk"]),
    ("🏃", ["rennen", "hardlopen", "run"]),
    ("📖", ["lezen", "boek", "voorlezen", "read", "book", "story"]),
    ("✏️", ["huiswerk", "schrijven", "oefenen", "homework", "write", "practice"]),
    ("🏫", ["school", "klas", "les", "class"]),
    ("🧑‍🏫", ["bso", "opvang", "daycare"]),
    ("🤗", ["knuffel", "knuffelen", "hug", "cuddle"]),
    ("🧸", ["speelgoed", "beer", "toys"]),
    ("🎧", ["luisteren", "koptelefoon", "listen", "podcast"]),
    ("🎵", ["muziek", "zingen", "liedje", "music", "sing", "song"]),
    ("🎹", ["piano", "muziekles"]),
    ("🎸", ["gitaar", "guitar"]),
    ("🥁", ["drum"]),
    ("💡", ["licht", "lamp", "light"]),
    ("🪟", ["gordijn", "gordijnen", "raam", "curtain", "window"]),
    ("🔌", ["opladen", "oplader", "charge"]),
    ("📱", ["telefoon", "ipad", "tablet", "phone", "schermtijd", "screen"]),
    ("💻", ["laptop", "computer"]),
    ("🖥️", ["desktop", "pc"]),
    ("📺", ["tv", "televisie", "kijken", "film", "watch", "movie"]),
    ("🎮", ["gamen", "game", "nintendo", "switch", "playstation"]),
    ("🍽️", ["eten", "avondeten", "diner", "dinner", "eat", "maaltijd"]),
    ("🥣", ["ontbijt", "ontbijten", "pap", "yoghurt", "cornflakes", "breakfast", "cereal"]),
    ("🥪", ["lunch", "lunchen", "boterham", "boterhammen", "sandwich"]),
    ("🍞", ["brood", "toast", "bread"]),
    ("🥐", ["croissant"]),
    ("🧀", ["kaas", "cheese"]),
    ("🥚", ["ei", "eieren", "egg"]),
    ("🍎", ["appel", "fruit", "apple"]),
    ("🍌", ["banaan", "banana"]),
    ("🍓", ["aardbei", "strawberry"]),
    ("🍇", ["druiven", "grapes"]),
    ("🥕", ["wortel", "carrot"]),
    ("🥦", ["groente", "broccoli", "vegetables"]),
    ("🍕", ["pizza"]),
    ("🍝", ["pasta", "spaghetti", "macaroni"]),
    ("🍟", ["friet", "patat", "fries"]),
    ("🥗", ["salade", "salad"]),
    ("🍲", ["soep", "stamppot", "soup"]),
    ("🍚", ["rijst", "rice"]),
    ("🥞", ["pannenkoek", "pannenkoeken", "pancake"]),
    ("🧃", ["drinken", "sap", "pakje", "limonade", "drink", "juice"]),
    ("💧", ["water"]),
    ("🥛", ["melk", "milk"]),
    ("🍼", ["fles", "flesje", "bottle"]),
    ("🍪", ["koek", "koekje", "tussendoortje", "snack", "cookie"]),
    ("🍬", ["snoep", "snoepje", "candy"]),
    ("🍫", ["chocola", "chocolade", "chocolate"]),
    ("🧁", ["bakken", "taart", "cupcake", "bake", "cake"]),
    ("🎂", ["verjaardag", "jarig", "birthday"]),
    ("🎉", ["feest", "feestje", "partijtje", "party"]),
    ("🎁", ["cadeau", "cadeautje", "present", "gift"]),
    ("⚽", ["voetbal", "voetballen", "soccer", "football"]),
    ("🏀", ["basketbal", "basketball"]),
    ("🎾", ["tennis", "tennissen"]),
    ("🏐", ["volleybal", "volleyball"]),
    ("🤾", ["handbal", "handball"]),
    ("🏑", ["hockey"]),
    ("🏊", ["zwemmen", "zwemles", "zwembad", "swim", "swimming"]),
    ("🤸", ["gym", "gymnastiek", "turnen", "gymnastics"]),
    ("🥋", ["judo", "karate", "taekwondo"]),
    ("⛸️", ["schaatsen", "skate"]),
    ("🩰", ["ballet", "dansen", "dansles", "dance"]),
    ("🏓", ["tafeltennis", "pingpong"]),
    ("🏋️", ["sport", "sporten", "training", "fitness"]),
    ("🧘", ["yoga", "rust", "rusten", "relax"]),
    ("🎨", ["tekenen", "knutselen", "verven", "draw", "craft", "paint"]),
    ("🖍️", ["kleuren", "kleurplaat", "color"]),
    ("🧩", ["puzzel", "puzzelen", "puzzle"]),
    ("🎲", ["spel", "spelletje", "bordspel", "boardgame"]),
    ("🛝", ["speeltuin", "buiten", "buitenspelen", "playground", "outside"]),
    ("🪁", ["vlieger", "kite"]),
    ("🧑‍🤝‍🧑", ["vriendje", "vriendinnetje", "afspraak", "spelen bij", "playdate", "friend"]),
    ("👨‍👩‍👧‍👦", ["familie", "family"]),
    ("👵", ["oma", "opa", "grandma", "grandpa"]),
    ("🐶", ["hond", "uitlaten", "dog"]),
    ("🐱", ["kat", "poes", "cat"]),
    ("🐰", ["konijn", "rabbit"]),
    ("🐹", ["hamster", "cavia"]),
    ("🐟", ["vissen", "vis", "fish"]),
    ("🐴", ["paard", "paardrijden", "pony", "horse"]),
    ("🧹", ["opruimen", "vegen", "stofzuigen", "tidy", "clean", "vacuum"]),
    ("🧺", ["was", "wasmand", "laundry"]),
    ("🍳", ["koken", "cook"]),
    ("🛒", ["boodschappen", "winkel", "supermarkt", "groceries", "shop"]),
    ("🗑️", ["afval", "vuilnis", "prullenbak", "trash"]),
    ("🪴", ["planten", "plant"]),
    ("🩺", ["dokter", "huisarts", "doctor"]),
    ("💊", ["medicijn", "medicijnen", "pil", "medicine"]),
    ("💉", ["prik", "vaccin", "shot"]),
    ("👓", ["bril", "glasses"]),
    ("🏠", ["thuis", "home"]),
    ("✈️", ["vakantie", "vliegtuig", "vliegen", "holiday", "flight"]),
    ("🏕️", ["kamperen", "camping"]),
    ("🏖️", ["strand", "beach"]),
    ("🎬", ["bioscoop", "cinema"]),
    ("🎭", ["theater", "toneel"]),
    ("🎪", ["circus", "pretpark"]),
    ("🦁", ["dierentuin", "zoo"]),
    ("📷", ["foto", "photo"]),
    ("🎄", ["kerst", "christmas"]),
    ("🎅", ["sinterklaas", "sint", "santa"]),
    ("🎃", ["halloween"]),
    ("🐣", ["pasen", "easter"]),
    ("📅", ["agenda"]),
]

private let EMOJI_INDEX: [(word: String, glyph: String)] = EMOJI_KEYWORDS
    .flatMap { entry in entry.words.map { (word: $0, glyph: entry.glyph) } }
    .sorted { $0.word.count > $1.word.count }

/// Het icoon dat bij een naam past, of niets als er geen trefwoord in zit.
func suggestEmoji(for text: String) -> String? {
    let plain = text
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        .lowercased()
    let words = plain.split { !$0.isLetter }.map(String.init)
    guard !words.isEmpty else { return nil }
    for entry in EMOJI_INDEX {
        if entry.word.contains(" ") {
            if plain.contains(entry.word) { return entry.glyph }
        } else if entry.word.count < 4 {
            if words.contains(entry.word) { return entry.glyph }
        } else if words.contains(where: { $0.hasPrefix(entry.word) }) {
            return entry.glyph
        }
    }
    return nil
}
