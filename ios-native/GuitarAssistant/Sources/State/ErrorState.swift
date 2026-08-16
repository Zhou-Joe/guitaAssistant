import SwiftUI

/// 全局轻量错误/提示通道。替代散落各处的 `print(...)` 静默失败。
///
/// 用法：在 View 中 `@Environment(ErrorState.self)`，出错时 `errorState.show(...)`；
/// 顶层 View 在 body 内用 `errorAlert(errorState:)` 挂载展示（**不要**在 ViewModifier
/// 里读 `@Environment(ErrorState.self)`——`@Observable` 类型作为 Environment 在
/// modifier 求值期会触发 Observation 追踪导致渲染期崩溃）。
@Observable
final class ErrorState {
    /// 当前待展示的消息（nil 表示无）。
    var message: String?
    /// 是否提供"打开设置"按钮（用于权限类错误）。
    var allowOpenSettings: Bool = false

    func show(_ text: String, allowOpenSettings: Bool = false) {
        message = text
        self.allowOpenSettings = allowOpenSettings
    }

    func dismiss() {
        message = nil
        allowOpenSettings = false
    }
}

/// 错误 alert 视图（非 modifier）。
///
/// **关键**：以子视图形式读取 `errorState.message`，而非 ViewModifier 的
/// `@Environment`——这样 Observation 追踪发生在正常视图更新路径中，安全。
struct ErrorAlertContent: View {
    let errorState: ErrorState

    var body: some View {
        Color.clear
            .alert(
                NSLocalizedString("notice", comment: ""),
                isPresented: Binding(
                    get: { errorState.message != nil },
                    set: { if !$0 { errorState.dismiss() } }
                )
            ) {
                if errorState.allowOpenSettings {
                    Button(NSLocalizedString("open_settings", comment: "")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                        errorState.dismiss()
                    }
                    Button(NSLocalizedString("ok", comment: ""), role: .cancel) { errorState.dismiss() }
                } else {
                    Button(NSLocalizedString("ok", comment: ""), role: .cancel) { errorState.dismiss() }
                }
            } message: {
                Text(errorState.message ?? "")
            }
    }
}

extension View {
    /// 挂载全局错误提示。传入已获取的 errorState（而非在 modifier 内读 environment）。
    func errorAlert(_ errorState: ErrorState) -> some View {
        background(ErrorAlertContent(errorState: errorState))
    }
}
