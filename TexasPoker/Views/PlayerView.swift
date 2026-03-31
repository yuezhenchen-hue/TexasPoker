import SwiftUI

struct PlayerView: View {
    @ObservedObject var player: Player
    let isCurrent: Bool
    let showCards: Bool
    let isBottom: Bool

    var body: some View {
        VStack(spacing: 4) {
            if isBottom && !player.holeCards.isEmpty {
                cardRow
            }

            playerPanel

            if !isBottom && !player.holeCards.isEmpty {
                cardRow
            }

            statusBadge
        }
    }

    private var playerPanel: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(player.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                if player.isDealer {
                    dealerBadge
                }
            }

            Text("$\(player.chips)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.yellow)

            if player.currentBet > 0 {
                Text("下注: \(player.currentBet)")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan.opacity(0.9))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(panelColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isCurrent ? Color.green : Color.clear, lineWidth: 2)
                )
        )
    }

    private var panelColor: Color {
        if player.isFolded {
            return Color.gray.opacity(0.4)
        }
        if isCurrent {
            return Color.green.opacity(0.35)
        }
        return Color(red: 0.15, green: 0.15, blue: 0.25).opacity(0.85)
    }

    private var cardRow: some View {
        CardRow(
            cards: player.holeCards,
            faceUp: showCards || player.isHuman,
            spacing: 4,
            cardWidth: isBottom ? 52 : 40
        )
    }

    private var dealerBadge: some View {
        Text("D")
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.black)
            .frame(width: 18, height: 18)
            .background(Circle().fill(.yellow))
    }

    @ViewBuilder
    private var statusBadge: some View {
        if player.isFolded {
            Text("已弃牌")
                .font(.system(size: 10))
                .foregroundColor(.red.opacity(0.8))
        } else if player.isAllIn {
            Text("ALL IN")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.red)
        } else if let action = player.lastAction {
            Text(action.displayName)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}
