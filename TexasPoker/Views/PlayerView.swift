import SwiftUI

struct AvatarView: View {
    let avatar: AvatarInfo
    let size: CGFloat
    let isCurrent: Bool
    let isFolded: Bool

    var body: some View {
        ZStack {
            // Glow ring for current player
            if isCurrent {
                Circle()
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: size + 6, height: size + 6)
                    .shadow(color: .green.opacity(0.6), radius: 6)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [avatar.bgColors.0, avatar.bgColors.1],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )

            Text(avatar.emoji)
                .font(.system(size: size * 0.52))
        }
        .opacity(isFolded ? 0.45 : 1.0)
    }
}

struct PlayerView: View {
    @ObservedObject var player: Player
    let isCurrent: Bool
    let showCards: Bool
    let isBottom: Bool

    var body: some View {
        VStack(spacing: 3) {
            if isBottom && !player.holeCards.isEmpty {
                cardRow
            }

            playerPanel

            if !isBottom && !player.holeCards.isEmpty {
                cardRow
            }
        }
    }

    private var playerPanel: some View {
        HStack(spacing: 8) {
            AvatarView(
                avatar: player.avatar,
                size: isBottom ? 44 : 38,
                isCurrent: isCurrent,
                isFolded: player.isFolded
            )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(player.name)
                        .font(.system(size: isBottom ? 14 : 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if player.isDealer {
                        dealerBadge
                    }
                }

                Text("$\(player.chips)")
                    .font(.system(size: isBottom ? 13 : 11, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)

                if player.currentBet > 0 {
                    Text("下注: \(player.currentBet)")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan.opacity(0.9))
                }

                statusLabel
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(panelColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrent ? Color.green.opacity(0.8) : Color.white.opacity(0.08), lineWidth: isCurrent ? 2 : 1)
                )
                .shadow(color: isCurrent ? .green.opacity(0.3) : .clear, radius: 6)
        )
    }

    private var panelColor: Color {
        if player.isFolded {
            return Color.gray.opacity(0.3)
        }
        if isCurrent {
            return Color.green.opacity(0.25)
        }
        return Color(red: 0.12, green: 0.12, blue: 0.22).opacity(0.9)
    }

    private var cardRow: some View {
        CardRow(
            cards: player.holeCards,
            faceUp: showCards || player.isHuman,
            spacing: 4,
            cardWidth: isBottom ? 52 : 38
        )
    }

    private var dealerBadge: some View {
        Text("D")
            .font(.system(size: 9, weight: .black))
            .foregroundColor(.black)
            .frame(width: 16, height: 16)
            .background(Circle().fill(.yellow))
    }

    @ViewBuilder
    private var statusLabel: some View {
        if player.isFolded {
            Text("已弃牌")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.red.opacity(0.8))
        } else if player.isAllIn {
            Text("ALL IN")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.red)
        } else if let action = player.lastAction {
            Text(action.displayName)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}
