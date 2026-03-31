import SwiftUI

struct ActionBar: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 8) {
            if viewModel.canRaise {
                raiseSlider
            }

            HStack(spacing: 10) {
                foldButton
                checkOrCallButton
                raiseButton
                allInButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
        )
    }

    private var foldButton: some View {
        Button(action: { viewModel.performAction(.fold) }) {
            actionLabel("弃牌", color: .red)
        }
    }

    @ViewBuilder
    private var checkOrCallButton: some View {
        let options = viewModel.humanOptions
        let toCall = viewModel.toCall

        if toCall == 0 {
            Button(action: { viewModel.performAction(.check) }) {
                actionLabel("过牌", color: .blue)
            }
        } else if options.contains(where: { if case .call = $0 { return true }; return false }) {
            Button(action: { viewModel.performAction(.call(toCall)) }) {
                actionLabel("跟注 \(toCall)", color: .teal)
            }
        }
    }

    @ViewBuilder
    private var raiseButton: some View {
        if viewModel.canRaise {
            Button(action: { viewModel.performRaise() }) {
                actionLabel("加注 \(Int(viewModel.raiseAmount))", color: .orange)
            }
        }
    }

    private var allInButton: some View {
        Button(action: {
            viewModel.performAction(.allIn(viewModel.engine.human.chips))
        }) {
            actionLabel("全下", color: Color(red: 0.7, green: 0.1, blue: 0.1))
        }
    }

    private var raiseSlider: some View {
        HStack(spacing: 12) {
            Text("加注")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            Slider(
                value: $viewModel.raiseAmount,
                in: Double(viewModel.engine.minRaise)...Double(max(viewModel.engine.minRaise, viewModel.maxRaise)),
                step: 10
            )
            .accentColor(.orange)

            Text("\(Int(viewModel.raiseAmount))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 8)
    }

    private func actionLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
            )
    }
}
