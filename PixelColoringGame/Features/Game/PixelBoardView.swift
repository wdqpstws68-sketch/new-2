import SwiftUI

struct PixelBoardView: View {
    let session: GameSessionStore
    let onTapCell: (Int) -> Void

    private let spacing: CGFloat = 2.2

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cellSize = max(
                8,
                (side - spacing * CGFloat(session.level.boardWidth - 1)) / CGFloat(session.level.boardWidth)
            )

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: session.level.boardWidth),
                spacing: spacing
            ) {
                ForEach(Array(session.level.cells.enumerated()), id: \.offset) { index, _ in
                    PixelBoardCellView(
                        session: session,
                        cellIndex: index,
                        cellSize: cellSize
                    )
                    .onTapGesture {
                        onTapCell(index)
                    }
                }
            }
            .frame(width: side, height: side)
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(AppTheme.boardBackground)
                    .shadow(color: AppTheme.shadowColor, radius: 20, x: 0, y: 16)
            )
        }
    }
}

private struct PixelBoardCellView: View {
    let session: GameSessionStore
    let cellIndex: Int
    let cellSize: CGFloat

    var body: some View {
        if let colorIndex = session.level.colorIndex(at: cellIndex),
           let paletteEntry = session.level.paletteEntriesByIndex[colorIndex] {
            let isFilled = session.filledCells.contains(cellIndex)
            let isSelected = colorIndex == session.selectedColorIndex
            let isIncorrect = session.highlightedIncorrectCell == cellIndex

            RoundedRectangle(cornerRadius: cellSize * 0.28, style: .continuous)
                .fill(
                    isFilled
                        ? paletteEntry.color
                        : isSelected
                            ? paletteEntry.color.opacity(0.18)
                            : Color.white.opacity(0.92)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cellSize * 0.28, style: .continuous)
                        .strokeBorder(
                            isIncorrect
                                ? AppTheme.accentOrange
                                : isSelected && !isFilled ? paletteEntry.color : Color.black.opacity(0.05),
                            lineWidth: isIncorrect ? 2.4 : isSelected && !isFilled ? 2.6 : 0.6
                        )
                }
                .overlay {
                    if isSelected && !isFilled {
                        RoundedRectangle(cornerRadius: cellSize * 0.28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.1)
                            .padding(max(0.6, cellSize * 0.08))
                    }
                }
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(Color.white.opacity(isFilled ? 0.36 : 0.2))
                        .frame(width: cellSize * 0.28, height: cellSize * 0.28)
                        .offset(x: cellSize * 0.14, y: cellSize * 0.14)
                }
                .overlay {
                    if isFilled {
                        RoundedRectangle(cornerRadius: cellSize * 0.28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.24), .clear, Color.black.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        Text("\(colorIndex + 1)")
                            .font(.system(size: max(6, cellSize * 0.46), weight: .black, design: .rounded))
                            .foregroundStyle(
                                isSelected
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary.opacity(0.7)
                            )
                            .padding(cellSize * 0.08)
                            .background(
                                RoundedRectangle(cornerRadius: cellSize * 0.18, style: .continuous)
                                    .fill(Color.white.opacity(isSelected ? 0.86 : 0.68))
                            )
                    }
                }
                .frame(width: cellSize, height: cellSize)
        } else {
            Color.clear
                .frame(width: cellSize, height: cellSize)
        }
    }
}
