import SwiftUI
import Combine

@MainActor
class GameViewModel: ObservableObject {
    @Published var engine: GameEngine
    @Published var showResults = false
    @Published var raiseAmount: Double = 40

    // Dealing animation state
    @Published var dealingCardIndex: Int = -1
    @Published var isDealing: Bool = false
    @Published var dealtPlayerIndices: Set<Int> = []

    let soundManager = SoundManager.shared
    private var aiTimer: Timer?
    private var dealTimer: Timer?

    init(aiCount: Int = 4, startingChips: Int = 1000) {
        engine = GameEngine(aiCount: aiCount, startingChips: startingChips)
    }

    var isGameActive: Bool {
        engine.phase != .waiting && engine.phase != .handOver
    }

    func reconfigure(aiCount: Int, startingChips: Int) {
        engine.reconfigure(aiCount: aiCount, startingChips: startingChips)
        showResults = false
        isDealing = false
        dealtPlayerIndices = []
    }

    func startGame() {
        showResults = false
        soundManager.startBackgroundMusic()
        engine.startNewHand()
        startDealingAnimation()
    }

    func nextHand() {
        showResults = false
        engine.startNewHand()
        startDealingAnimation()
    }

    func performAction(_ action: PlayerAction) {
        switch action {
        case .fold: soundManager.playFold()
        case .check: soundManager.playCheck()
        case .call: soundManager.playChipBet()
        case .raise: soundManager.playChipBet()
        case .allIn: soundManager.playAllIn()
        }
        engine.processHumanAction(action)
        startAILoop()
    }

    func performRaise() {
        soundManager.playChipBet()
        let amount = Int(raiseAmount)
        engine.processHumanAction(.raise(amount))
        startAILoop()
    }

    var humanOptions: [PlayerAction] {
        engine.getHumanOptions()
    }

    var toCall: Int {
        engine.currentBet - engine.human.currentBet
    }

    var canRaise: Bool {
        humanOptions.contains(where: {
            if case .raise = $0 { return true }
            return false
        })
    }

    var maxRaise: Int {
        max(engine.minRaise, engine.human.chips - toCall)
    }

    // MARK: - Dealing Animation

    private func startDealingAnimation() {
        isDealing = true
        dealtPlayerIndices = []
        dealingCardIndex = 0

        let playerCount = engine.players.count
        var cardStep = 0

        dealTimer?.invalidate()
        dealTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { timer.invalidate(); return }

                let playerIdx = cardStep % playerCount
                self.dealtPlayerIndices.insert(playerIdx)
                self.dealingCardIndex = cardStep
                self.soundManager.playDealCard()
                self.objectWillChange.send()

                cardStep += 1

                // Each player gets 2 cards
                if cardStep >= playerCount * 2 {
                    timer.invalidate()
                    // Short pause then finish
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.isDealing = false
                        self.engine.finishDealing()
                        self.objectWillChange.send()
                        self.startAILoop()
                    }
                }
            }
        }
    }

    // MARK: - AI Loop

    private func startAILoop() {
        aiTimer?.invalidate()
        guard !engine.waitingForHuman,
              engine.phase != .handOver,
              engine.phase != .showdown,
              engine.phase != .waiting,
              engine.phase != .dealing else {
            if engine.phase == .handOver {
                showResults = true
                soundManager.playWin()
            }
            return
        }

        aiTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.engine.processAITurn() {
                    // Play sound for AI action
                    if let player = self.engine.currentPlayer ?? self.engine.players.last {
                        switch player.lastAction {
                        case .fold: self.soundManager.playFold()
                        case .check: self.soundManager.playCheck()
                        case .call, .raise: self.soundManager.playChipBet()
                        case .allIn: self.soundManager.playAllIn()
                        case .none: break
                        }
                    }
                    self.objectWillChange.send()
                    self.startAILoop()
                } else if self.engine.phase == .handOver || self.engine.phase == .showdown {
                    self.showResults = true
                    self.soundManager.playWin()
                }
            }
        }
    }

    func updateRaiseBounds() {
        let minR = Double(engine.minRaise)
        let maxR = Double(maxRaise)
        if raiseAmount < minR { raiseAmount = minR }
        if raiseAmount > maxR { raiseAmount = maxR }
    }

    deinit {
        aiTimer?.invalidate()
        dealTimer?.invalidate()
    }
}
