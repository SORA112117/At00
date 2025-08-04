//
//  DesignSystem.swift
//  At00
//
//  デザインシステム - 統一されたUI要素とカラーパレット
//

import SwiftUI

struct DesignSystem {
    
    // MARK: - 適応的カラー定義
    static let adaptiveShadowColor = Color(.systemGray4).opacity(0.3)
    static let adaptiveProgressBackground = Color(.systemGray5)
    
    // MARK: - カラーパレット
    static let colorPalette: [Color] = [
        .blue, .green, .orange, .purple, .pink, 
        .indigo, .teal, .cyan, .red, .yellow, .mint, .brown
    ]
    
    // MARK: - カード設計
    struct Card: ViewModifier {
        let cornerRadius: CGFloat
        let shadowRadius: CGFloat
        
        init(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 8) {
            self.cornerRadius = cornerRadius
            self.shadowRadius = shadowRadius
        }
        
        func body(content: Content) -> some View {
            content
                .background(Color(.systemBackground))
                .cornerRadius(cornerRadius)
                .shadow(color: DesignSystem.adaptiveShadowColor, radius: shadowRadius, x: 0, y: 4)
        }
    }
    
    // MARK: - インタラクティブボタン
    struct InteractiveButton: ViewModifier {
        let isPressed: Bool
        let isLongPressing: Bool
        
        func body(content: Content) -> some View {
            content
                .scaleEffect(isLongPressing ? 1.01 : (isPressed ? 0.99 : 1.0))
                .shadow(radius: isLongPressing ? 4 : 1, x: 0, y: 1)
                .animation(.easeInOut(duration: 0.15), value: isPressed)
                .animation(.easeInOut(duration: 0.3), value: isLongPressing)
        }
    }
    
    // MARK: - 入力フィールド
    struct InputField: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    // MARK: - プログレスバー
    static func progressBar(
        progress: Double,
        height: CGFloat = 16,
        cornerRadius: CGFloat = 8
    ) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(DesignSystem.adaptiveProgressBackground)
                .frame(height: height)
            
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(LinearGradient(
                    colors: progress >= 1.0 ? [.red, .orange] : 
                           progress >= 0.8 ? [.orange, .yellow] : [.green, .mint],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: max(0, CGFloat(progress) * 200), height: height)
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
    
    // MARK: - セクションヘッダー
    struct SectionHeader: ViewModifier {
        let title: String
        
        func body(content: Content) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                content
            }
        }
    }
    
    // MARK: - カラーセレクター
    static func colorSelector(
        selectedIndex: Binding<Int>,
        columns: Int = 6
    ) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: 8) {
            ForEach(0..<colorPalette.count, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedIndex.wrappedValue = index
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(colorPalette[index])
                            .frame(width: 32, height: 32)
                        
                        if selectedIndex.wrappedValue == index {
                            Circle()
                                .stroke(Color.primary, lineWidth: 2)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - ステータスインジケーター
    static func statusIndicator(
        color: Color,
        size: CGFloat = 12
    ) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
    
    // MARK: - カラーライン
    static func colorLine(
        color: Color,
        width: CGFloat = 4,
        height: CGFloat = 20,
        cornerRadius: CGFloat = 2
    ) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle(
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 8
    ) -> some View {
        modifier(DesignSystem.Card(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
    
    func interactiveButton(
        isPressed: Bool = false,
        isLongPressing: Bool = false
    ) -> some View {
        modifier(DesignSystem.InteractiveButton(isPressed: isPressed, isLongPressing: isLongPressing))
    }
    
    func inputFieldStyle() -> some View {
        modifier(DesignSystem.InputField())
    }
    
    func sectionHeader(_ title: String) -> some View {
        modifier(DesignSystem.SectionHeader(title: title))
    }
    
    func primaryButtonStyle(isDisabled: Bool = false) -> some View {
        modifier(DesignSystem.PrimaryButton(isDisabled: isDisabled))
    }
    
    func secondaryButtonStyle() -> some View {
        modifier(DesignSystem.SecondaryButton())
    }
    
    func destructiveButtonStyle() -> some View {
        modifier(DesignSystem.DestructiveButton())
    }
}

// MARK: - Color Utilities
extension DesignSystem {
    static func getColor(for index: Int) -> Color {
        guard index >= 0 && index < colorPalette.count else { return .blue }
        return colorPalette[index]
    }
    
    static func getColorIndex(for color: Color) -> Int {
        return colorPalette.firstIndex(of: color) ?? 0
    }
    
    // MARK: - 統一ボタンスタイル
    struct PrimaryButton: ViewModifier {
        let isDisabled: Bool
        
        init(isDisabled: Bool = false) {
            self.isDisabled = isDisabled
        }
        
        func body(content: Content) -> some View {
            content
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isDisabled ? .secondary : .primary)
                .disabled(isDisabled)
        }
    }
    
    struct SecondaryButton: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    struct DestructiveButton: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.red)
        }
    }
    
    // MARK: - 統一アラートスタイル
    static func standardAlert(
        title: String,
        message: String? = nil,
        primaryAction: Alert.Button,
        secondaryAction: Alert.Button? = nil
    ) -> Alert {
        if let secondary = secondaryAction {
            return Alert(
                title: Text(title),
                message: message.map { Text($0) },
                primaryButton: primaryAction,
                secondaryButton: secondary
            )
        } else {
            return Alert(
                title: Text(title),
                message: message.map { Text($0) },
                dismissButton: primaryAction
            )
        }
    }
    
    // MARK: - エラーハンドリングUI
    struct ErrorBanner: View {
        let message: String
        let type: ErrorType
        let onDismiss: () -> Void
        
        enum ErrorType {
            case error, warning, info, systemError, dataNotFound
            
            var color: Color {
                switch self {
                case .error, .systemError: return .red
                case .warning: return .orange
                case .info: return .blue
                case .dataNotFound: return .purple
                }
            }
            
            var icon: String {
                switch self {
                case .error, .systemError: return "exclamationmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .info: return "info.circle.fill"
                case .dataNotFound: return "questionmark.circle.fill"
                }
            }
        }
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .foregroundColor(type.color)
                    .font(.system(size: 16, weight: .medium))
                
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.systemGray3))
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(type.color.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: adaptiveShadowColor, radius: 4, x: 0, y: 2)
            .padding(.horizontal)
        }
    }
    
    // MARK: - ローディング状態
    struct LoadingView: View {
        let message: String
        
        var body: some View {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle())
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - 空状態表示
    struct EmptyStateView: View {
        let icon: String
        let title: String
        let message: String
        let actionTitle: String?
        let action: (() -> Void)?
        
        init(
            icon: String,
            title: String,
            message: String,
            actionTitle: String? = nil,
            action: (() -> Void)? = nil
        ) {
            self.icon = icon
            self.title = title
            self.message = message
            self.actionTitle = actionTitle
            self.action = action
        }
        
        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                
                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Array Extension for Safe Access
// Note: iOS 18.5+ provides native safe subscript, so custom implementation is removed