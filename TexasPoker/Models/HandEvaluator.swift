import Foundation

enum HandRank: Int, Comparable, CaseIterable {
    case highCard = 0
    case onePair = 1
    case twoPair = 2
    case threeOfAKind = 3
    case straight = 4
    case flush = 5
    case fullHouse = 6
    case fourOfAKind = 7
    case straightFlush = 8
    case royalFlush = 9

    static func < (lhs: HandRank, rhs: HandRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .highCard: return "高牌"
        case .onePair: return "一对"
        case .twoPair: return "两对"
        case .threeOfAKind: return "三条"
        case .straight: return "顺子"
        case .flush: return "同花"
        case .fullHouse: return "葫芦"
        case .fourOfAKind: return "四条"
        case .straightFlush: return "同花顺"
        case .royalFlush: return "皇家同花顺"
        }
    }
}

struct HandResult: Comparable {
    let rank: HandRank
    let tiebreakers: [Int]
    let description: String

    static func < (lhs: HandResult, rhs: HandResult) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        for (a, b) in zip(lhs.tiebreakers, rhs.tiebreakers) {
            if a != b { return a < b }
        }
        return false
    }

    static func == (lhs: HandResult, rhs: HandResult) -> Bool {
        lhs.rank == rhs.rank && lhs.tiebreakers == rhs.tiebreakers
    }
}

struct HandEvaluator {
    static func evaluate(holeCards: [Card], communityCards: [Card]) -> HandResult {
        let allCards = holeCards + communityCards
        guard allCards.count >= 5 else {
            let ranks = allCards.map(\.rank).sorted(by: >)
            return HandResult(rank: .highCard, tiebreakers: ranks, description: "高牌")
        }

        var bestResult: HandResult?
        let combos = combinations(allCards, choose: 5)

        for combo in combos {
            let result = evaluateFive(Array(combo))
            if let best = bestResult {
                if result > best { bestResult = result }
            } else {
                bestResult = result
            }
        }

        return bestResult ?? HandResult(rank: .highCard, tiebreakers: [], description: "高牌")
    }

    private static func evaluateFive(_ cards: [Card]) -> HandResult {
        let ranks = cards.map(\.rank).sorted(by: >)
        let suits = cards.map(\.suit)
        let isFlush = Set(suits).count == 1
        let (isStraight, highCard) = checkStraight(ranks)

        let rankCounts = Dictionary(grouping: ranks, by: { $0 }).mapValues(\.count)
        let sorted = rankCounts.sorted { a, b in
            if a.value != b.value { return a.value > b.value }
            return a.key > b.key
        }
        let countValues = sorted.map(\.value)

        if isStraight && isFlush {
            if highCard == 14 {
                return HandResult(rank: .royalFlush, tiebreakers: [highCard], description: "皇家同花顺")
            }
            return HandResult(rank: .straightFlush, tiebreakers: [highCard], description: "同花顺")
        }

        if countValues.first == 4 {
            let quadRank = sorted[0].key
            let kicker = sorted[1].key
            return HandResult(rank: .fourOfAKind, tiebreakers: [quadRank, kicker], description: "四条")
        }

        if countValues.count >= 2 && countValues[0] == 3 && countValues[1] == 2 {
            let tripRank = sorted[0].key
            let pairRank = sorted[1].key
            return HandResult(rank: .fullHouse, tiebreakers: [tripRank, pairRank], description: "葫芦")
        }

        if isFlush {
            return HandResult(rank: .flush, tiebreakers: ranks, description: "同花")
        }

        if isStraight {
            return HandResult(rank: .straight, tiebreakers: [highCard], description: "顺子")
        }

        if countValues.first == 3 {
            let tripRank = sorted[0].key
            let kickers = sorted.filter { $0.value == 1 }.map(\.key).sorted(by: >)
            return HandResult(rank: .threeOfAKind, tiebreakers: [tripRank] + kickers, description: "三条")
        }

        if countValues.count >= 2 && countValues[0] == 2 && countValues[1] == 2 {
            let pairs = sorted.filter { $0.value == 2 }.map(\.key).sorted(by: >)
            let kicker = sorted.filter { $0.value == 1 }.map(\.key).first ?? 0
            return HandResult(rank: .twoPair, tiebreakers: pairs + [kicker], description: "两对")
        }

        if countValues.first == 2 {
            let pairRank = sorted[0].key
            let kickers = sorted.filter { $0.value == 1 }.map(\.key).sorted(by: >)
            return HandResult(rank: .onePair, tiebreakers: [pairRank] + kickers, description: "一对")
        }

        return HandResult(rank: .highCard, tiebreakers: ranks, description: "高牌")
    }

    private static func checkStraight(_ ranks: [Int]) -> (Bool, Int) {
        let unique = Array(Set(ranks)).sorted(by: >)
        guard unique.count >= 5 else { return (false, 0) }

        if unique == Array(stride(from: unique[0], through: unique[0] - 4, by: -1)) {
            return (true, unique[0])
        }

        // A-2-3-4-5 wheel
        if Set(unique) == Set([14, 2, 3, 4, 5]) {
            return (true, 5)
        }

        return (false, 0)
    }

    private static func combinations(_ array: [Card], choose k: Int) -> [[Card]] {
        guard k <= array.count else { return [] }
        if k == 0 { return [[]] }
        if k == array.count { return [array] }

        var result: [[Card]] = []
        var combo: [Card] = []

        func backtrack(_ start: Int) {
            if combo.count == k {
                result.append(combo)
                return
            }
            for i in start..<array.count {
                combo.append(array[i])
                backtrack(i + 1)
                combo.removeLast()
            }
        }

        backtrack(0)
        return result
    }
}
