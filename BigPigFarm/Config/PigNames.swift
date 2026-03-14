/// PigNames -- Name generation arrays for guinea pigs.
/// Maps from: data/names.py

/// Provides random name generation for guinea pigs.
///
/// Contains themed name lists (cute, food, color, personality, famous)
/// plus gendered title prefixes and honorary suffixes.
/// Use `generateName` for a single random name, or `generateUniqueName`
/// to avoid collisions with an existing set.
enum PigNames {

    // MARK: - Prefix Gender

    /// Gender hint for title prefix selection.
    /// Separate from Models/Gender to keep the Config layer independent.
    /// Callers holding a `Gender` value should bridge via an extension in the
    /// Models or Engine layer (not here) to maintain the dependency direction.
    enum PrefixGender: Sendable {
        case male
        case female
    }

    // MARK: - Prefixes

    static let malePrefixes: [String] = [
        "Sir", "Mr.", "Duke", "Lord", "Baron", "Count", "King", "Prince",
    ]

    static let femalePrefixes: [String] = [
        "Lady", "Ms.", "Princess", "Queen", "Duchess", "Baroness", "Countess",
    ]

    static let neutralPrefixes: [String] = [
        "Professor", "Captain", "Dr.", "Chief",
    ]

    // MARK: - Name Lists

    static let cuteNames: [String] = [
        "Squeaky", "Patches", "Peanut", "Cinnamon", "Nutmeg", "Cookie", "Biscuit",
        "Caramel", "Mocha", "Cocoa", "Oreo", "Brownie", "Muffin", "Cupcake",
        "Butterscotch", "Toffee", "Marshmallow", "Ginger", "Pepper", "Clover",
        "Daisy", "Poppy", "Rosie", "Willow", "Maple", "Hazel", "Olive", "Basil",
        "Sage", "Thyme", "Parsley", "Mint", "Peaches", "Apricot", "Plum", "Cherry",
        "Mango", "Kiwi", "Coconut", "Almond", "Walnut", "Cashew", "Pistachio",
        "Pretzel", "Crumble", "Fudge", "Truffle", "Pudding", "Custard", "Waffle",
        "Pancake", "Noodle", "Dumpling", "Tofu", "Mochi", "Boba", "Sushi",
    ]

    static let foodNames: [String] = [
        "Carrot", "Lettuce", "Celery", "Cucumber", "Tomato", "Spinach", "Kale",
        "Broccoli", "Cabbage", "Radish", "Turnip", "Beet", "Pumpkin", "Squash",
        "Zucchini", "Eggplant", "Potato", "Bean", "Pea", "Corn",
    ]

    static let colorNames: [String] = [
        "Ginger", "Rusty", "Sandy", "Sunny", "Goldie", "Copper", "Bronze",
        "Ebony", "Onyx", "Shadow", "Midnight", "Coal", "Smoky", "Dusty",
        "Snowy", "Ivory", "Pearl", "Cotton", "Cloud", "Frost", "Cream",
        "Cocoa", "Chocolate", "Mocha", "Espresso", "Coffee", "Brownie",
        "Caramel", "Honey", "Amber", "Tawny", "Fawn",
    ]

    static let personalityNames: [String] = [
        "Whiskers", "Nibbles", "Squeaks", "Wiggles", "Tumbles", "Scamper",
        "Zippy", "Bouncy", "Fluffy", "Fuzzy", "Snuggles", "Cuddles", "Bubbles",
        "Giggles", "Twinkle", "Sparkle", "Pebbles", "Buttons", "Pickles",
        "Sprout", "Nugget", "Pip", "Dot", "Speck", "Freckles", "Speckles",
    ]

    static let famousNames: [String] = [
        "Hamtaro", "Pikachu", "Remy", "Stuart", "Gus", "Jerry", "Mickey",
        "Minnie", "Chip", "Dale", "Gadget", "Fievel", "Bernard", "Bianca",
        "Templeton", "Rizzo", "Splinter", "Ratigan",
    ]

    // MARK: - Suffixes

    static let suffixes: [String] = [
        "Jr.", "III", "the Great", "the Fluffy", "the Brave", "the Wise",
        "the Mighty", "the Gentle", "the Swift", "the Noble",
    ]

    // MARK: - Combined

    // Some names appear in multiple sub-lists (e.g. "Ginger", "Caramel").
    // This matches the Python source and slightly skews their pick probability.
    static let allNames: [String] =
        cuteNames + foodNames + colorNames + personalityNames + famousNames

    // MARK: - Generation

    /// Generate a random guinea pig name.
    ///
    /// - Parameters:
    ///   - includeTitle: Whether to potentially include a title prefix (15% chance).
    ///   - includeSuffix: Whether to potentially include a suffix (10% chance).
    ///   - gender: Prefix gender for gender-appropriate titles. Pass `nil` for any prefix.
    /// - Returns: A randomly generated name string.
    static func generateName(
        includeTitle: Bool = false,
        includeSuffix: Bool = false,
        gender: PrefixGender? = nil
    ) -> String {
        guard var name = allNames.randomElement() else {
            preconditionFailure("PigNames.allNames must not be empty")
        }

        if includeTitle && Double.random(in: 0.0..<1.0) < 0.15 {
            let prefixes: [String]
            switch gender {
            case .male:
                prefixes = malePrefixes + neutralPrefixes
            case .female:
                prefixes = femalePrefixes + neutralPrefixes
            case nil:
                prefixes = malePrefixes + femalePrefixes + neutralPrefixes
            }
            guard let prefix = prefixes.randomElement() else {
                preconditionFailure("Prefix arrays must not be empty")
            }
            name = "\(prefix) \(name)"
        }

        if includeSuffix && Double.random(in: 0.0..<1.0) < 0.1 {
            guard let suffix = suffixes.randomElement() else {
                preconditionFailure("PigNames.suffixes must not be empty")
            }
            name = "\(name) \(suffix)"
        }

        return name
    }

    /// Generate a unique name not present in the given set.
    ///
    /// Tries up to `maxAttempts` random names with titles and suffixes enabled
    /// to maximise the available name pool. If all attempts collide, falls back
    /// to a numbered name (e.g. "Cookie 1").
    ///
    /// - Parameters:
    ///   - existingNames: Set of names already in use.
    ///   - gender: Prefix gender for gender-appropriate titles.
    ///   - maxAttempts: Maximum random attempts before falling back to numbered names.
    /// - Returns: A name guaranteed not to be in `existingNames`.
    static func generateUniqueName(
        existingNames: Set<String>,
        gender: PrefixGender? = nil,
        maxAttempts: Int = 100
    ) -> String {
        for _ in 0..<maxAttempts {
            let name = generateName(includeTitle: true, includeSuffix: true, gender: gender)
            if !existingNames.contains(name) {
                return name
            }
        }

        // Fallback: add a number suffix
        guard let baseName = allNames.randomElement() else {
            preconditionFailure("PigNames.allNames must not be empty")
        }
        var counter = 1
        while existingNames.contains("\(baseName) \(counter)") {
            counter += 1
        }
        return "\(baseName) \(counter)"
    }
}
