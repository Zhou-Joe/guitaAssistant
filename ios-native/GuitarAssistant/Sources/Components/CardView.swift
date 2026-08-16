import SwiftUI

/// 通用卡片容器。对应 Flutter 版 `widgets/common/card_widget.dart`。
struct CardView<Content: View>: View {
    var backgroundColor: Color = AppColors.surface
    var cornerRadius: CGFloat = AppTheme.cardCornerRadius
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// 主操作按钮。对应 Flutter 版 `widgets/common/primary_button.dart`。
/// 支持 disabled 态与 loading 态（显示转圈、禁用点击）。
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var color: Color = AppColors.cta
    var fullWidth: Bool = true
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().controlSize(.small).tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(isEnabled ? color : color.opacity(0.4))
            .clipShape(Capsule())
        }
        .disabled(!isEnabled || isLoading)
    }
}
