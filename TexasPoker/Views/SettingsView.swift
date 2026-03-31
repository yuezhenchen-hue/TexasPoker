import SwiftUI

struct GameSettings {
    var aiCount: Int = 4
    var startingChips: Int = 1000
}

struct SettingsView: View {
    @Binding var settings: GameSettings
    @ObservedObject var soundManager: SoundManager
    var onStart: () -> Void

    private let aiRange = 1...7

    var body: some View {
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

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // Title
                    VStack(spacing: 4) {
                        Text("♠ ♥ ♦ ♣")
                            .font(.system(size: 36))
                        Text("游戏设置")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    // Player count
                    settingsCard {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                    .foregroundColor(.green)
                                Text("AI 对手数量")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(settings.aiCount) 人")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.yellow)
                            }

                            HStack(spacing: 8) {
                                ForEach(Array(aiRange), id: \.self) { count in
                                    Button(action: {
                                        soundManager.playButtonTap()
                                        settings.aiCount = count
                                    }) {
                                        Text("\(count)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(settings.aiCount == count ? .black : .white)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(settings.aiCount == count ? Color.yellow : Color.white.opacity(0.15))
                                            )
                                    }
                                }
                            }

                            Text("总共 \(settings.aiCount + 1) 人参与牌局")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                    }

                    // Starting chips
                    settingsCard {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundColor(.green)
                                Text("起始筹码")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("$\(settings.startingChips)")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.yellow)
                            }

                            HStack(spacing: 8) {
                                ForEach([500, 1000, 2000, 5000], id: \.self) { amount in
                                    Button(action: {
                                        soundManager.playButtonTap()
                                        settings.startingChips = amount
                                    }) {
                                        Text("\(amount)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(settings.startingChips == amount ? .black : .white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(settings.startingChips == amount ? Color.yellow : Color.white.opacity(0.15))
                                            )
                                    }
                                }
                            }
                        }
                    }

                    // Sound settings
                    settingsCard {
                        VStack(spacing: 14) {
                            HStack {
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundColor(.green)
                                Text("音频设置")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }

                            Toggle(isOn: $soundManager.isMusicEnabled) {
                                HStack(spacing: 8) {
                                    Image(systemName: "music.note")
                                        .foregroundColor(.cyan)
                                    Text("背景音乐")
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .green))

                            Toggle(isOn: $soundManager.isSoundEnabled) {
                                HStack(spacing: 8) {
                                    Image(systemName: "waveform")
                                        .foregroundColor(.cyan)
                                    Text("游戏音效")
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                        }
                    }

                    // Start button
                    Button(action: {
                        soundManager.playButtonTap()
                        onStart()
                    }) {
                        HStack(spacing: 10) {
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

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
