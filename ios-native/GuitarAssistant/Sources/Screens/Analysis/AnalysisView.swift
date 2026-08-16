import SwiftUI
import SwiftData

/// 分析界面。对应 Flutter `analysis_screen.dart`，但接入真实 DSP。
struct AnalysisView: View {
    let recording: RecordingModel
    @State private var targetBPM: Int = 100
    @State private var result: AnalysisResult?
    @State private var isAnalyzing = false
    @State private var analyzeFailed = false
    @State private var viewType: AnalysisViewType = .waveform
    @Environment(\.dismiss) private var dismiss

    enum AnalysisViewType: String, CaseIterable {
        case waveform, timeline, heatmap
        var label: String { NSLocalizedString("analysis_\(rawValue)", comment: "") }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                infoCard
                if analyzeFailed {
                    EmptyStateView(systemImage: "exclamationmark.triangle",
                                   title: NSLocalizedString("analyze_failed", comment: ""),
                                   actionTitle: NSLocalizedString("retry", comment: "")) {
                        analyze()
                    }
                } else if let result {
                    statsCards(result.stats)
                    Picker("", selection: $viewType) {
                        ForEach(AnalysisViewType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch viewType {
                    case .waveform: WaveformView(waveform: result.waveform)
                    case .timeline: TimelineView(expected: result.expectedBeats, actual: result.actualBeats)
                    case .heatmap: HeatmapView(perBeat: result.perBeat)
                    }
                } else {
                    placeholder
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("analysis_title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(NSLocalizedString("close", comment: "")) { dismiss() }
            }
        }
        .onAppear { if result == nil && !analyzeFailed { analyze() } }
    }

    private var infoCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(recording.title).font(.headline).foregroundStyle(AppColors.textPrimary)
                HStack {
                    Text(NSLocalizedString("target_bpm", comment: ""))
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    HStack {
                        Button { adjustBPM(by: -5) } label: { Image(systemName: "minus") }
                        Text("\(targetBPM)").monospacedDigit()
                        Button { adjustBPM(by: 5) } label: { Image(systemName: "plus") }
                    }
                }
            }
        }
    }

    private func statsCards(_ stats: TimingStats) -> some View {
        HStack(spacing: 12) {
            statCard(title: NSLocalizedString("stat_accuracy", comment: ""),
                     value: String(format: "%.0f%%", stats.accuracy), color: AppColors.cta)
            statCard(title: NSLocalizedString("stat_on_beat", comment: ""),
                     value: "\(stats.onBeatCount)/\(stats.totalBeats)", color: AppColors.warning)
            statCard(title: NSLocalizedString("stat_deviation", comment: ""),
                     value: String(format: "%.0fms", stats.avgDeviation), color: AppColors.accentAnalysis)
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            if isAnalyzing {
                ProgressView()
                Text(NSLocalizedString("analyzing", comment: ""))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(height: 200)
    }

    private func adjustBPM(by delta: Int) {
        targetBPM = min(AppConstants.maxBPM, max(AppConstants.minBPM, targetBPM + delta))
        scheduleAnalyze()   // 防抖，不立即跑
    }

    /// 防抖：连点时取消旧任务，延迟 0.3s 再跑（避免并发分析互相覆盖）。
    @State private var analyzeTask: Task<Void, Never>?
    private func scheduleAnalyze() {
        analyzeTask?.cancel()
        analyzeTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await analyze()
        }
    }

    private func analyze() {
        guard !isAnalyzing else { return }   // 拦截重入
        isAnalyzing = true
        analyzeFailed = false
        let url = URL(fileURLWithPath: recording.filePath)
        let bpm = targetBPM
        DispatchQueue.global(qos: .userInitiated).async {
            let engine = AnalysisEngine()
            let res = engine.analyze(url: url, targetBPM: bpm)
            DispatchQueue.main.async {
                if let res {
                    self.result = res
                    self.analyzeFailed = false
                } else {
                    self.analyzeFailed = true
                }
                self.isAnalyzing = false
            }
        }
    }
}
