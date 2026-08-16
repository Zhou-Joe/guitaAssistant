import SwiftUI

/// 调音主界面。对应 Flutter 版 `lib/screens/tuner/tuner_screen.dart`。
struct TunerView: View {
    @State private var viewModel = TunerViewModel()

    var body: some View {
        VStack(spacing: 24) {
            TunerDisplay(
                frequency: viewModel.currentFrequency,
                detectedNote: viewModel.detectedNote,
                cents: viewModel.cents,
                nearestStringIndex: viewModel.nearestStringIndex,
                selectedStringNote: viewModel.selectedStringIndex.map {
                    AppConstants.guitarStringNotes[$0]
                },
                isInTune: viewModel.isInTune,
                isListening: viewModel.isListening,
                errorMessage: viewModel.errorMessage
            )
            .padding(.top, 16)

            Spacer()

            stringButtons

            Spacer()

            startStopButton
                .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .navigationTitle(NSLocalizedString("tuner", comment: ""))
        .navigationBarTitleDisplayMode(.large)
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

    // MARK: - 弦按钮（3 行 × 2 列，模拟指板顺序）

    private var stringButtons: some View {
        // 行排列：[弦6,5][弦4,3][弦2,1]，对应索引 [0,1][2,3][4,5]
        let rows: [[Int]] = [[0, 1], [2, 3], [4, 5]]
        return VStack(spacing: 16) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(row, id: \.self) { index in
                        stringButton(for: index)
                    }
                }
            }
        }
    }

    private func stringButton(for index: Int) -> some View {
        let isSelected = viewModel.selectedStringIndex == index
        let isAutoMode = viewModel.selectedStringIndex == nil
        // 自动模式下：当前最近弦 = 被检测弦。
        let isDetected = viewModel.isListening && isAutoMode && viewModel.nearestStringIndex == index
        // 选中模式：调准；自动模式：检测到的弦且准音。
        let isTuned = (isSelected || isDetected) && viewModel.isInTune

        let stateColor: Color = {
            if isTuned { return AppColors.cta }
            if isDetected { return AppColors.warning }      // 自动模式检测中（未必准）
            if isSelected { return AppColors.secondary }     // 手动选中
            return AppColors.surface
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if viewModel.selectedStringIndex == index {
                    viewModel.selectedStringIndex = nil
                } else {
                    viewModel.selectedStringIndex = index
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Text("\(AppConstants.guitarStringNotes[index])")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(stateColor == AppColors.surface ? AppColors.textPrimary : .white)
                    Text(String(format: NSLocalizedString("string_n", comment: ""),
                                AppConstants.guitarStringNames[index]))
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.textMuted)
                    // 模拟琴弦横线：低音弦更粗
                    Capsule()
                        .fill(stateColor == AppColors.surface ? AppColors.textMuted : .white.opacity(0.7))
                        .frame(width: 36, height: stringThickness(for: index))
                }
                .frame(width: 72, height: 72)
                .background(stateColor, in: Circle())
                .shadow(color: stateColor.opacity(stateColor == AppColors.surface ? 0 : 0.5),
                        radius: stateColor == AppColors.surface ? 0 : 10)

                if isTuned {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.cta)
                        .background(Circle().fill(AppColors.background))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func stringThickness(for index: Int) -> CGFloat {
        // 索引 0(低音 E) 最粗，5(高音 E) 最细
        CGFloat(5 - index) * 0.6 + 1.0
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
    }
}
