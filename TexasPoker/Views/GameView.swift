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
                    Spacer(minLength: 0)
                    tableArea(geo: geo)
                    Spacer(minLength: 0)
                    bottomArea(geo: geo)
                }

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
                Color(red: 0.04, green: 0.04, blue: 0.10),
                Color(red: 0.06, green: 0.10, blue: 0.06),
                Color(red: 0.04, green: 0.04, blue: 0.10),
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

            VStack(spacing: 1) {
                Text(viewModel.engine.phase.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text("盲注 \(GameEngine.smallBlind)/\(GameEngine.bigBlind)")
                    .font(.system(size: 10))
                    .foregroundColor(.orange.opacity(0.7))
            }

            Spacer()

            HStack(spacing: 12) {
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
        .padding(.horizontal, 14)
        .padding(.top, geo.safeAreaInsets.top + 2)
    }

    // MARK: - Table Area (big table + players around it)

    private func tableArea(geo: GeometryProxy) -> some View {
        let tableW = geo.size.width - 24
        let tableH = geo.size.height * 0.55
        let centerX = geo.size.width / 2
        let centerY = geo.safeAreaInsets.top + 40 + tableH / 2

        return ZStack {
            // The felt table
            pokerTable(tableW: tableW, tableH: tableH)

            // Community cards in center
            if !viewModel.engine.communityCards.isEmpty {
                CardRow(
                    cards: viewModel.engine.communityCards,
                    faceUp: true,
                    spacing: 6,
                    cardWidth: min(50, (tableW - 100) / 6)
                )
                .transition(.scale.combined(with: .opacity))
                .animation(.easeOut(duration: 0.3), value: viewModel.engine.communityCards.count)
            }

            // Pot above cards
            if viewModel.engine.pot > 0 {
                VStack(spacing: 1) {
                    Text("底池")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.engine.pot)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .offset(y: -tableH * 0.22)
            }

            // Message
            messageView
                .offset(y: tableH * 0.22)

            // Players arranged around the ellipse
            playersAroundTable(tableW: tableW, tableH: tableH)
        }
        .frame(width: geo.size.width, height: tableH + 60)
    }

    private func pokerTable(tableW: CGFloat, tableH: CGFloat) -> some View {
        ZStack {
            // Outer shadow glow
            Ellipse()
                .fill(Color.black.opacity(0.4))
                .frame(width: tableW + 4, height: tableH + 4)
                .blur(radius: 12)

            // Wood rim
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.45, green: 0.28, blue: 0.12),
                            Color(red: 0.32, green: 0.18, blue: 0.06),
                            Color(red: 0.45, green: 0.28, blue: 0.12),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: tableW, height: tableH)

            // Inner felt
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.16, green: 0.48, blue: 0.28),
                            Color(red: 0.10, green: 0.36, blue: 0.18),
                            Color(red: 0.07, green: 0.28, blue: 0.13),
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: tableW * 0.45
                    )
                )
                .frame(width: tableW - 20, height: tableH - 20)

            // Subtle highlight
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        center: UnitPoint(x: 0.4, y: 0.35),
                        startRadius: 10,
                        endRadius: tableW * 0.35
                    )
                )
                .frame(width: tableW - 20, height: tableH - 20)

            // Inner border line
            Ellipse()
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                .frame(width: tableW - 50, height: tableH - 50)
        }
    }

    // MARK: - Players around the table

    private func playersAroundTable(tableW: CGFloat, tableH: CGFloat) -> some View {
        let allPlayers = viewModel.engine.players
        let count = allPlayers.count

        // Human is always at bottom center, AI distributed around top half
        let positions = calculatePlayerPositions(count: count, tableW: tableW, tableH: tableH)

        return ZStack {
            ForEach(Array(allPlayers.enumerated()), id: \.element.id) { index, player in
                if index < positions.count {
                    playerViewAnimated(player: player, isBottom: player.isHuman)
                        .offset(x: positions[index].x, y: positions[index].y)
                }
            }
        }
    }

    private func calculatePlayerPositions(count: Int, tableW: CGFloat, tableH: CGFloat) -> [CGPoint] {
        // Index 0 = human (bottom), rest = AI spread around top
        guard count > 0 else { return [] }

        var positions: [CGPoint] = []

        // Human at bottom center
        positions.append(CGPoint(x: 0, y: tableH * 0.42))

        let aiCount = count - 1
        guard aiCount > 0 else { return positions }

        // AI players distributed on the upper arc of the ellipse
        // Angles from ~210° to ~330° (in standard math coords, that's upper half)
        let rx = tableW * 0.48
        let ry = tableH * 0.46

        if aiCount == 1 {
            // Directly across from human
            positions.append(CGPoint(x: 0, y: -ry))
        } else if aiCount == 2 {
            let angles: [CGFloat] = [-0.7, 0.7]  // roughly ±40°
            for a in angles {
                positions.append(CGPoint(x: sin(a) * rx, y: -cos(a) * ry))
            }
        } else {
            // Spread evenly across the upper arc
            let startAngle: CGFloat = -.pi * 0.75
            let endAngle: CGFloat = .pi * 0.75
            let step = (endAngle - startAngle) / CGFloat(aiCount + 1)

            for i in 1...aiCount {
                let angle = startAngle + step * CGFloat(i)
                let x = sin(angle) * rx
                let y = -cos(angle) * ry
                positions.append(CGPoint(x: x, y: y))
            }
        }

        return positions
    }

    private func playerViewAnimated(player: Player, isBottom: Bool) -> some View {
        let showCards: Bool
        if viewModel.isDealing {
            let idx = viewModel.engine.players.firstIndex(where: { $0.id == player.id }) ?? -1
            showCards = player.isHuman && viewModel.dealtPlayerIndices.contains(idx)
        } else {
            // During showdown, show ALL non-folded players' cards
            showCards = showAllCards || player.isHuman
        }

        let posName = viewModel.engine.positionName(for: player)

        return PlayerView(
            player: player,
            isCurrent: isCurrentPlayer(player),
            showCards: showCards,
            isBottom: isBottom,
            positionName: posName
        )
        .animation(.easeInOut(duration: 0.3), value: player.isFolded)
    }

    // MARK: - Dealing Overlay

    private func dealingOverlay(geo: GeometryProxy) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 32))
                .foregroundColor(.yellow.opacity(0.8))
            Text("荷官发牌中...")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
        )
        .animation(.easeInOut(duration: 0.2), value: viewModel.dealtPlayerIndices)
    }

    // MARK: - Bottom Area

    private func bottomArea(geo: GeometryProxy) -> some View {
        Group {
            if viewModel.engine.phase == .waiting {
                startButton
            } else if viewModel.isDealing {
                EmptyView()
            } else if viewModel.engine.phase == .showdown {
                // Showdown: cards are showing, wait
                VStack(spacing: 4) {
                    Text("摊牌 — 查看所有玩家手牌")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.yellow)
                    ProgressView()
                        .tint(.yellow.opacity(0.6))
                        .scaleEffect(0.8)
                }
            } else if viewModel.engine.phase == .handOver {
                nextHandButton
            } else if viewModel.isPhasePaused {
                // New community cards just appeared
                Text(viewModel.engine.message)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.yellow)
            } else if viewModel.engine.waitingForHuman {
                ActionBar(viewModel: viewModel)
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .tint(.white.opacity(0.5))
                        .scaleEffect(0.8)
                    Text("AI 思考中...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.bottom, geo.safeAreaInsets.bottom + 6)
        .padding(.horizontal, 12)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            .animation(.easeInOut(duration: 0.2), value: viewModel.engine.message)
    }

    // MARK: - Results Overlay

    private var resultsOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { }

            ScrollView {
                VStack(spacing: 14) {
                    Text("本局结果")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.yellow)

                    ForEach(viewModel.engine.handResults) { result in
                        HStack(spacing: 10) {
                            AvatarView(
                                avatar: result.player.avatar,
                                size: 32,
                                isCurrent: false,
                                isFolded: false
                            )

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
                        .padding(.horizontal, 16)
                    }

                    if viewModel.engine.activePlayers.count > 1 {
                        Divider().background(Color.white.opacity(0.3))

                        ForEach(viewModel.engine.activePlayers, id: \.id) { player in
                            HStack(spacing: 8) {
                                AvatarView(
                                    avatar: player.avatar,
                                    size: 24,
                                    isCurrent: false,
                                    isFolded: false
                                )

                                Text(player.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 55, alignment: .leading)

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
            }
            .frame(maxHeight: 420)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 30)
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

    /// During showdown AND handOver, all non-folded players' cards should be visible
    private var showAllCards: Bool {
        viewModel.engine.phase == .showdown || viewModel.engine.phase == .handOver || viewModel.showResults
    }
}
