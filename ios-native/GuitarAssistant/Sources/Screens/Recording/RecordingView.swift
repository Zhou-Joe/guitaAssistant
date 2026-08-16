import SwiftUI
import SwiftData
import AVKit

/// 录音界面。对应 Flutter `recording_screen.dart` + `recording_list.dart` + `player_widget.dart`。
struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ErrorState.self) private var errorState
    @Query(sort: \RecordingModel.createdAt, order: .reverse) private var recordings: [RecordingModel]
    @State private var viewModel = RecordingViewModel()
    @State private var playback = PlaybackController()
    @State private var pendingAnalysis: RecordingModel?
    @State private var shareItems: [Any]?
    @State private var previewSession: AVCaptureSession?

    var body: some View {
        VStack(spacing: 0) {
            recordSection
            Divider().background(AppColors.surfaceElevated)
            listSection
        }
        .navigationTitle(NSLocalizedString("recording", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // 注册保存回调（比 onChange 观察链更可靠，避免记录丢失）。
            viewModel.onComplete = { url, mode, duration in
                if let url { saveRecording(url, mode: mode, duration: duration) }
                else { errorState.show(NSLocalizedString("recording_save_failed", comment: "")) }
            }
        }
        .onDisappear {
            if viewModel.isRecording {
                // 视频模式：finish 异步写盘，teardown 需在写盘完成后执行（避免文件损坏）。
                if viewModel.mode == .video {
                    viewModel.onTeardownAfterFinish = { [weak viewModel] in
                        viewModel?.teardownVideo()
                    }
                    viewModel.finish()
                } else {
                    viewModel.finish()
                    viewModel.teardownVideo()
                }
            } else {
                viewModel.teardownVideo()
            }
        }
        .sheet(item: Binding(
            get: { shareItems.map { ShareItem(items: $0) } },
            set: { if $0 == nil { shareItems = nil } }
        )) { item in
            ShareSheet(items: item.items)
        }
    }

    // MARK: - 录制区

    private var recordSection: some View {
        VStack(spacing: 16) {
            Picker(NSLocalizedString("mode", comment: ""), selection: Binding(
                get: { viewModel.mode },
                set: { newMode in
                    viewModel.setMode(newMode)
                    // 切换模式时若正在录制，先结束保存当前录制。
                    if viewModel.isRecording { viewModel.finish() }
                    // 切到视频预热相机；切到音频释放相机。
                    if newMode == .video {
                        viewModel.prepareVideo { session in
                            previewSession = session
                        }
                    } else {
                        previewSession = nil
                        viewModel.teardownVideo()
                    }
                }
            )) {
                Text(NSLocalizedString("mode_audio", comment: "")).tag(RecordingMode.audio)
                Text(NSLocalizedString("mode_video", comment: "")).tag(RecordingMode.video)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // 视频模式显示相机预览；音频模式显示时长。
            if viewModel.mode == .video {
                videoPreview
            } else {
                Text(viewModel.formattedDuration)
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(viewModel.isRecording ? AppColors.error : AppColors.textPrimary)
            }

            recordButton
            if let error = viewModel.error {
                VStack(spacing: 4) {
                    Text(error).font(.caption).foregroundStyle(AppColors.error)
                        .multilineTextAlignment(.center).padding(.horizontal)
                    if isPermissionError(error) {
                        Button(NSLocalizedString("open_settings", comment: "")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption).foregroundStyle(AppColors.cta)
                    }
                }
            }
        }
        .padding(.vertical, 20)
    }

    /// 视频预览（叠加录制时长与录制按钮在预览上方）。
    private var videoPreview: some View {
        ZStack {
            // 黑色占位底；session 异步就绪后显示预览。
            Color.black
            if let session = previewSession {
                CameraPreview(session: session)
            } else {
                ProgressView().tint(AppColors.cta)
            }
            VStack {
                if viewModel.isRecording {
                    // 录制时长 + 红点。
                    HStack(spacing: 6) {
                        Circle().fill(AppColors.error).frame(width: 8, height: 8)
                        Text(viewModel.formattedDuration)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.black.opacity(0.4), in: Capsule())
                    .padding(.top, 12)
                }
                Spacer()
            }
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    /// 控制条：录制中/暂停时显示"停止保存"按钮 + 主按钮；空闲时只显示主按钮。
    private var controlBar: some View {
        HStack(spacing: 40) {
            // 录制中或暂停时显示"停止保存"（方块）。
            if viewModel.isRecording {
                Button {
                    viewModel.finish()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(AppColors.cta, in: Circle())
                        .shadow(color: AppColors.cta.opacity(0.4), radius: 8)
                }
                .accessibilityIdentifier("stopSaveButton")
                .accessibilityLabel(Text(NSLocalizedString("stop_save", comment: "")))
            }
            // 主按钮：idle→开始(圆点)；recording→暂停(方块)；paused→继续(三角)。
            Button {
                viewModel.toggleRecordOrPause()
            } label: {
                mainButtonLabel
            }
            .accessibilityIdentifier("recordToggleButton")
            // 占位，保证主按钮居中。
            if viewModel.isRecording { Spacer().frame(width: 56) }
        }
    }

    @ViewBuilder private var mainButtonLabel: some View {
        ZStack {
            Circle()
                .fill(viewModel.phase == .idle ? AppColors.cta : AppColors.error)
                .frame(width: 72, height: 72)
            switch viewModel.phase {
            case .idle:
                // 圆点（开始）。
                Circle().fill(.white).frame(width: 26, height: 26)
            case .recording:
                // 方块（暂停）。
                RoundedRectangle(cornerRadius: 4).fill(.white)
                    .frame(width: 24, height: 24)
            case .paused:
                // 三角（继续）。
                Image(systemName: "play.fill").font(.title).foregroundStyle(.white)
            }
        }
        .shadow(color: AppColors.error.opacity(0.4), radius: 10)
    }

    private var recordButton: some View {
        controlBar
    }

    // MARK: - 列表

    private var listSection: some View {
        Group {
            if recordings.isEmpty {
                EmptyStateView(
                    systemImage: "waveform",
                    title: NSLocalizedString("no_recordings", comment: ""),
                    message: NSLocalizedString("no_recordings_hint", comment: "")
                )
            } else {
                recordingList
            }
        }
    }

    private var recordingList: some View {
        List {
            ForEach(recordings) { rec in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: rec.mode == .audio ? "mic.fill" : "video.fill")
                            .foregroundStyle(AppColors.accentRecording)
                        Text(rec.title).foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text("\(rec.durationSeconds / 60):\(String(format: "%02d", rec.durationSeconds % 60))")
                            .font(.caption.monospacedDigit()).foregroundStyle(AppColors.textMuted)
                    }
                    playerRow(rec)
                    HStack {
                        Button {
                            pendingAnalysis = rec
                        } label: {
                            Label(NSLocalizedString("analyze", comment: ""), systemImage: "waveform.badge.magnifyingglass")
                                .font(.caption)
                        }
                        Spacer()
                        // 分享按钮：弹系统分享面板，自动列出已安装的社交 App
                        // （哔哩哔哩/小红书/抖音/微信等）。
                        Button {
                            shareRecording(rec)
                        } label: {
                            Label(NSLocalizedString("share", comment: ""), systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                    }
                }
                .listRowBackground(AppColors.surface)
                .listRowSeparatorTint(AppColors.surfaceElevated)
                .swipeActions {
                    Button(role: .destructive) { delete(rec) } label: {
                        Label(NSLocalizedString("delete", comment: ""), systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .sheet(item: $pendingAnalysis) { rec in
            NavigationStack {
                AnalysisView(recording: rec)
            }
        }
    }

    private func playerRow(_ rec: RecordingModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 视频：当前播放时显示视频画面；否则显示缩略占位。
            if rec.mode == .video && playback.currentRecordingId == rec.id,
               let vp = playback.videoPlayer {
                VideoPlayer(player: vp)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            // 播放控制条。
            HStack(spacing: 12) {
                Button {
                    playback.toggle(recording: rec)
                } label: {
                    Image(systemName: (playback.currentRecordingId == rec.id && playback.isPlaying)
                          ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2).foregroundStyle(AppColors.cta)
                }
                Slider(value: Binding(
                    get: { playback.currentRecordingId == rec.id ? playback.progress : 0 },
                    set: { if playback.currentRecordingId == rec.id { playback.seek(to: $0) } }
                ), in: 0...1)
                .tint(AppColors.cta)
                Text(playback.currentRecordingId == rec.id
                     ? "\(playback.formattedPosition) / \(playback.formattedDuration)"
                     : formatDuration(rec.durationSeconds))
                    .font(.caption2.monospacedDigit()).foregroundStyle(AppColors.textMuted)
            }
            // 播放错误提示。
            if playback.currentRecordingId == rec.id, let err = playback.errorMessage {
                Text(err).font(.caption).foregroundStyle(AppColors.error)
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - 操作

    private func saveRecording(_ url: URL, mode: RecordingMode, duration: Int) {
        let title = url.deletingPathExtension().lastPathComponent
        let rec = RecordingModel(title: title, filePath: url.path,
                                 mode: mode, durationSeconds: duration)
        modelContext.insert(rec)
        do {
            try modelContext.save()
        } catch {
            errorState.show(NSLocalizedString("save_failed", comment: ""))
        }
    }

    /// 分享录音/录像：弹系统分享面板，自动列出已安装的社交 App
    /// （哔哩哔哩、小红书、抖音、微信等）。
    private func shareRecording(_ rec: RecordingModel) {
        let url = URL(fileURLWithPath: rec.filePath)
        guard FileManager.default.fileExists(atPath: rec.filePath) else {
            errorState.show(NSLocalizedString("file_not_found", comment: ""))
            return
        }
        // 视频用文件 URL 分享（社交 App 能直接读取）；
        // 音频也用 URL，部分 App 支持。
        var items: [Any] = [url]
        // 附带一段文案，用户可在分享面板编辑。
        let text = String(format: NSLocalizedString("share_text", comment: ""), rec.title)
        items.insert(text, at: 0)
        shareItems = items
    }

    private func delete(_ rec: RecordingModel) {
        if playback.currentRecordingId == rec.id { playback.stop() }
        modelContext.delete(rec)
        try? FileManager.default.removeItem(atPath: rec.filePath)
        do {
            try modelContext.save()
        } catch {
            errorState.show(NSLocalizedString("delete_failed", comment: ""))
        }
    }

    /// 判断错误是否为权限拒绝（用于显示"打开设置"入口）。
    private func isPermissionError(_ message: String) -> Bool {
        let mic = NSLocalizedString("mic_permission_denied", comment: "")
        let cam = NSLocalizedString("camera_permission_denied", comment: "")
        return message == mic || message == cam
    }
}

/// 分享内容包装器（供 .sheet(item:) 使用）。
private struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}
