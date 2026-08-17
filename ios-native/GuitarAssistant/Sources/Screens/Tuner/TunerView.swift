import SwiftUI

/// 调音主界面:琴头整页矢量图为底,音名叠加在上部琴头面,
/// 偏差条/状态/开始按钮叠在下部琴颈之上。
struct TunerView: View {
    @State private var viewModel = TunerViewModel()

    var body: some View {
        ZStack {
            // 琴头整页背景(琴颈出血到底边)。点弦钮选弦(手动),再点回自动模式。
            TunerHeadstockView(
                detectedStringIndex: viewModel.nearestStringIndex,
                selectedStringIndex: viewModel.selectedStringIndex,
                isInTune: viewModel.isInTune,
                isListening: viewModel.isListening
            ) { newIndex in
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.selectedStringIndex = newIndex
                }
            }
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                TunerDisplay(
                    frequency: viewModel.currentFrequency,
                    detectedNote: viewModel.detectedNote,
                    nearestStringIndex: viewModel.nearestStringIndex,
                    selectedStringNote: viewModel.selectedStringIndex.map {
                        AppConstants.guitarStringNotes[$0]
                    },
                    isInTune: viewModel.isInTune,
                    isListening: viewModel.isListening
                )
                .padding(.top, 4)

                Spacer()

                VStack(spacing: 12) {
                    TunerMeterBar(cents: viewModel.cents)
                    statusText
                    startStopButton
                }
                .padding(.bottom, 16)
            }
        }
        .navigationTitle(NSLocalizedString("tuner", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            viewModel.stopListening()
        }
        // 调音命中时触发成功触觉反馈。
        .sensoryFeedback(.success, trigger: viewModel.isInTune)
        // 权限被拒时显示"打开设置"入口。
        .overlay(alignment: .bottom) {
            if let error = viewModel.errorMessage,
               error == NSLocalizedString("mic_permission_denied", comment: "") {
                VStack(spacing: 8) {
                    Text(error).font(.caption).foregroundStyle(AppColors.error)
                    Button(NSLocalizedString("open_settings", comment: "")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption).foregroundStyle(AppColors.cta)
                }
                .padding(.bottom, 120)
            }
        }
    }

    // MARK: - 状态文案

    private var statusText: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(statusColor)
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
    }

    private var message: String {
        if let errorMessage = viewModel.errorMessage { return errorMessage }
        if !viewModel.isListening { return NSLocalizedString("tap_start_to_begin", comment: "") }
        if viewModel.isInTune { return NSLocalizedString("in_tune", comment: "") }
        if viewModel.cents < -15 { return NSLocalizedString("too_flat_tighten", comment: "") }
        if viewModel.cents > 15 { return NSLocalizedString("too_sharp_loosen", comment: "") }
        return NSLocalizedString("almost_there", comment: "")
    }

    private var statusColor: Color {
        if viewModel.isInTune && viewModel.isListening { return AppColors.cta }
        if !viewModel.isListening { return AppColors.textMuted }
        return AppColors.textSecondary
    }

    // MARK: - Start/Stop

    private var startStopButton: some View {
        Button {
            if viewModel.isListening {
                viewModel.stopListening()
            } else {
                viewModel.startListening()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isListening ? "stop.fill" : "play.fill")
                Text(viewModel.isListening
                     ? NSLocalizedString("stop", comment: "")
                     : NSLocalizedString("start", comment: ""))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(width: 160, height: 44)
            .background(viewModel.isListening ? AppColors.error : AppColors.cta, in: Capsule())
        }
        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
    }
}
