import SwiftUI

struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    @ObservedObject private var soundManager = SoundManager.shared
    var onBack: () -> Void

    init(aiCount: Int, startingChips: Int, onBack: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: GameViewModel(aiCount: aiCount, startingChips: startingChips))
        self.onBack = onBack
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background

                VStack(spacing: 0) {
                    topBar(geo: geo)

                    Spacer(minLength: 4)

                    topPlayers(geo: geo)

                    Spacer(minLength: 4)

                    pokerTable(geo: geo)

                    Spacer(minLength: 4)

                    bottomPlayer(geo: geo)

                    Spacer(minLength: 4)

                    bottomArea(geo: geo)
                }
                .padding(.horizontal, 8)

                // Dealing animation overlay
                if viewModel.isDealing {
                    dealingOverlay(geo: geo)
                }

                if viewModel.showResults && !viewModel.engine.handResults.isEmpty {
                    resultsOverlay
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.12),
                Color(red: 0.08, green: 0.12, blue: 0.08),
                Color(red: 0.05, green: 0.05, blue: 0.12),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private func topBar(geo: GeometryProxy) -> some View {
        HStack {
            Button(action: {
                soundManager.playButtonTap()
                soundManager.stopMusic()
                onBack()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("设置")
                }
                .font(.system(size: 13))
                .foregroundColor(.gray)
            }

            Spacer()

            Text("阶段: \(viewModel.engine.phase.rawValue)")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            Spacer()

            HStack(spacing: 12) {
                // Music toggle
                Button(action: {
                    soundManager.isMusicEnabled.toggle()
                    soundManager.playButtonTap()
                }) {
                    Image(systemName: soundManager.isMusicEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(soundManager.isMusicEnabled ? .green : .gray)
                }

                Text("第 \(viewModel.engine.handNumber) 局")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, geo.safeAreaInsets.top + 4)
    }

    // MARK: - Dealing Overlay

    private func dealingOverlay(geo: GeometryProxy) -> some View {
        let deckPos = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 - 60)

        return ZStack {
            // Deck position indicator
            VStack(spacing: 4) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.yellow.opacity(0.8))
                Text("荷官发牌中...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .position(deckPos)

            // Flying cards animation
            ForEach(Array(viewModel.dealtPlayerIndices), id: \.self) { idx in
                CardView(card: nil, faceUp: false, width: 36, height: 51)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.dealtPlayerIndices)
    }

    // MARK: - Poker Table

    private func pokerTable(geo: GeometryProxy) -> some View {
        let tableW = geo.size.width - 40
        let tableH = min(geo.size.height * 0.32, 200.0)

        return ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.15, green: 0.45, blue: 0.25),
                            Color(red: 0.1, green: 0.35, blue: 0.18)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: tableW * 0.5
                    )
                )
                .frame(width: tableW, height: tableH)

            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.5, green: 0.3, blue: 0.1),
                            Color(red: 0.35, green: 0.2, blue: 0.08),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 8
                )
                .frame(width: tableW, height: tableH)

            if viewModel.engine.pot > 0 {
                VStack(spacing: 2) {
                    Text("底池")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.engine.pot)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.5)))
                .offset(y: -tableH * 0.28)
            }

            if !viewModel.engine.communityCards.isEmpty {
                CardRow(
                    cards: viewModel.engine.communityCards,
                    faceUp: true,
                    spacing: 5,
                    cardWidth: min(48, (tableW - 80) / 6)
                )
                .transition(.scale.combined(with: .opacity))
                .animation(.easeOut(duration: 0.3), value: viewModel.engine.communityCards.count)
            }

            sidePlayers(tableW: tableW, tableH: tableH)

            messageView
                .offset(y: tableH * 0.38)
        }
    }

    // MARK: - Players Layout

    private func topPlayers(geo: GeometryProxy) -> some View {
        let topAI = topPositionPlayers
        return HStack(spacing: 16) {
            ForEach(topAI, id: \.id) { player in
                playerViewAnimated(player: player, isBottom: false)
            }
        }
    }

    private func sidePlayers(tableW: CGFloat, tableH: CGFloat) -> some View {
        let sides = sidePositionPlayers
        return ZStack {
            if sides.count > 0 {
                playerViewAnimated(player: sides[0], isBottom: false)
                    .offset(x: -tableW * 0.42, y: 0)
            }
            if sides.count > 1 {
                playerViewAnimated(player: sides[1], isBottom: false)
                    .offset(x: tableW * 0.42, y: 0)
            }
        }
    }

    private func bottomPlayer(geo: GeometryProxy) -> some View {
        playerViewAnimated(player: viewModel.engine.human, isBottom: true)
    }

    private func playerViewAnimated(player: Player, isBottom: Bool) -> some View {
        let showCards: Bool
        if viewModel.isDealing {
            let idx = viewModel.engine.players.firstIndex(where: { $0.id == player.id }) ?? -1
            showCards = player.isHuman && viewModel.dealtPlayerIndices.contains(idx)
        } else {
            showCards = showAllCards || player.isHuman
        }

        return PlayerView(
            player: player,
            isCurrent: isCurrentPlayer(player),
            showCards: showCards,
            isBottom: isBottom
        )
        .animation(.easeInOut(duration: 0.3), value: player.isFolded)
    }

    private var topPositionPlayers: [Player] {
        let ai = viewModel.engine.aiPlayers
        if ai.count <= 2 { return ai }
        let mid = ai.count / 2
        return Array(ai[mid...])
    }

    private var sidePositionPlayers: [Player] {
        let ai = viewModel.engine.aiPlayers
        guard ai.count >= 1 else { return [] }
        if ai.count <= 2 { return [] }
        let mid = ai.count / 2
        return Array(ai.prefix(mid))
    }

    // MARK: - Bottom Area

    private func bottomArea(geo: GeometryProxy) -> some View {
        Group {
            if viewModel.engine.phase == .waiting {
                startButton
            } else if viewModel.isDealing {
                Text("荷官发牌中...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.yellow)
            } else if viewModel.engine.phase == .handOver {
                nextHandButton
            } else if viewModel.engine.waitingForHuman {
                ActionBar(viewModel: viewModel)
            } else {
                Text("AI 思考中...")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.bottom, geo.safeAreaInsets.bottom + 8)
    }

    private var startButton: some View {
        Button(action: {
            soundManager.playButtonTap()
            viewModel.startGame()
        }) {
            Text("开始游戏")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        }
    }

    private var nextHandButton: some View {
        Button(action: {
            soundManager.playButtonTap()
            viewModel.nextHand()
        }) {
            Text("下一局")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
        }
    }

    // MARK: - Message

    private var messageView: some View {
        Text(viewModel.engine.message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            .animation(.easeInOut(duration: 0.2), value: viewModel.engine.message)
    }

    // MARK: - Results Overlay

    private var resultsOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 14) {
                Text("本局结果")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.yellow)

                ForEach(viewModel.engine.handResults) { result in
                    HStack {
                        Text(result.player.name)
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .semibold))

                        Spacer()

                        Text("+\(result.winnings)")
                            .foregroundColor(.green)
                            .font(.system(size: 16, weight: .bold, design: .rounded))

                        Text(result.handDescription)
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 20)
                }

                if viewModel.engine.activePlayers.count > 1 {
                    Divider().background(Color.white.opacity(0.3))

                    ForEach(viewModel.engine.activePlayers, id: \.id) { player in
                        HStack(spacing: 8) {
                            Text(player.name)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 60, alignment: .leading)

                            CardRow(cards: player.holeCards, faceUp: true, spacing: 4, cardWidth: 36)
                        }
                    }
                }

                Button(action: {
                    soundManager.playButtonTap()
                    viewModel.nextHand()
                }) {
                    Text("下一局")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.blue))
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private func isCurrentPlayer(_ player: Player) -> Bool {
        guard viewModel.engine.phase != .waiting,
              viewModel.engine.phase != .handOver,
              viewModel.engine.phase != .showdown,
              viewModel.engine.phase != .dealing else { return false }
        return viewModel.engine.currentPlayerIndex < viewModel.engine.players.count &&
               viewModel.engine.players[viewModel.engine.currentPlayerIndex].id == player.id
    }

    private var showAllCards: Bool {
        viewModel.engine.phase == .showdown || viewModel.engine.phase == .handOver
    }
}
