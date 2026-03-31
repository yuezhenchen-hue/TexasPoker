import SwiftUI

struct GameView: View {
    @StateObject private var viewModel = GameViewModel()

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
            Text("阶段: \(viewModel.engine.phase.rawValue)")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            Spacer()

            Text("第 \(viewModel.engine.handNumber) 局")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 12)
        .padding(.top, geo.safeAreaInsets.top + 4)
    }

    // MARK: - Poker Table

    private func pokerTable(geo: GeometryProxy) -> some View {
        let tableW = geo.size.width - 40
        let tableH = min(geo.size.height * 0.32, 200.0)

        return ZStack {
            // Table
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

            // Pot
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

            // Community cards
            if !viewModel.engine.communityCards.isEmpty {
                CardRow(
                    cards: viewModel.engine.communityCards,
                    faceUp: true,
                    spacing: 5,
                    cardWidth: min(48, (tableW - 80) / 6)
                )
            }

            // Side players
            sidePlayers(tableW: tableW, tableH: tableH)

            // Message
            messageView
                .offset(y: tableH * 0.38)
        }
    }

    // MARK: - Players Layout

    private func topPlayers(geo: GeometryProxy) -> some View {
        let topAI = topPositionPlayers
        return HStack(spacing: 20) {
            ForEach(topAI, id: \.id) { player in
                PlayerView(
                    player: player,
                    isCurrent: isCurrentPlayer(player),
                    showCards: showAllCards,
                    isBottom: false
                )
            }
        }
    }

    private func sidePlayers(tableW: CGFloat, tableH: CGFloat) -> some View {
        let sides = sidePositionPlayers
        return ZStack {
            if sides.count > 0 {
                PlayerView(
                    player: sides[0],
                    isCurrent: isCurrentPlayer(sides[0]),
                    showCards: showAllCards,
                    isBottom: false
                )
                .offset(x: -tableW * 0.42, y: 0)
            }
            if sides.count > 1 {
                PlayerView(
                    player: sides[1],
                    isCurrent: isCurrentPlayer(sides[1]),
                    showCards: showAllCards,
                    isBottom: false
                )
                .offset(x: tableW * 0.42, y: 0)
            }
        }
    }

    private func bottomPlayer(geo: GeometryProxy) -> some View {
        PlayerView(
            player: viewModel.engine.human,
            isCurrent: isCurrentPlayer(viewModel.engine.human),
            showCards: true,
            isBottom: true
        )
    }

    /// AI at top center area
    private var topPositionPlayers: [Player] {
        let ai = viewModel.engine.aiPlayers
        guard ai.count >= 2 else { return ai }
        let mid = ai.count / 2
        return Array(ai[mid...].prefix(2))
    }

    /// AI on left/right sides
    private var sidePositionPlayers: [Player] {
        let ai = viewModel.engine.aiPlayers
        guard ai.count >= 1 else { return [] }
        let mid = ai.count / 2
        return Array(ai.prefix(mid))
    }

    // MARK: - Bottom Area

    private func bottomArea(geo: GeometryProxy) -> some View {
        Group {
            if viewModel.engine.phase == .waiting {
                startButton
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
        Button(action: { viewModel.startGame() }) {
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
        Button(action: { viewModel.nextHand() }) {
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

                // Show all non-folded players' cards
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

                Button(action: { viewModel.nextHand() }) {
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
        }
    }

    // MARK: - Helpers

    private func isCurrentPlayer(_ player: Player) -> Bool {
        guard viewModel.engine.phase != .waiting,
              viewModel.engine.phase != .handOver,
              viewModel.engine.phase != .showdown else { return false }
        return viewModel.engine.currentPlayerIndex < viewModel.engine.players.count &&
               viewModel.engine.players[viewModel.engine.currentPlayerIndex].id == player.id
    }

    private var showAllCards: Bool {
        viewModel.engine.phase == .showdown || viewModel.engine.phase == .handOver
    }
}
