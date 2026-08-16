import SwiftUI

/// 节拍器主界面。对应 Flutter 版 `lib/screens/metronome/metronome_screen.dart`。
struct MetronomeView: View {
    @Environment(MetronomeEngine.self) private var engine

    @State private var showTimeSignature = false
    @State private var showSoundStyle = false
    @State private var showTempoMode = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                bpmControl
                beatIndicator

                HStack(spacing: 16) {
                    settingsCard(
                        title: NSLocalizedString("time_signature", comment: ""),
                        icon: "music.note.list",
                        value: engine.timeSignature,
                        isExpanded: $showTimeSignature
                    ) {
                        timeSignatureOptions
                    }
                    settingsCard(
                        title: NSLocalizedString("sound", comment: ""),
                        icon: "speaker.wave.2",
                        value: engine.soundStyle.displayName,
                        isExpanded: $showSoundStyle
                    ) {
                        soundStyleOptions
                    }
                }

                settingsCard(
                    title: NSLocalizedString("tempo_mode", comment: ""),
                    icon: "speedometer",
                    value: NSLocalizedString("tempo_mode_\(engine.tempoMode.rawValue)", comment: ""),
                    isExpanded: $showTempoMode,
                    full: true
                ) {
                    tempoModeOptions
                }

                // 音量调节
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.1.fill").foregroundStyle(AppColors.textSecondary)
                    Slider(value: Binding(
                        get: { Double(engine.volume) },
                        set: { engine.volume = Float($0) }
                    ), in: 0...1).tint(AppColors.cta)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(AppColors.textSecondary)
                }
                .padding()
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))

                // 错误提示（如音色加载失败）
                if let error = engine.error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.error)
                        Text(error).font(.caption).foregroundStyle(AppColors.error)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            playButton
                .padding(.bottom, 24)
        }
        .navigationTitle(NSLocalizedString("metronome", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        // 每拍触觉反馈（轻拍 selection）。
        .sensoryFeedback(.selection, trigger: engine.currentBeat)
    }

    // MARK: - BPM 控制

    private var bpmControl: some View {
        VStack(spacing: 12) {
            Text("\(engine.bpm)")
                .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(AppColors.cta)
                .contentTransition(.numericText())
            Text("BPM")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 12) {
                bpmStepButton(-5)
                bpmStepButton(-1)
                Spacer().frame(width: 80)
                bpmStepButton(1)
                bpmStepButton(5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private func bpmStepButton(_ delta: Int) -> some View {
        Button {
            engine.setBpm(engine.bpm + delta)
        } label: {
            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 56, height: 44)
                .background(AppColors.surfaceElevated, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - 拍点指示器

    private var beatIndicator: some View {
        HStack(spacing: 10) {
            ForEach(0..<engine.beatsPerMeasure, id: \.self) { i in
                Circle()
                    .fill(i == engine.currentBeat && engine.isPlaying
                          ? (i == 0 ? AppColors.cta : AppColors.secondary)
                          : AppColors.surfaceElevated)
                    .frame(width: i == engine.currentBeat && engine.isPlaying ? 16 : 12,
                           height: i == engine.currentBeat && engine.isPlaying ? 16 : 12)
                    .scaleEffect(i == engine.currentBeat && engine.isPlaying ? 1.2 : 1.0)
                    .animation(.easeOut(duration: 0.1), value: engine.currentBeat)
            }
        }
        .frame(height: 24)
        .opacity(engine.isPlaying ? 1 : 0.3)
    }

    // MARK: - 设置卡片

    @ViewBuilder
    private func settingsCard<Content: View>(title: String, icon: String, value: String,
                                             isExpanded: Binding<Bool>,
                                             full: Bool = false,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack {
                    Image(systemName: icon).foregroundStyle(AppColors.cta)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.caption).foregroundStyle(AppColors.textSecondary)
                        Text(value).font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption).foregroundStyle(AppColors.textMuted)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: full ? .infinity : nil)
    }

    private var timeSignatureOptions: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
            ForEach(AppConstants.timeSignatures, id: \.self) { sig in
                let selected = sig == engine.timeSignature
                Button {
                    engine.setTimeSignature(sig)
                } label: {
                    Text(sig)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selected ? .white : AppColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(selected ? AppColors.cta : AppColors.surfaceElevated,
                                    in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var soundStyleOptions: some View {
        VStack(spacing: 8) {
            ForEach(SoundStyle.allCases, id: \.self) { style in
                let selected = style == engine.soundStyle
                Button {
                    engine.setSoundStyle(style)
                } label: {
                    HStack {
                        Text(style.displayName).foregroundStyle(selected ? .white : AppColors.textSecondary)
                        Spacer()
                        if selected { Image(systemName: "checkmark").foregroundStyle(.white) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(selected ? AppColors.cta : AppColors.surfaceElevated,
                                in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var tempoModeOptions: some View {
        VStack(spacing: 8) {
            ForEach(TempoMode.allCases, id: \.self) { mode in
                let selected = mode == engine.tempoMode
                Button {
                    engine.setTempoMode(mode)
                } label: {
                    HStack {
                        Text(NSLocalizedString("tempo_mode_\(mode.rawValue)", comment: ""))
                            .foregroundStyle(selected ? .white : AppColors.textSecondary)
                        Spacer()
                        if selected { Image(systemName: "checkmark").foregroundStyle(.white) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(selected ? AppColors.secondary : AppColors.surfaceElevated,
                                in: RoundedRectangle(cornerRadius: 10))
                }
            }
            // gradual 模式显示目标 BPM
            if engine.tempoMode == .gradual {
                HStack {
                    Text(NSLocalizedString("target_bpm", comment: ""))
                        .font(.caption).foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    HStack(spacing: 8) {
                        Button { engine.targetGradualBpm -= 5 } label: { Image(systemName: "minus") }
                        Text("\(engine.targetGradualBpm)").monospacedDigit()
                        Button { engine.targetGradualBpm += 5 } label: { Image(systemName: "plus") }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - 播放按钮

    private var playButton: some View {
        Button {
            engine.togglePlay()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                Text(engine.isPlaying
                     ? NSLocalizedString("pause", comment: "")
                     : NSLocalizedString("start", comment: ""))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(width: 200, height: 56)
            .background(engine.isPlaying ? AppColors.error : AppColors.cta, in: Capsule())
            .shadow(color: (engine.isPlaying ? AppColors.error : AppColors.cta).opacity(0.4), radius: 12)
        }
    }
}
