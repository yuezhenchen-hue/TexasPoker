import SwiftUI

struct CardView: View {
    let card: Card?
    var faceUp: Bool = true
    var width: CGFloat = 52
    var height: CGFloat = 74

    var body: some View {
        if let card = card, faceUp {
            faceUpCard(card)
        } else {
            faceDownCard
        }
    }

    private func faceUpCard(_ card: Card) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.white)
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: -2) {
                        Text(card.rankString)
                            .font(.system(size: width * 0.28, weight: .bold, design: .rounded))
                        Text(card.suit.symbol)
                            .font(.system(size: width * 0.24))
                    }
                    .foregroundColor(card.suit.isRed ? .red : .black)
                    Spacer()
                }
                .padding(.leading, 4)
                .padding(.top, 3)

                Spacer()

                Text(card.suit.symbol)
                    .font(.system(size: width * 0.5))
                    .foregroundColor(card.suit.isRed ? .red : .black)

                Spacer()
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
    }

    private var faceDownCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.25, blue: 0.55),
                                 Color(red: 0.2, green: 0.35, blue: 0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .padding(3)

            // Decorative pattern
            VStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: width * 0.12, height: width * 0.12)
                        }
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
    }
}

struct CardRow: View {
    let cards: [Card]
    var faceUp: Bool = true
    var spacing: CGFloat = 6
    var cardWidth: CGFloat = 52

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(cards) { card in
                CardView(card: card, faceUp: faceUp, width: cardWidth, height: cardWidth * 1.42)
            }
        }
    }
}
