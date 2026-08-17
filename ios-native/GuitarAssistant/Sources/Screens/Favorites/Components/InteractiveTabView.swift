import SwiftUI

/// 交互式曲谱视图：四种交互能力（速查卡/小节播放/导出/叠加）。
struct InteractiveTabView: View {
    /// 当前显示的曲谱（可被编辑更新）。
    @State private var currentScore: TabScore
    let originalImage: UIImage?
    /// 置信度（仅在未编辑时显示；编辑后标记为"已编辑"）。
    var confidence: Double
    /// 识别诊断信息（CV 为空时展示，便于排查）。
    var recognitionDiagnostics: String = ""
    /// 编辑保存回调（传入编辑后的 score，由调用方写回数据库）。
    var onSaveEdit: ((TabScore) -> Void)?

    /// 是否已被用户编辑过。
    @State private var hasBeenEdited = false

    init(score: TabScore, originalImage: UIImage?, confidence: Double,
         recognitionDiagnostics: String = "",
         onSaveEdit: ((TabScore) -> Void)? = nil) {
        _currentScore = State(initialValue: score)
        self.originalImage = originalImage
        self.confidence = confidence
        self.recognitionDiagnostics = recognitionDiagnostics
        self.onSaveEdit = onSaveEdit
    }

    enum Mode: String, CaseIterable {
        case measures    // 小节序列播放
        case chords      // 和弦速查卡
        case annotate    // 原图叠加标注
    }

    /// 小节视图的子模式：卡片 vs 标准六线谱。
    enum MeasureSubMode: String, CaseIterable {
        case cards   // 小节卡片（横向滚动）
        case staff   // 标准六线谱样式
    }

    @State private var mode: Mode = .measures
    @State private var measureSubMode: MeasureSubMode = .cards
    /// 六线谱视图每行显示的小节数。
    @State private var measuresPerRow: Int = 4
    @State private var showShareSheet = false
    @State private var showEditor = false
    @State private var shareItems: [Any]?
    @State private var asciiTab = ""
    @Environment(MetronomeEngine.self) private var metronome

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(AppColors.surfaceElevated)

            switch mode {
            case .measures: measurePlayback
            case .chords: chordLookup
            case .annotate: annotateView
            }
        }
        .onAppear { asciiTab = currentScore.toAsciiTab() }
        .sheet(item: Binding(
            get: { shareItems.map { ShareItemWrapper(items: $0) } },
            set: { if $0 == nil { shareItems = nil } }
        )) { wrapper in
            ShareSheet(items: wrapper.items)
        }
        .sheet(isPresented: $showEditor) {
            TabEditorView(score: currentScore,
                          onSave: { edited in
                              currentScore = edited
                              hasBeenEdited = true
                              asciiTab = edited.toAsciiTab()
                              onSaveEdit?(edited)
                          },
                          onCancel: {})
        }
    }

    // MARK: - 顶部

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                if hasBeenEdited {
                    Label(NSLocalizedString("edited", comment: ""), systemImage: "checkmark.seal.fill")
                        .font(.caption).foregroundStyle(AppColors.cta)
                } else {
                    Text(String(format: NSLocalizedString("recognition_confidence", comment: ""),
                                Int(confidence * 100)))
                        .font(.caption).foregroundStyle(AppColors.textMuted)
                }
                Spacer()
                // 编辑按钮。
                Button { showEditor = true } label: {
                    Label(NSLocalizedString("edit", comment: ""), systemImage: "pencil")
                        .font(.caption)
                }
                // 分享菜单：图片 / 文本。
                Menu {
                    Button {
                        shareStaffImage()
                    } label: {
                        Label(NSLocalizedString("share_image", comment: ""), systemImage: "photo")
                    }
                    Button {
                        shareTextTab()
                    } label: {
                        Label(NSLocalizedString("share_text_tab", comment: ""), systemImage: "doc.text")
                    }
                } label: {
                    Label(NSLocalizedString("share", comment: ""), systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
            }
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Text(NSLocalizedString("mode_\(m.rawValue)", comment: "")).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - 模式1：小节序列播放

    private var measurePlayback: some View {
        VStack(spacing: 12) {
            if currentScore.measures.isEmpty {
                // 显示诊断信息（便于排查 CV 为何识别为空）。
                VStack(spacing: 8) {
                    Image(systemName: "music.note").font(.system(size: 40))
                        .foregroundStyle(AppColors.textMuted)
                    Text(NSLocalizedString("no_measures", comment: ""))
                        .foregroundStyle(AppColors.textSecondary)
                    if !recognitionDiagnostics.isEmpty {
                        ScrollView {
                            Text(recognitionDiagnostics)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(AppColors.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(AppColors.surfaceElevated, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .frame(maxHeight: 200)
                        .padding(.horizontal)
                    }
                }
            } else {
                // 子视图切换：卡片 / 六线谱。
                measureSubModePicker

                switch measureSubMode {
                case .cards:
                    cardsView
                case .staff:
                    StaffTabView(score: currentScore, measuresPerRow: measuresPerRow)
                    // 每行小节数调节。
                    measuresPerRowControl
                }
                playbackControls
            }
        }
    }

    /// 子模式切换器。
    private var measureSubModePicker: some View {
        HStack {
            Picker("", selection: $measureSubMode) {
                ForEach(MeasureSubMode.allCases, id: \.self) { sub in
                    Text(NSLocalizedString("sub_\(sub.rawValue)", comment: "")).tag(sub)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal)
    }

    /// 卡片视图（原有横向滚动）。
    private var cardsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                        ForEach(Array(currentScore.measures.enumerated()), id: \.element.id) { idx, measure in
                    measureCard(idx: idx, measure: measure)
                }
            }
            .padding()
        }
    }

    /// 六线谱视图的每行小节数调节。
    private var measuresPerRowControl: some View {
        HStack(spacing: 12) {
            Text(NSLocalizedString("measures_per_row", comment: ""))
                .font(.caption).foregroundStyle(AppColors.textSecondary)
            Stepper("\(measuresPerRow)", value: $measuresPerRow, in: 1...8)
                .tint(AppColors.cta)
                .font(.caption)
            Spacer()
        }
        .padding(.horizontal)
    }

    private func measureCard(idx: Int, measure: TabMeasure) -> some View {
        let isCurrent = metronome.isPlaying && currentMeasureIndex == idx
        return VStack(alignment: .leading, spacing: 6) {
            // 和弦名。
            if !measure.chords.isEmpty {
                Text(measure.chords.joined(separator: " "))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.warning)
            }
            // 六线谱（每弦一行）。
            VStack(alignment: .leading, spacing: 2) {
                ForEach(0..<6, id: \.self) { s in
                    HStack(spacing: 4) {
                        Text(stringName(s))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(AppColors.textMuted)
                        Text(measure.strings[s].map { note -> String in
                            let f = note.fret >= 10 ? "\(note.fret)" : "\(note.fret)"
                            return note.technique == .normal ? f : "\(f)\(note.technique.symbol)"
                        }.joined(separator: "-"))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
            Text("\(idx + 1)").font(.system(size: 9)).foregroundStyle(AppColors.textMuted)
        }
        .padding(10)
        .background(isCurrent ? AppColors.secondary : AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrent ? AppColors.cta : .clear, lineWidth: 2)
        )
    }

    private func stringName(_ idx: Int) -> String {
        ["e", "B", "G", "D", "A", "E"][idx]
    }

    private var playbackControls: some View {
        HStack(spacing: 16) {
            Button { metronome.togglePlay() } label: {
                Image(systemName: metronome.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2).foregroundStyle(AppColors.cta)
            }
            Text("\(metronome.bpm) BPM").font(.caption.monospacedDigit())
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal)
    }

    /// 当前应该高亮的小节索引。
    /// 与节拍器严格对齐:每个节拍器小节(强拍起)推进一张卡片——
    /// 累计已响拍数 ÷ 每小节拍数 = 当前小节序号。
    private var currentMeasureIndex: Int {
        guard !currentScore.measures.isEmpty else { return 0 }
        let beatsPerMeasure = max(1, metronome.beatsPerMeasure)
        return (metronome.playedBeatTotal / beatsPerMeasure) % currentScore.measures.count
    }

    // MARK: - 模式2：和弦速查卡

    private var chordLookup: some View {
        ScrollView {
            // 收集曲谱中出现的所有和弦（去重，保持顺序）。
            let allChords = Array(Set(currentScore.measures.flatMap { $0.chords })).sorted()
            if allChords.isEmpty {
                EmptyStateView(systemImage: "music.quarternote.3",
                               title: NSLocalizedString("no_chords", comment: ""))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 16) {
                    ForEach(allChords, id: \.self) { name in
                        ChordCardView(chordName: name)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - 模式3：原图叠加标注

    private var annotateView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let originalImage {
                    // 原图 + 半透明绿色弦线叠加（示意标注）。
                    ZStack {
                        Image(uiImage: originalImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        // 叠加标注层（简化：显示识别置信度标签）。
                        VStack {
                            HStack {
                                Label(String(format: "%d%%", Int(confidence * 100)),
                                      systemImage: "checkmark.seal.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(AppColors.cta, in: Capsule())
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                    .padding()
                } else {
                    EmptyStateView(systemImage: "photo",
                                   title: NSLocalizedString("no_original_image", comment: ""))
                }

                // 下方显示识别的文本 TAB。
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("text_tab", comment: ""))
                        .font(.headline).foregroundStyle(AppColors.textPrimary)
                    Text(asciiTab)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding()
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - 分享

    /// 分享六线谱图片：用 ImageRenderer 把 StaffTabView 渲染成 UIImage。
    private func shareStaffImage() {
        let staffView = StaffTabView(score: currentScore, measuresPerRow: measuresPerRow)
            .frame(width: 1000)
            .background(AppColors.background)
        let renderer = ImageRenderer(content: staffView)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else {
            return
        }
        let text = NSLocalizedString("share_tab_text", comment: "")
        shareItems = [text, image]
    }

    /// 分享文本 TAB。
    private func shareTextTab() {
        let text = NSLocalizedString("share_tab_text", comment: "")
        shareItems = [text, asciiTab]
    }
}

/// 分享内容包装器（供 .sheet(item:) 使用）。
private struct ShareItemWrapper: Identifiable {
    let id = UUID()
    let items: [Any]
}

/// 系统分享 sheet 包装。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
