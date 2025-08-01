//
//  ColorBlockGrid.swift
//  At00
//
//  カラーブロックグリッド表示コンポーネント
//

import SwiftUI

struct ColorBlockGrid: View {
    let absenceCount: Int
    let maxAbsences: Int
    
    private let rows = 2
    private let columns = 5
    private let blockSize: CGFloat = 6
    private let spacing: CGFloat = 2
    
    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        blockView(at: row * columns + column)
                    }
                }
            }
        }
    }
    
    private func blockView(at index: Int) -> some View {
        Rectangle()
            .fill(blockColor(at: index))
            .frame(width: blockSize, height: blockSize)
            .cornerRadius(1)
    }
    
    private func blockColor(at index: Int) -> Color {
        let filledBlocks = min(absenceCount, rows * columns)
        let warningThreshold = (maxAbsences * 2) / 3
        
        if index < filledBlocks {
            if absenceCount >= maxAbsences {
                return .red
            } else if absenceCount >= warningThreshold {
                return .orange
            } else {
                return .green
            }
        } else {
            return Color.gray.opacity(0.2)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // 安全状態
        ColorBlockGrid(absenceCount: 2, maxAbsences: 5)
        
        // 注意状態
        ColorBlockGrid(absenceCount: 4, maxAbsences: 5)
        
        // 危険状態
        ColorBlockGrid(absenceCount: 5, maxAbsences: 5)
        
        // 上限超過
        ColorBlockGrid(absenceCount: 7, maxAbsences: 5)
    }
    .padding()
}