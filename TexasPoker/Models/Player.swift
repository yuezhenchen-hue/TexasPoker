import Foundation

enum PlayerAction: Equatable {
    case fold
    case check
    case call(Int)
    case raise(Int)
    case allIn(Int)

    var displayName: String {
        switch self {
        case .fold: return "弃牌"
        case .check: return "过牌"
        case .call(let amount): return "跟注 \(amount)"
        case .raise(let amount): return "加注 \(amount)"
        case .allIn(let amount): return "全下 \(amount)"
        }
    }
}

enum AIStyle: CaseIterable {
    case tight, loose, aggressive
}

struct AvatarInfo {
    let emoji: String
    let bgColors: (Color, Color)

    static let human = AvatarInfo(emoji: "😎", bgColors: (.blue, .cyan))
    static let presets: [AvatarInfo] = [
        AvatarInfo(emoji: "👩‍💼", bgColors: (.purple, .pink)),
        AvatarInfo(emoji: "🧔", bgColors: (.orange, .red)),
        AvatarInfo(emoji: "🤠", bgColors: (.green, .teal)),
        AvatarInfo(emoji: "👸", bgColors: (.pink, .purple)),
        AvatarInfo(emoji: "🦊", bgColors: (.orange, .yellow)),
        AvatarInfo(emoji: "🐺", bgColors: (.gray, .blue)),
        AvatarInfo(emoji: "🎩", bgColors: (.indigo, .purple)),
    ]
}

import SwiftUI

class Player: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let isHuman: Bool
    let aiStyle: AIStyle?
    let avatar: AvatarInfo

    @Published var chips: Int
    @Published var holeCards: [Card] = []
    @Published var currentBet: Int = 0
    @Published var totalBetThisRound: Int = 0
    @Published var isFolded: Bool = false
    @Published var isAllIn: Bool = false
    @Published var isDealer: Bool = false
    @Published var isSmallBlind: Bool = false
    @Published var isBigBlind: Bool = false
    @Published var lastAction: PlayerAction?

    init(name: String, chips: Int = 1000, isHuman: Bool = false, aiStyle: AIStyle? = nil, avatar: AvatarInfo = .human) {
        self.name = name
        self.chips = chips
        self.isHuman = isHuman
        self.aiStyle = aiStyle
        self.avatar = avatar
    }

    var isActive: Bool {
        !isFolded && !isAllIn && chips > 0
    }

    func resetForNewHand() {
        holeCards = []
        currentBet = 0
        totalBetThisRound = 0
        isFolded = false
        isAllIn = false
        isDealer = false
        isSmallBlind = false
        isBigBlind = false
        lastAction = nil
    }

    @discardableResult
    func bet(_ amount: Int) -> Int {
        let actual = min(amount, chips)
        chips -= actual
        currentBet += actual
        totalBetThisRound += actual
        if chips == 0 { isAllIn = true }
        return actual
    }

    func resetCurrentBet() {
        currentBet = 0
    }

    // MARK: - AI Decision

    func decideAction(communityCards: [Card], pot: Int, currentBet: Int, minRaise: Int) -> PlayerAction {
        let toCall = currentBet - self.currentBet
        let strength = evaluateStrength(communityCards: communityCards)
        let style = aiStyle ?? .loose

        if toCall > chips {
            return strength > 0.5 ? .allIn(chips) : .fold
        }

        switch style {
        case .tight:
            return tightStrategy(strength: strength, toCall: toCall, minRaise: minRaise, pot: pot)
        case .aggressive:
            return aggressiveStrategy(strength: strength, toCall: toCall, minRaise: minRaise, pot: pot)
        case .loose:
            return looseStrategy(strength: strength, toCall: toCall, minRaise: minRaise, pot: pot)
        }
    }

    private func evaluateStrength(communityCards: [Card]) -> Double {
        guard !communityCards.isEmpty else { return preflopStrength() }

        let result = HandEvaluator.evaluate(holeCards: holeCards, communityCards: communityCards)
        let base = Double(result.rank.rawValue) / Double(HandRank.royalFlush.rawValue)
        let kicker = result.tiebreakers.first.map { Double($0) / 14.0 * 0.1 } ?? 0
        return min(1.0, max(0.0, base + kicker + Double.random(in: -0.1...0.1)))
    }

    private func preflopStrength() -> Double {
        guard holeCards.count >= 2 else { return 0.3 }
        let c1 = holeCards[0], c2 = holeCards[1]
        var strength = 0.2

        if c1.rank == c2.rank {
            strength += 0.3 + Double(c1.rank) / 14.0 * 0.3
        }
        strength += Double(max(c1.rank, c2.rank)) / 14.0 * 0.15

        if c1.suit == c2.suit { strength += 0.06 }
        if abs(c1.rank - c2.rank) <= 2 { strength += 0.05 }

        strength += Double.random(in: -0.08...0.08)
        return max(0.0, min(1.0, strength))
    }

    private func tightStrategy(strength: Double, toCall: Int, minRaise: Int, pot: Int) -> PlayerAction {
        if strength > 0.7 {
            let raiseAmt = min(minRaise * 2, chips)
            return .raise(raiseAmt)
        }
        if strength > 0.4 {
            if toCall == 0 { return .check }
            if toCall <= pot * 3 / 10 { return .call(toCall) }
            return .fold
        }
        return toCall == 0 ? .check : .fold
    }

    private func aggressiveStrategy(strength: Double, toCall: Int, minRaise: Int, pot: Int) -> PlayerAction {
        if strength > 0.5 {
            return .raise(min(minRaise * 3, chips))
        }
        if strength > 0.25 {
            if Double.random(in: 0...1) < 0.4 {
                return .raise(min(minRaise * 2, chips))
            }
            return toCall == 0 ? .check : .call(toCall)
        }
        if toCall == 0 {
            return Double.random(in: 0...1) < 0.2 ? .raise(min(minRaise, chips)) : .check
        }
        return toCall <= pot / 5 ? .call(toCall) : .fold
    }

    private func looseStrategy(strength: Double, toCall: Int, minRaise: Int, pot: Int) -> PlayerAction {
        if strength > 0.6 {
            return .raise(min(minRaise * 2, chips))
        }
        if strength > 0.3 {
            if toCall == 0 {
                return Double.random(in: 0...1) < 0.3 ? .raise(min(minRaise, chips)) : .check
            }
            return .call(toCall)
        }
        if toCall == 0 { return .check }
        if toCall <= pot * 2 / 5 && Double.random(in: 0...1) < 0.4 {
            return .call(toCall)
        }
        return .fold
    }
}
