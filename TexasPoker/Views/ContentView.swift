import SwiftUI

struct ContentView: View {
    @State private var screen: AppScreen = .welcome
    @State private var settings = GameSettings()
    @StateObject private var soundManager = SoundManager.shared

    enum AppScreen {
        case welcome, settings, game
    }

    var body: some View {
        switch screen {
        case .welcome:
            welcomeScreen
                .transition(.opacity)
        case .settings:
            SettingsView(settings: $settings, soundManager: soundManager) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    screen = .game
                }
            }
            .transition(.move(edge: .trailing))
        case .game:
            GameView(
                aiCount: settings.aiCount,
                startingChips: settings.startingChips,
                onBack: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        screen = .settings
                    }
                }
            )
            .transition(.move(edge: .trailing))
        }
    }

    private var welcomeScreen: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.18),
                    Color(red: 0.02, green: 0.12, blue: 0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 120
                            )
                        )
                        .frame(width: 200, height: 200)

                    VStack(spacing: 4) {
                        Text("♠ ♥ ♦ ♣")
                            .font(.system(size: 40))

                        Text("德扑策略师")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Poker Strategy Master")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                VStack(spacing: 14) {
                    featureRow(icon: "person.3.fill", text: "自定义 1-7 个 AI 对手")
                    featureRow(icon: "suit.club.fill", text: "完整德州扑克规则 & 荷官发牌")
                    featureRow(icon: "music.note", text: "沉浸式背景音乐 & 音效")
                }
                .padding(.horizontal, 40)

                Spacer()

                Button(action: {
                    soundManager.playButtonTap()
                    withAnimation(.spring()) { screen = .settings }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("开始游戏")
                            .font(.system(size: 20, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 50)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color.green, Color(red: 0.15, green: 0.5, blue: 0.25)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .green.opacity(0.4), radius: 10, y: 4)
                    )
                }

                Spacer().frame(height: 40)
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
