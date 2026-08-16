import SwiftUI

/// 最小化节拍器悬浮窗。对应 Flutter 版 `lib/widgets/minimized_metronome.dart`。
/// 用户曾在节拍器页启动过播放后，切到其它 Tab 时常驻显示 BPM + 播放/暂停。
struct MinimizedMetronome: View {
    @Environment(MetronomeEngine.self) private var engine

    var body: some View {
        if engine.hasBeenStarted {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(engine.bpm)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(AppColors.textPrimary)
                    Text("BPM")
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.textMuted)
                }
                Button {
                    engine.togglePlay()
                } label: {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(engine.isPlaying ? AppColors.error : AppColors.cta, in: Circle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppColors.surfaceElevated, in: Capsule())
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
    }
}
