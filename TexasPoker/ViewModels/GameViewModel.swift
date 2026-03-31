import SwiftUI
import Combine

@MainActor
class GameViewModel: ObservableObject {
    @Published var engine = GameEngine()
    @Published var showResults = false
    @Published var raiseAmount: Double = 40

    private var aiTimer: Timer?

    var isGameActive: Bool {
        engine.phase != .waiting && engine.phase != .handOver
    }

    func startGame() {
        showResults = false
        engine.startNewHand()
        startAILoop()
    }

    func nextHand() {
        showResults = false
        engine.startNewHand()
        startAILoop()
    }

    func performAction(_ action: PlayerAction) {
        engine.processHumanAction(action)
        startAILoop()
    }

    func performRaise() {
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

    // MARK: - AI Loop

    private func startAILoop() {
        aiTimer?.invalidate()
        guard !engine.waitingForHuman,
              engine.phase != .handOver,
              engine.phase != .showdown,
              engine.phase != .waiting else {
            if engine.phase == .handOver {
                showResults = true
            }
            return
        }

        aiTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.engine.processAITurn() {
                    self.objectWillChange.send()
                    self.startAILoop()
                } else if self.engine.phase == .handOver || self.engine.phase == .showdown {
                    self.showResults = true
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
    }
}
