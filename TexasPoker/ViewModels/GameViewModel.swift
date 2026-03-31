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

    // Phase pause state — when a new community phase arrives, we pause briefly
    @Published var isPhasePaused: Bool = false

    let soundManager = SoundManager.shared
    private var aiTimer: Timer?
    private var dealTimer: Timer?
    private var showdownTimer: Timer?

    /// Time AI takes to act (seconds)
    private let aiDelay: TimeInterval = 0.9
    /// Pause when new community cards appear (seconds)
    private let phasePauseDelay: TimeInterval = 1.5
    /// How long to show all cards at showdown before results overlay (seconds)
    private let showdownDisplayTime: TimeInterval = 3.5

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
        scheduleNextStep()
    }

    func performRaise() {
        soundManager.playChipBet()
        let amount = Int(raiseAmount)
        engine.processHumanAction(.raise(amount))
        scheduleNextStep()
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
        dealTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { timer.invalidate(); return }

                let playerIdx = cardStep % playerCount
                self.dealtPlayerIndices.insert(playerIdx)
                self.dealingCardIndex = cardStep
                self.soundManager.playDealCard()
                self.objectWillChange.send()

                cardStep += 1

                if cardStep >= playerCount * 2 {
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.isDealing = false
                        self.engine.finishDealing()
                        self.objectWillChange.send()
                        self.scheduleNextStep()
                    }
                }
            }
        }
    }

    // MARK: - Main game loop dispatcher

    private func scheduleNextStep() {
        aiTimer?.invalidate()

        // If a new community phase just started, pause so the player can see the cards
        if engine.phaseJustChanged {
            engine.phaseJustChanged = false
            isPhasePaused = true
            soundManager.playDealCard()
            aiTimer = Timer.scheduledTimer(withTimeInterval: phasePauseDelay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.isPhasePaused = false
                    self?.scheduleNextStep()
                }
            }
            return
        }

        // Showdown: all cards are visible, wait then show results
        if engine.phase == .showdown {
            soundManager.playWin()
            showdownTimer?.invalidate()
            showdownTimer = Timer.scheduledTimer(withTimeInterval: showdownDisplayTime, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.engine.finishShowdown()
                    self.showResults = true
                    self.objectWillChange.send()
                }
            }
            return
        }

        // Hand over
        if engine.phase == .handOver {
            showResults = true
            soundManager.playWin()
            return
        }

        // Waiting for human
        if engine.waitingForHuman {
            return
        }

        // Not actionable phases
        guard engine.phase != .waiting, engine.phase != .dealing else { return }

        // AI turn
        aiTimer = Timer.scheduledTimer(withTimeInterval: aiDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let prev = self.engine.currentPlayer
                if self.engine.processAITurn() {
                    if let p = prev {
                        switch p.lastAction {
                        case .fold: self.soundManager.playFold()
                        case .check: self.soundManager.playCheck()
                        case .call, .raise: self.soundManager.playChipBet()
                        case .allIn: self.soundManager.playAllIn()
                        case .none: break
                        }
                    }
                    self.objectWillChange.send()
                    self.scheduleNextStep()
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
        showdownTimer?.invalidate()
    }
}
