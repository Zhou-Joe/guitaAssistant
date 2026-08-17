import Foundation
import AVFoundation
import SwiftUI

/// 录制服务。改进自 Flutter 版（录音录完即丢、录像完全未实现）：
/// - 音频用 AVAudioRecorder，AAC/m4a，落盘到 Documents/recordings/audio/。
/// - 录像用 AVCaptureSession，H.264/mp4，落盘到 Documents/recordings/video/。
/// - 停止时正确返回文件 URL 与时长。
final class RecordingService: NSObject, AVCaptureFileOutputRecordingDelegate {

    private var audioRecorder: AVAudioRecorder?
    private(set) var currentFileURL: URL?
    private var startedAt: Date?

    /// 音频录制回调（每 0.5s 更新电平/时长）。
    var onAudioLevel: ((Float) -> Void)?
    var timer: Timer?

    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)
    }

    // MARK: - 音频录制

    func startAudioRecording() throws -> URL {
        try configureSession()
        let url = StorageManager.shared.recordingsAudioURL
            .appendingPathComponent("rec_\(Int(Date().timeIntervalSince1970)).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.record()
        audioRecorder = recorder
        currentFileURL = url
        startedAt = Date()
        startMetering()
        return url
    }

    func stopAudioRecording() -> (url: URL, duration: Int)? {
        guard let recorder = audioRecorder, let url = currentFileURL else { return nil }
        recorder.stop()
        let duration = Int(Date().timeIntervalSince(startedAt ?? Date()))
        audioRecorder = nil
        stopMetering()
        return (url, duration)
    }

    func pauseAudioRecording() {
        audioRecorder?.pause()
    }

    func resumeAudioRecording() {
        audioRecorder?.record()
    }

    private func startMetering() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let r = self.audioRecorder else { return }
            r.updateMeters()
            let db = r.averagePower(forChannel: 0)   // -160...0
            let level = pow(10, db / 20)
            self.onAudioLevel?(level)
        }
    }

    private func stopMetering() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - 视频录制

    /// 视频采集会话（切换到视频模式时预热，供预览层与录制共用）。
    private(set) var videoSession: AVCaptureSession?
    private var movieOutput: AVCaptureMovieFileOutput?

    /// 准备视频会话（添加前后置输入 + movie 输出，开始运行供预览）。
    /// 返回供预览层绑定的 session。
    func prepareVideoSession() throws -> AVCaptureSession {
        try configureSession()
        // 复用已有会话。
        if let session = videoSession {
            if !session.isRunning { session.startRunning() }
            return session
        }
        let session = AVCaptureSession()
        session.sessionPreset = .high

        session.beginConfiguration()
        // 音频输入
        if let audio = AVCaptureDevice.default(for: .audio) {
            let input = try AVCaptureDeviceInput(device: audio)
            if session.canAddInput(input) { session.addInput(input) }
        }
        // 视频输入（后置摄像头）
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) { session.addInput(input) }
        }
        let output = AVCaptureMovieFileOutput()
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        applyPortraitOrientation()
        session.startRunning()
        videoSession = session
        movieOutput = output
        return session
    }

    // MARK: - 摄像头切换

    /// 当前使用的摄像头位置。
    private(set) var cameraPosition: AVCaptureDevice.Position = .back

    /// 是否有前置摄像头(决定 UI 是否显示切换按钮)。
    static func hasFrontCamera() -> Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    /// 切换前置/后置摄像头:重配视频输入,音频输入保持。
    /// 预览层绑定同一 session,切换后自动刷新。
    func switchCamera() throws -> AVCaptureDevice.Position {
        guard let session = videoSession else {
            throw NSError(domain: "Recording", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "视频会话未就绪"])
        }
        let newPosition: AVCaptureDevice.Position = cameraPosition == .back ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let input = try? AVCaptureDeviceInput(device: device) else {
            throw NSError(domain: "Recording", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "摄像头不可用"])
        }
        session.beginConfiguration()
        // 移除现有视频输入(保留音频)。
        for existing in session.inputs {
            if let deviceInput = existing as? AVCaptureDeviceInput,
               deviceInput.device.hasMediaType(.video) {
                session.removeInput(existing)
            }
        }
        if session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()
        cameraPosition = newPosition
        // 输入变化后连接重建,重新应用竖屏方向。
        applyPortraitOrientation()
        return newPosition
    }

    /// 录制连接设为竖屏方向(app 锁定竖屏,默认 landscape 会把视频录成横的)。
    private func applyPortraitOrientation() {
        guard let connection = movieOutput?.connection(with: .video),
              connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }

    /// 停止视频会话（离开视频模式时调用，释放相机）。
    func teardownVideoSession() {
        videoSession?.stopRunning()
        videoSession = nil
        movieOutput = nil
    }

    func startVideoRecording() throws -> URL {
        guard let session = videoSession, let output = movieOutput else {
            throw NSError(domain: "Recording", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "视频会话未就绪"])
        }
        if !session.isRunning { session.startRunning() }
        let url = StorageManager.shared.recordingsVideoURL
            .appendingPathComponent("rec_\(Int(Date().timeIntervalSince1970)).mp4")
        currentFileURL = url
        startedAt = Date()
        output.startRecording(to: url, recordingDelegate: self)
        return url
    }

    /// 视频录制完成回调（委托驱动，避免文件未写完就读取的竞态）。
    /// 参数为 nil 表示录制失败。
    private var videoStopCompletion: ((URL?) -> Void)?

    /// 异步停止视频录制，完成后回调（文件已最终写入磁盘）。
    func stopVideoRecording(completion: @escaping (URL?) -> Void) {
        guard let output = movieOutput else { completion(nil); return }
        videoStopCompletion = completion
        output.stopRecording()
    }

    func pauseVideoRecording() {
        guard let output = movieOutput, output.isRecording else { return }
        if #available(iOS 18.0, *) {
            output.pauseRecording()
        }
        // iOS 17 无暂停 API：保持运行（UI 仍显示暂停态，仅停止计时）。
    }

    func resumeVideoRecording() {
        guard let output = movieOutput else { return }
        if #available(iOS 18.0, *) {
            output.resumeRecording()
        }
    }

    // MARK: - delegate（视频录制完成）

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        let result: URL? = (error == nil) ? outputFileURL : nil
        // 若失败，删除可能损坏的临时文件。
        if result == nil {
            try? FileManager.default.removeItem(at: outputFileURL)
        }
        let completion = videoStopCompletion
        videoStopCompletion = nil
        DispatchQueue.main.async {
            completion?(result)
        }
    }
}

/// 录制视图模型。
@Observable
final class RecordingViewModel {
    /// 录制状态机：idle(未录) / recording(录中) / paused(暂停)。
    enum Phase: Equatable { case idle, recording, paused }
    private(set) var phase: Phase = .idle
    /// 是否正在录制（含暂停态，便于 UI 判断有无进行中的会话）。
    var isRecording: Bool { phase != .idle }

    private(set) var durationSeconds: Int = 0
    private(set) var mode: RecordingMode = .audio
    /// 当前摄像头位置(视频模式)。
    private(set) var cameraPosition: AVCaptureDevice.Position = .back
    private(set) var error: String?
    private(set) var audioLevel: Float = 0

    /// 录制完成回调：View 注册保存到数据库（避免依赖 onChange 观察链）。
    /// 参数：文件 URL、模式、时长(秒)；URL 为 nil 表示保存失败。
    var onComplete: ((URL?, RecordingMode, Int) -> Void)?
    /// 视频写盘完成后的清理回调（onDisappear 时注册，避免 teardown 抢在写盘前）。
    var onTeardownAfterFinish: (() -> Void)?

    private let service = RecordingService()
    private var timer: Timer?

    func setMode(_ mode: RecordingMode) { self.mode = mode }

    /// 预热视频会话（切换到视频模式时调用）。
    /// startRunning 是阻塞调用，在后台执行后通过回调返回 session。
    /// 若已有会话则同步返回（复用预览，不阻塞）。
    func prepareVideo(completion: @escaping (AVCaptureSession?) -> Void) {
        // 已有会话则直接返回（复用预览，不阻塞）。
        if let existing = service.videoSession {
            completion(existing)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let session = try self?.service.prepareVideoSession()
                DispatchQueue.main.async { completion(session) }
            } catch {
                DispatchQueue.main.async {
                    self?.error = error.localizedDescription
                    completion(nil)
                }
            }
        }
    }

    /// 离开视频模式时释放相机。
    func teardownVideo() {
        service.teardownVideoSession()
        cameraPosition = .back
    }

    /// 能否切换摄像头:视频模式、未在录制、设备有前置摄像头。
    var canSwitchCamera: Bool {
        mode == .video && phase == .idle && RecordingService.hasFrontCamera()
    }

    /// 切换前置/后置摄像头(仅空闲时可切,避免录制中途换输入产生坏文件)。
    func switchCamera() {
        guard canSwitchCamera, let session = service.videoSession, session.isRunning else {
            // 会话未预热完成时忽略(预热完成后按钮才可用,此处兜底)。
            if canSwitchCamera { error = NSLocalizedString("camera_unavailable", comment: "") }
            return
        }
        do {
            cameraPosition = try service.switchCamera()
        } catch {
            self.error = error.localizedDescription
        }
    }

    deinit {
        timer?.invalidate()
        teardownVideo()
    }

    /// 主按钮：idle→开始；recording→暂停；paused→继续。
    func toggleRecordOrPause() {
        switch phase {
        case .idle:
            requestPermissionAndStart()
        case .recording:
            pause()
        case .paused:
            resume()
        }
    }

    /// 停止并保存（独立按钮）。
    func finish() {
        guard phase != .idle else { return }
        let wasMode = mode
        phase = .idle
        stopTimer()
        let duration = durationSeconds

        switch wasMode {
        case .audio:
            if let result = service.stopAudioRecording() {
                // 统一用 UI 累计的 durationSeconds（不含暂停时长），两模式一致。
                onComplete?(result.url, .audio, duration)
            } else {
                onComplete?(nil, .audio, 0)
            }
        case .video:
            // 视频停止异步：委托回调后才最终写入磁盘。
            service.stopVideoRecording { [weak self] url in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let url {
                        self.onComplete?(url, .video, duration)
                    } else {
                        self.error = NSLocalizedString("recording_save_failed", comment: "")
                        self.onComplete?(nil, .video, 0)
                    }
                    // 写盘完成后执行 teardown（onDisappear 时注册）。
                    self.onTeardownAfterFinish?()
                    self.onTeardownAfterFinish = nil
                }
            }
        }
    }

    private func pause() {
        switch mode {
        case .audio:
            service.pauseAudioRecording()
        case .video:
            service.pauseVideoRecording()
        }
        phase = .paused
        stopTimer()
    }

    private func resume() {
        switch mode {
        case .audio:
            service.resumeAudioRecording()
        case .video:
            service.resumeVideoRecording()
        }
        phase = .recording
        startTimer()
    }

    /// 先请求权限，再开始录制（权限拒绝时给出友好提示而非裸系统错误）。
    private func requestPermissionAndStart() {
        error = nil
        durationSeconds = 0

        // 麦克风权限（音频/视频都需要）。
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.error = NSLocalizedString("mic_permission_denied", comment: "")
                    return
                }
                if self.mode == .video {
                    self.requestCameraPermissionThenStart()
                } else {
                    self.actuallyStart()
                }
            }
        }
    }

    private func requestCameraPermissionThenStart() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            actuallyStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted { self.actuallyStart() }
                    else { self.error = NSLocalizedString("camera_permission_denied", comment: "") }
                }
            }
        default:
            error = NSLocalizedString("camera_permission_denied", comment: "")
        }
    }

    private func actuallyStart() {
        AudioSessionCoordinator.shared.activate(for: mode == .audio ? .recordOnly : .record)
        do {
            switch mode {
            case .audio:
                _ = try service.startAudioRecording()
            case .video:
                _ = try service.startVideoRecording()
            }
            phase = .recording
            startTimer()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.durationSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    var formattedDuration: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
