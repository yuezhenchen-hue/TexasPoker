import Foundation

enum GamePhase: String {
    case waiting = "等待开始"
    case dealing = "发牌中"
    case preFlop = "翻牌前"
    case flop = "翻牌"
    case turn = "转牌"
    case river = "河牌"
    case showdown = "摊牌"
    case handOver = "本局结束"
}

struct HandResultInfo: Identifiable {
    let id = UUID()
    let player: Player
    let winnings: Int
    let handDescription: String
}

class GameEngine: ObservableObject {
    static let smallBlind = 10
    static let bigBlind = 20

    let human: Player
    var aiPlayers: [Player]
    @Published var players: [Player] = []
    @Published var communityCards: [Card] = []
    @Published var pot: Int = 0
    @Published var phase: GamePhase = .waiting
    @Published var currentPlayerIndex: Int = 0
    @Published var currentBet: Int = 0
    @Published var minRaise: Int = 20
    @Published var message: String = "点击「开始游戏」"
    @Published var handResults: [HandResultInfo] = []
    @Published var waitingForHuman: Bool = false
    @Published var handNumber: Int = 0

    // Set when a new community phase starts, ViewModel reads and resets
    @Published var phaseJustChanged: Bool = false

    private var deck = Deck()
    private var dealerIndex: Int = 0
    private var lastRaiserIndex: Int = -1

    @Published var pendingHoleCards: [[Card]] = []
    private var showdownPot: Int = 0

    private let allAITemplates: [(String, AIStyle)] = [
        ("Alice", .tight),
        ("Bob", .aggressive),
        ("Charlie", .loose),
        ("Diana", .tight),
        ("Eve", .aggressive),
        ("Frank", .loose),
        ("Grace", .tight),
    ]

    init(aiCount: Int = 4, startingChips: Int = 1000) {
        human = Player(name: "你", chips: startingChips, isHuman: true, avatar: .human)
        let count = min(aiCount, allAITemplates.count)
        aiPlayers = allAITemplates.prefix(count).enumerated().map { i, t in
            let avatar = AvatarInfo.presets[i % AvatarInfo.presets.count]
            return Player(name: t.0, chips: startingChips, aiStyle: t.1, avatar: avatar)
        }
        players = [human] + aiPlayers
    }

    func reconfigure(aiCount: Int, startingChips: Int) {
        let count = min(aiCount, allAITemplates.count)
        human.chips = startingChips
        aiPlayers = allAITemplates.prefix(count).enumerated().map { i, t in
            let avatar = AvatarInfo.presets[i % AvatarInfo.presets.count]
            return Player(name: t.0, chips: startingChips, aiStyle: t.1, avatar: avatar)
        }
        players = [human] + aiPlayers
        phase = .waiting
        handNumber = 0
        communityCards = []
        pot = 0
        handResults = []
        message = "点击「开始游戏」"
        dealerIndex = 0
    }

    var activePlayers: [Player] { players.filter { !$0.isFolded } }
    var playersInAction: [Player] { players.filter { $0.isActive } }

    var currentPlayer: Player? {
        guard currentPlayerIndex >= 0, currentPlayerIndex < players.count else { return nil }
        return players[currentPlayerIndex]
    }

    /// Position name for a player relative to dealer
    func positionName(for player: Player) -> String? {
        guard let idx = players.firstIndex(where: { $0.id == player.id }) else { return nil }
        let n = players.count

        if player.isDealer { return "BTN" }
        if player.isSmallBlind { return "SB" }
        if player.isBigBlind { return "BB" }

        if n <= 3 { return nil }

        // Standard position names
        let bbIdx = (dealerIndex + 2) % n
        let posFromBB = (idx - bbIdx + n) % n
        if posFromBB == 1 { return "UTG" }

        let btnDist = (dealerIndex - idx + n) % n
        if btnDist == 1 { return "CO" }
        if n >= 6 && btnDist == 2 { return "HJ" }
        return "MP"
    }

    // MARK: - New Hand

    func startNewHand() {
        removeBrokePlayers()
        guard players.count >= 2, human.chips > 0 else {
            message = human.chips <= 0 ? "你已经没有筹码了！游戏结束！" : "游戏结束！"
            phase = .handOver
            return
        }

        handNumber += 1
        deck.reset()
        communityCards = []
        pot = 0
        currentBet = 0
        minRaise = Self.bigBlind
        handResults = []
        pendingHoleCards = []
        phaseJustChanged = false

        for p in players { p.resetForNewHand() }
        dealerIndex = dealerIndex % players.count
        assignPositions()
        postBlinds()

        phase = .dealing
        prepareDealingCards()
        message = "荷官发牌中..."
    }

    func finishDealing() {
        for (i, p) in players.enumerated() {
            if i < pendingHoleCards.count {
                p.holeCards = pendingHoleCards[i]
            }
        }
        pendingHoleCards = []
        phase = .preFlop
        setFirstPlayerPreflop()
        message = "第 \(handNumber) 局 — 翻牌前"
        checkHumanTurn()
    }

    /// Called by ViewModel after showdown display time
    func finishShowdown() {
        phase = .handOver
        dealerIndex = (dealerIndex + 1) % players.count
    }

    private func prepareDealingCards() {
        pendingHoleCards = players.map { _ in deck.deal(2) }
    }

    private func removeBrokePlayers() {
        let broke = aiPlayers.filter { $0.chips <= 0 }
        for p in broke {
            players.removeAll { $0.id == p.id }
            aiPlayers.removeAll { $0.id == p.id }
        }
        if dealerIndex >= players.count { dealerIndex = 0 }
    }

    private func assignPositions() {
        let n = players.count
        players[dealerIndex].isDealer = true
        players[(dealerIndex + 1) % n].isSmallBlind = true
        players[(dealerIndex + 2) % n].isBigBlind = true
    }

    private func postBlinds() {
        let n = players.count
        let sb = players[(dealerIndex + 1) % n]
        let bb = players[(dealerIndex + 2) % n]
        let sbActual = sb.bet(Self.smallBlind)
        let bbActual = bb.bet(Self.bigBlind)
        pot += sbActual + bbActual
        currentBet = Self.bigBlind
    }

    // MARK: - Turn Management

    private func setFirstPlayerPreflop() {
        let n = players.count
        currentPlayerIndex = (dealerIndex + 3) % n
        lastRaiserIndex = (dealerIndex + 2) % n
        skipInactive()
    }

    private func setFirstPlayerPostflop() {
        let n = players.count
        currentPlayerIndex = (dealerIndex + 1) % n
        lastRaiserIndex = -1
        skipInactive()
    }

    private func skipInactive() {
        let n = players.count
        var attempts = 0
        while attempts < n {
            if players[currentPlayerIndex].isActive { return }
            currentPlayerIndex = (currentPlayerIndex + 1) % n
            attempts += 1
        }
    }

    private func checkHumanTurn() {
        if let p = currentPlayer, p.isHuman, p.isActive {
            waitingForHuman = true
        } else {
            waitingForHuman = false
        }
    }

    // MARK: - Actions

    func processAITurn() -> Bool {
        guard let player = currentPlayer,
              !player.isHuman,
              player.isActive else { return false }

        let action = player.decideAction(
            communityCards: communityCards,
            pot: pot,
            currentBet: currentBet,
            minRaise: minRaise
        )
        executeAction(player: player, action: action)
        return true
    }

    func processHumanAction(_ action: PlayerAction) {
        waitingForHuman = false
        executeAction(player: human, action: action)
    }

    private func executeAction(player: Player, action: PlayerAction) {
        player.lastAction = action

        switch action {
        case .fold:
            player.isFolded = true
            message = "\(player.name) 弃牌"

        case .check:
            message = "\(player.name) 过牌"

        case .call(let amount):
            let toCall = currentBet - player.currentBet
            let actual = player.bet(min(toCall, amount))
            pot += actual
            message = "\(player.name) 跟注 \(actual)"

        case .raise(let amount):
            let toCall = currentBet - player.currentBet
            let actual = player.bet(toCall + amount)
            pot += actual
            currentBet = player.currentBet
            minRaise = max(minRaise, amount)
            lastRaiserIndex = currentPlayerIndex
            message = "\(player.name) 加注到 \(player.currentBet)"

        case .allIn(let amount):
            let actual = player.bet(amount)
            pot += actual
            if player.currentBet > currentBet {
                currentBet = player.currentBet
                lastRaiserIndex = currentPlayerIndex
            }
            message = "\(player.name) 全下 \(actual)"
        }

        advanceToNextPlayer()
    }

    private func advanceToNextPlayer() {
        let inHand = activePlayers
        if inHand.count <= 1 {
            endHandEarly()
            return
        }

        let activeNonAllIn = playersInAction
        if activeNonAllIn.count <= 1 &&
            players.allSatisfy({ $0.currentBet == currentBet || $0.isAllIn || $0.isFolded }) {
            fastForwardToShowdown()
            return
        }

        let n = players.count
        var nextIdx = (currentPlayerIndex + 1) % n
        var attempts = 0

        while attempts < n {
            if nextIdx == lastRaiserIndex {
                advancePhase()
                return
            }
            if players[nextIdx].isActive {
                currentPlayerIndex = nextIdx
                checkHumanTurn()
                return
            }
            nextIdx = (nextIdx + 1) % n
            attempts += 1
        }

        advancePhase()
    }

    // MARK: - Phase Transitions

    private func advancePhase() {
        for p in players { p.resetCurrentBet() }
        currentBet = 0
        minRaise = Self.bigBlind

        switch phase {
        case .preFlop:
            phase = .flop
            _ = deck.dealOne()
            communityCards.append(contentsOf: deck.deal(3))
            message = "— 翻牌 —"
            phaseJustChanged = true
        case .flop:
            phase = .turn
            _ = deck.dealOne()
            communityCards.append(contentsOf: deck.deal(1))
            message = "— 转牌 —"
            phaseJustChanged = true
        case .turn:
            phase = .river
            _ = deck.dealOne()
            communityCards.append(contentsOf: deck.deal(1))
            message = "— 河牌 —"
            phaseJustChanged = true
        case .river:
            showdown()
            return
        default:
            break
        }

        setFirstPlayerPostflop()
        checkHumanTurn()

        if playersInAction.count <= 1 &&
            players.allSatisfy({ $0.currentBet == currentBet || $0.isAllIn || $0.isFolded }) {
            fastForwardToShowdown()
        }
    }

    private func fastForwardToShowdown() {
        while phase != .showdown && phase != .handOver {
            for p in players { p.resetCurrentBet() }
            currentBet = 0

            switch phase {
            case .preFlop:
                phase = .flop
                _ = deck.dealOne()
                communityCards.append(contentsOf: deck.deal(3))
            case .flop:
                phase = .turn
                _ = deck.dealOne()
                communityCards.append(contentsOf: deck.deal(1))
            case .turn:
                phase = .river
                _ = deck.dealOne()
                communityCards.append(contentsOf: deck.deal(1))
            case .river:
                showdown()
                return
            default:
                break
            }
        }
        if phase != .showdown && phase != .handOver {
            showdown()
        }
    }

    private func endHandEarly() {
        guard let winner = activePlayers.first else { return }
        winner.chips += pot
        handResults = [HandResultInfo(player: winner, winnings: pot, handDescription: "其他人弃牌")]
        message = "\(winner.name) 赢得 \(pot) 筹码"
        pot = 0
        phase = .handOver
        dealerIndex = (dealerIndex + 1) % players.count
        waitingForHuman = false
    }

    private func showdown() {
        showdownPot = pot
        phase = .showdown
        let contenders = activePlayers

        var evaluations: [(Player, HandResult)] = contenders.map { p in
            let result = HandEvaluator.evaluate(holeCards: p.holeCards, communityCards: communityCards)
            return (p, result)
        }
        evaluations.sort { $0.1 > $1.1 }

        guard let best = evaluations.first else { return }
        let winners = evaluations.filter { $0.1 == best.1 }
        let share = pot / winners.count

        handResults = winners.map {
            HandResultInfo(player: $0.0, winnings: share, handDescription: $0.1.description)
        }
        for (player, _) in winners {
            player.chips += share
        }

        if winners.count == 1 {
            message = "🏆 \(best.0.name) 赢得 \(pot) — \(best.1.description)"
        } else {
            let names = winners.map(\.0.name).joined(separator: "、")
            message = "🏆 \(names) 平分 \(pot)"
        }

        pot = 0
        waitingForHuman = false
        // STAY in .showdown — ViewModel will call finishShowdown() after display time
    }

    // MARK: - Human Options

    func getHumanOptions() -> [PlayerAction] {
        var options: [PlayerAction] = []
        let toCall = currentBet - human.currentBet

        options.append(.fold)

        if toCall == 0 {
            options.append(.check)
        } else if toCall <= human.chips {
            options.append(.call(toCall))
        }

        if human.chips > toCall {
            let raiseAmount = minRaise
            if toCall + raiseAmount <= human.chips {
                options.append(.raise(raiseAmount))
            }
        }

        options.append(.allIn(human.chips))
        return options
    }
}
