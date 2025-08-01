//
//  DesignSystem.swift
//  At00
//
//  デザインシステム - 統一されたUI要素とカラーパレット
//

import SwiftUI

struct DesignSystem {
    
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
                .shadow(color: .black.opacity(0.05), radius: shadowRadius, x: 0, y: 4)
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
                .fill(Color.gray.opacity(0.2))
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
}

// MARK: - Array Extension for Safe Access
// Note: iOS 18.5+ provides native safe subscript, so custom implementation is removed