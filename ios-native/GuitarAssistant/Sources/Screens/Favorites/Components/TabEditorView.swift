import SwiftUI
import SwiftData

/// 曲谱编辑器：允许用户修正识别结果（和弦名、品位数字、增删小节），保存回数据库。
struct TabEditorView: View {
    /// 可编辑的曲谱副本（编辑中不直接影响原数据）。
    @State private var editingScore: TabScore
    /// 保存回调（传入编辑后的 score，由调用方写回数据库）。
    let onSave: (TabScore) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(score: TabScore, onSave: @escaping (TabScore) -> Void, onCancel: @escaping () -> Void) {
        _editingScore = State(initialValue: score)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // BPM 编辑。
                    bpmRow
                    // 小节列表（用稳定 id，避免删除错位）。
                    ForEach(editingScore.measures) { measure in
                        if let idx = editingScore.measures.firstIndex(where: { $0.id == measure.id }) {
                            measureCard(measureIndex: idx)
                        }
                    }
                    // 添加小节。
                    addMeasureButton
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle(NSLocalizedString("edit_tab", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        onCancel(); dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("save", comment: "")) {
                        onSave(editingScore); dismiss()
                    }
                }
            }
        }
    }

    // MARK: - BPM

    private var bpmRow: some View {
        HStack {
            Text("BPM").font(.headline).foregroundStyle(AppColors.textPrimary)
            Spacer()
            Stepper("\(editingScore.bpm ?? 120)", value: Binding(
                get: { editingScore.bpm ?? 120 },
                set: { editingScore.bpm = $0 }
            ), in: 30...250)
            .tint(AppColors.cta)
        }
        .padding()
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 小节卡片

    private func measureCard(measureIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 小节标题 + 删除按钮。
            HStack {
                Text(String(format: NSLocalizedString("measure_n", comment: ""), measureIndex + 1))
                    .font(.headline).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Button(role: .destructive) {
                    if editingScore.measures.count > 1 {
                        editingScore.measures.remove(at: measureIndex)
                    }
                } label: {
                    Image(systemName: "trash").font(.caption)
                }
            }

            // 和弦名编辑。
            chordEditor(measureIndex: measureIndex)

            // 六线谱品位编辑（6 行）。
            VStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { stringIdx in
                    fretRowEditor(measureIndex: measureIndex, stringIdx: stringIdx)
                }
            }
        }
        .padding()
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 和弦编辑

    private func chordEditor(measureIndex: Int) -> some View {
        HStack {
            Text(NSLocalizedString("chords", comment: ""))
                .font(.caption).foregroundStyle(AppColors.textSecondary)
            TextField("C Am F G", text: Binding(
                get: { editingScore.measures[measureIndex].chords.joined(separator: " ") },
                set: { newValue in
                    editingScore.measures[measureIndex].chords = newValue
                        .split(separator: " ")
                        .map { String($0).trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
            ))
            .textInputAutocapitalization(.never)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppColors.warning)
        }
    }

    // MARK: - 品位行编辑

    private func fretRowEditor(measureIndex: Int, stringIdx: Int) -> some View {
        let stringName = ["e", "B", "G", "D", "A", "E"][stringIdx]
        return HStack(spacing: 8) {
            Text(stringName)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppColors.textMuted)
                .frame(width: 14)

            // 该弦的品位序列：显示为可编辑的 chip 序列。
            let notes = editingScore.measures[measureIndex].strings[stringIdx]
            ForEach(Array(notes.enumerated()), id: \.offset) { noteIdx, note in
                // 点击数字弹出修改。
                FretChip(fret: note.fret) { newFret in
                    if let newFret {
                        editingScore.measures[measureIndex].strings[stringIdx][noteIdx].fret = newFret
                    } else {
                        editingScore.measures[measureIndex].strings[stringIdx].remove(at: noteIdx)
                    }
                }
            }
            // 添加音符按钮。
            Button {
                editingScore.measures[measureIndex].strings[stringIdx].append(FretNote(fret: 0))
            } label: {
                Image(systemName: "plus.circle").font(.caption)
                    .foregroundStyle(AppColors.cta)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - 添加小节

    private var addMeasureButton: some View {
        Button {
            editingScore.measures.append(TabMeasure())
        } label: {
            Label(NSLocalizedString("add_measure", comment: ""), systemImage: "plus.circle.fill")
                .font(.headline)
                .foregroundStyle(AppColors.cta)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// 品位数字 chip：点击弹出网格选择器（0-24）修改或删除。
struct FretChip: View {
    let fret: Int
    let onChange: (Int?) -> Void   // nil = 删除

    @State private var showEditor = false

    var body: some View {
        Button {
            showEditor = true
        } label: {
            Text("\(fret)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(fret == 0 ? AppColors.cta : AppColors.textPrimary)
                .frame(width: 28, height: 24)
                .background(AppColors.surfaceElevated, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEditor) {
            FretPickerSheet(currentFret: fret) { newFret in
                onChange(newFret)
                showEditor = false
            }
            .presentationDetents([.medium])
        }
    }
}

/// 品位选择面板：0-24 网格 + 删除按钮。
struct FretPickerSheet: View {
    let currentFret: Int
    let onSelect: (Int?) -> Void   // nil = 删除

    private let columns = Array(repeating: GridItem(.flexible()), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0...24, id: \.self) { fret in
                        Button {
                            onSelect(fret)
                        } label: {
                            Text("\(fret)")
                                .font(.system(.title3, design: .monospaced).weight(.bold))
                                .foregroundStyle(fret == currentFret ? .white : AppColors.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    fret == currentFret ? AppColors.cta : AppColors.surfaceElevated,
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()

                // 删除按钮。
                Button(role: .destructive) {
                    onSelect(nil)
                } label: {
                    Label(NSLocalizedString("delete_note", comment: ""), systemImage: "trash")
                        .frame(maxWidth: .infinity).padding()
                }
                .padding(.horizontal)
            }
            .background(AppColors.background)
            .navigationTitle(NSLocalizedString("select_fret", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        onSelect(currentFret)   // 取消=不变
                    }
                }
            }
        }
    }
}
