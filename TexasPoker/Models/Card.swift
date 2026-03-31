import Foundation

enum Suit: Int, CaseIterable, Comparable, Codable {
    case clubs = 0
    case diamonds = 1
    case hearts = 2
    case spades = 3

    var symbol: String {
        switch self {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        }
    }

    var isRed: Bool {
        self == .hearts || self == .diamonds
    }

    static func < (lhs: Suit, rhs: Suit) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct Card: Identifiable, Equatable, Comparable, Hashable {
    let id = UUID()
    let rank: Int   // 2-14, where 14 = Ace
    let suit: Suit

    var rankString: String {
        switch rank {
        case 2...10: return "\(rank)"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        case 14: return "A"
        default: return "?"
        }
    }

    var displayName: String {
        "\(rankString)\(suit.symbol)"
    }

    static func < (lhs: Card, rhs: Card) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        return lhs.suit < rhs.suit
    }

    static func == (lhs: Card, rhs: Card) -> Bool {
        lhs.rank == rhs.rank && lhs.suit == rhs.suit
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(rank)
        hasher.combine(suit)
    }
}

class Deck {
    private var cards: [Card] = []

    init() {
        reset()
    }

    func reset() {
        cards = []
        for suit in Suit.allCases {
            for rank in 2...14 {
                cards.append(Card(rank: rank, suit: suit))
            }
        }
        shuffle()
    }

    func shuffle() {
        cards.shuffle()
    }

    func deal(_ count: Int = 1) -> [Card] {
        let dealt = Array(cards.prefix(count))
        cards.removeFirst(min(count, cards.count))
        return dealt
    }

    func dealOne() -> Card? {
        cards.isEmpty ? nil : cards.removeFirst()
    }

    var remaining: Int { cards.count }
}
