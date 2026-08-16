import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 曲谱收藏主界面。对应 Flutter `favorites_screen.dart`。
/// 修复：导入时将文件拷贝进 `Documents/tabs/`（Flutter 版只存临时路径，沙盒失效）。
struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ErrorState.self) private var errorState
    @Query(sort: \TabModel.updatedAt, order: .reverse) private var tabs: [TabModel]

    @State private var searchText = ""
    @State private var showImporter = false
    @State private var renamingTab: TabModel?

    private var filteredTabs: [TabModel] {
        guard !searchText.isEmpty else { return tabs }
        return tabs.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if filteredTabs.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredTabs) { tab in
                        NavigationLink {
                            TabViewerView(tab: tab)
                        } label: {
                            tabRow(tab)
                        }
                        .listRowBackground(AppColors.surface)
                        .listRowSeparatorTint(AppColors.surfaceElevated)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(NSLocalizedString("favorites", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: NSLocalizedString("search", comment: ""))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showImporter = true } label: { Image(systemName: "plus") }
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.pdf, .jpeg, .png, .image],
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .sheet(item: $renamingTab) { tab in
            RenameSheet(tab: tab)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "music.note.list",
            title: NSLocalizedString("no_tabs", comment: ""),
            message: NSLocalizedString("no_tabs_hint", comment: ""),
            actionTitle: NSLocalizedString("import_tab", comment: "")
        ) {
            showImporter = true
        }
    }

    private func tabRow(_ tab: TabModel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tab.fileType == .pdf ? "doc.richtext" : "photo")
                .font(.title2).foregroundStyle(AppColors.accentFavorites)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(tab.title).font(.body.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)
                Text(tab.fileType == .pdf ? "PDF" : NSLocalizedString("image", comment: ""))
                    .font(.caption).foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button { renamingTab = tab } label: {
                Label(NSLocalizedString("rename", comment: ""), systemImage: "pencil")
            }
            .tint(AppColors.secondary)
        }
    }

    // MARK: - 导入

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            handleSecurityScoped(url: url)
        case .failure:
            errorState.show(NSLocalizedString("import_failed", comment: ""))
        }
    }

    private func handleSecurityScoped(url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let fileType: TabFileType = url.pathExtension.lowercased() == "pdf" ? .pdf : .image
        do {
            let destURL = try StorageManager.shared.copy(into: .tabs, from: url)
            let baseName = url.deletingPathExtension().lastPathComponent
            let tab = TabModel(title: baseName, filePath: destURL.path, fileType: fileType)
            modelContext.insert(tab)
            try modelContext.save()
        } catch {
            errorState.show(NSLocalizedString("import_failed", comment: ""))
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let tab = filteredTabs[index]
            // 先删数据库记录；删文件失败时清理残留。
            modelContext.delete(tab)
            do {
                try FileManager.default.removeItem(atPath: tab.filePath)
            } catch {
                // 文件可能已被外部删除，忽略。
            }
        }
        do {
            try modelContext.save()
        } catch {
            errorState.show(NSLocalizedString("delete_failed", comment: ""))
        }
    }
}

/// 重命名弹窗。
struct RenameSheet: View {
    let tab: TabModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField(NSLocalizedString("title", comment: ""), text: $name)
            }
            .navigationTitle(NSLocalizedString("rename", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("save", comment: "")) {
                        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                            tab.title = name
                            tab.updatedAt = .now
                            try? modelContext.save()
                        }
                        dismiss()
                    }
                }
            }
        }
        .onAppear { name = tab.title }
    }
}
