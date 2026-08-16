import SwiftUI
import PDFKit
import SwiftData

/// 曲谱查看器。对应 Flutter `tab_viewer_screen.dart`：
/// PDF 用 PDFKit，图片用缩放视图；顶部保留内嵌节拍器面板联动。
/// 图片曲谱支持 AI/CV 识别，识别后切换到交互视图。
struct TabViewerView: View {
    let tab: TabModel
    @Environment(MetronomeEngine.self) private var metronome
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showMetronomePanel = false
    @State private var currentPage = 0
    @State private var totalPages = 0
    @State private var pdfLoadFailed = false

    // 识别相关。
    @State private var recognitionVM = RecognitionViewModel()
    @State private var loadedImage: UIImage?
    @State private var showRecognitionSheet = false
    @State private var existingRecognition: RecognizedTabModel?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            content
                .background(AppColors.background)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .onAppear { loadExistingRecognition(); loadImage() }
        .confirmationDialog(NSLocalizedString("select_method", comment: ""),
                             isPresented: $showRecognitionSheet,
                             titleVisibility: .visible) {
            Button(NSLocalizedString("method_hybrid", comment: "")) {
                runRecognition(method: .hybrid)
            }
            Button(NSLocalizedString("method_ai", comment: "")) {
                runRecognition(method: .ai)
            }
            Button(NSLocalizedString("method_cv", comment: "")) {
                runRecognition(method: .cv)
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        }
    }

    // MARK: - 执行识别

    private func runRecognition(method: RecognitionMethod) {
        guard let image = loadedImage else { return }
        let config = aiConfig()
        // ai/hybrid 需要配置；cv 不需要。
        if method != .cv && config == nil {
            recognitionVM.setError(NSLocalizedString("ai_not_configured", comment: ""))
            return
        }
        Task {
            await recognitionVM.recognize(image: image, method: method,
                                          aiConfig: config, tabId: tab.id,
                                          modelContext: modelContext)
        }
    }

    private var toolbar: some View {
        HStack {
            Text(tab.title).font(.headline).foregroundStyle(AppColors.textPrimary)
            Spacer()
            // 页码指示（仅 PDF 且未失败时显示）。
            if tab.fileType == .pdf, !pdfLoadFailed, totalPages > 0 {
                Text("\(currentPage)/\(totalPages)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppColors.textMuted)
            }
            // 识别按钮（仅图片类型曲谱）。
            if tab.fileType == .image {
                Button { showRecognitionSheet = true } label: {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(recognitionPhaseDone ? AppColors.cta : AppColors.textSecondary)
                }
            }
            Button {
                showMetronomePanel.toggle()
            } label: {
                Image(systemName: "metronome")
                    .foregroundStyle(metronome.isPlaying ? AppColors.cta : AppColors.textSecondary)
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(AppColors.surface)
    }

    /// 是否已完成识别（用于按钮高亮）。
    private var recognitionPhaseDone: Bool {
        if case .done = recognitionVM.phase { return true }
        return existingRecognition != nil
    }

    /// 识别方法显示名。
    private func methodDisplayName(_ method: RecognitionMethod) -> String {
        switch method {
        case .ai: return "AI"
        case .cv: return "CV"
        case .hybrid: return "Hybrid"
        }
    }

    @ViewBuilder private var content: some View {
        let url = URL(fileURLWithPath: tab.filePath)
        if tab.fileType == .pdf {
            if pdfLoadFailed {
                EmptyStateView(systemImage: "doc.questionmark",
                               title: NSLocalizedString("file_load_failed", comment: ""))
            } else {
                PDFKitView(url: url,
                           onPageChange: { page, total in
                               currentPage = page; totalPages = total
                           },
                           onLoadFailed: { pdfLoadFailed = true })
                    .overlay(alignment: .bottom) {
                        if showMetronomePanel { metronomePanel.padding() }
                    }
            }
        } else {
            // 图片曲谱：识别中/出错/有结果/原图 四种状态。
            switch recognitionVM.phase {
            case .recognizing(let method):
                // 识别中。
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large).tint(AppColors.cta)
                    Text(String(format: NSLocalizedString("recognizing_method", comment: ""),
                                methodDisplayName(method)))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let msg):
                // 识别失败：显示错误详情 + 原图入口。
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36)).foregroundStyle(AppColors.error)
                        Text(NSLocalizedString("recognition_failed", comment: ""))
                            .font(.headline).foregroundStyle(AppColors.textPrimary)
                        Text(msg)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(AppColors.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(AppColors.surfaceElevated, in: RoundedRectangle(cornerRadius: 8))
                        Button(NSLocalizedString("retry", comment: "")) {
                            recognitionVM.reset()
                        }
                        .font(.caption).foregroundStyle(AppColors.cta)
                    }
                    .padding()
                }
            default:
                // 有识别结果 → 交互视图；否则原图。
                if let score = resolvedScore {
                    InteractiveTabView(score: score,
                                       originalImage: loadedImage,
                                       confidence: resolvedConfidence,
                                       recognitionDiagnostics: recognitionVM.lastDiagnostics,
                                       onSaveEdit: { editedScore in
                                           saveEditedScore(editedScore)
                                       })
                } else {
                    ImageViewer(url: url)
                        .overlay(alignment: .bottom) {
                            if showMetronomePanel { metronomePanel.padding() }
                        }
                }
            }
        }
    }

    /// 当前生效的识别结果（优先内存中刚识别的，其次数据库里的）。
    private var resolvedScore: TabScore? {
        if case .done(let score, _, _) = recognitionVM.phase { return score }
        if let existing = existingRecognition,
           let score = try? TabScore.fromJSON(existing.scoreJSON) {
            return score
        }
        return nil
    }

    private var resolvedConfidence: Double {
        if case .done(_, _, let c) = recognitionVM.phase { return c }
        return existingRecognition?.confidence ?? 0
    }

    // MARK: - 加载图片 / 已有识别结果

    private func loadImage() {
        guard loadedImage == nil else { return }
        let url = URL(fileURLWithPath: tab.filePath)
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                DispatchQueue.main.async { loadedImage = img }
            }
        }
    }

    /// 保存用户编辑后的曲谱，更新或创建 RecognizedTabModel。
    private func saveEditedScore(_ score: TabScore) {
        guard let json = try? score.toJSON() else { return }
        let tabIdValue = tab.id
        let pred = #Predicate<RecognizedTabModel> { $0.tabId == tabIdValue }
        let descriptor = FetchDescriptor<RecognizedTabModel>(predicate: pred)
        // 更新已有记录（若无则创建）。
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.scoreJSON = json
            existing.confidence = 1.0   // 用户已确认，置信度设满
        } else {
            let model = RecognizedTabModel(tabId: tab.id, scoreJSON: json,
                                           method: .ai, confidence: 1.0)
            modelContext.insert(model)
            existingRecognition = model
        }
        try? modelContext.save()
        // 同步刷新内存状态，让交互视图立即显示新内容。
        recognitionVM.refresh(score: score, confidence: 1.0)
    }

    private func loadExistingRecognition() {
        let tabIdValue = tab.id
        let pred = #Predicate<RecognizedTabModel> { $0.tabId == tabIdValue }
        let descriptor = FetchDescriptor<RecognizedTabModel>(predicate: pred)
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existingRecognition = existing
            recognitionVM.restore(from: existing)
        }
    }

    /// 取 AI 配置（从 SwiftData + Keychain）。
    private func aiConfig() -> TabRecognitionEngine.AIConfig? {
        let pred = #Predicate<AIConfigModel> { $0.id == "default" }
        let descriptor = FetchDescriptor<AIConfigModel>(predicate: pred)
        guard let config = (try? modelContext.fetch(descriptor))?.first,
              config.isConfigured,
              let key = KeychainStore.load(account: config.keychainAccount),
              !key.isEmpty else {
            return nil
        }
        return TabRecognitionEngine.AIConfig(endpoint: config.apiEndpoint,
                                             apiKey: key,
                                             model: config.modelName)
    }

    private var metronomePanel: some View {
        VStack(spacing: 8) {
            HStack {
                Button { metronome.setBpm(metronome.bpm - 5) } label: {
                    Image(systemName: "minus").frame(width: 30)
                }
                Text("\(metronome.bpm) BPM").monospacedDigit()
                Button { metronome.setBpm(metronome.bpm + 5) } label: {
                    Image(systemName: "plus").frame(width: 30)
                }
                Spacer()
                Button { metronome.togglePlay() } label: {
                    Label(metronome.isPlaying
                          ? NSLocalizedString("pause", comment: "")
                          : NSLocalizedString("start", comment: ""),
                          systemImage: metronome.isPlaying ? "pause.fill" : "play.fill")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.textPrimary)
        }
        .padding()
        .background(AppColors.surfaceElevated, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// PDFKit 封装。监听翻页并暴露页码；文档加载失败时显示占位。
struct PDFKitView: UIViewRepresentable {
    let url: URL
    /// 当前页变化回调（用于显示页码）。
    var onPageChange: ((Int, Int) -> Void)?
    /// 文档加载失败回调。
    var onLoadFailed: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(onPageChange: onPageChange) }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        // 加载文档；失败时通知并返回空 view（由外层覆盖占位）。
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
            context.coordinator.total = doc.pageCount
            context.coordinator.observe(pdfView: pdfView)
        } else {
            onLoadFailed?()
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}

    final class Coordinator: NSObject {
        let onPageChange: ((Int, Int) -> Void)?
        var total = 0
        weak var pdfView: PDFView?
        private var pageObserver: NSObjectProtocol?

        init(onPageChange: ((Int, Int) -> Void)?) { self.onPageChange = onPageChange }

        func observe(pdfView: PDFView) {
            self.pdfView = pdfView
            // 用 PDFView 翻页通知（.page 不是 KVO 可观察属性）。
            pageObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged, object: pdfView, queue: .main
            ) { [weak self] _ in
                self?.reportCurrentPage()
            }
            reportCurrentPage()
        }

        private func reportCurrentPage() {
            guard let pdfView else { return }
            // 用视图中心点定位当前页。
            let center = CGPoint(x: pdfView.bounds.midX, y: pdfView.bounds.midY)
            let page = pdfView.page(for: center, nearest: true)?.pageRef?.pageNumber ?? 1
            onPageChange?(page, total)
        }

        deinit {
            if let pageObserver { NotificationCenter.default.removeObserver(pageObserver) }
        }
    }
}

/// 图片查看器（异步加载，支持捏合缩放）。
struct ImageViewer: View {
    let url: URL
    @State private var scale: CGFloat = 1.0
    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale = max(0.5, min(4.0, $0)) }
                            .onEnded { _ in
                                // 松手时小于 1 回弹到 1（符合 iOS 惯例）。
                                if scale < 1 { withAnimation(.spring()) { scale = 1 } }
                            }
                    )
                    .onTapGesture(count: 2) { withAnimation(.spring()) { scale = scale > 1 ? 1 : 2 } }
            } else if loadFailed {
                EmptyStateView(systemImage: "photo.badge.exclamationmark",
                               title: NSLocalizedString("file_load_failed", comment: ""))
            } else {
                ProgressView()
                    .tint(AppColors.cta)
            }
        }
        .task(id: url) {
            image = nil
            loadFailed = false
            let loaded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return UIImage(data: data)
            }.value
            await MainActor.run {
                if let loaded { image = loaded }
                else { loadFailed = true }
            }
        }
    }
}
