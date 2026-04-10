import SwiftUI
import UIKit

enum LevelPreviewRenderer {
    @MainActor
    static func renderSolved(level: LevelManifest, side: CGFloat) -> UIImage? {
        let view = SolvedLevelPreview(level: level)
            .frame(width: side, height: side)

        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

private struct SolvedLevelPreview: View {
    let level: LevelManifest

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let spacing = max(side * 0.003, 1)
            let cellSize = (side - spacing * CGFloat(level.boardWidth - 1)) / CGFloat(level.boardWidth)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: level.boardWidth),
                spacing: spacing
            ) {
                ForEach(Array(level.cells.enumerated()), id: \.offset) { index, colorIndex in
                    if colorIndex >= 0, let entry = level.paletteEntriesByIndex[colorIndex] {
                        RoundedRectangle(cornerRadius: cellSize * 0.32, style: .continuous)
                            .fill(entry.color)
                            .overlay(alignment: .topLeading) {
                                Circle()
                                    .fill(Color.white.opacity(0.34))
                                    .frame(width: cellSize * 0.28, height: cellSize * 0.28)
                                    .offset(x: cellSize * 0.14, y: cellSize * 0.14)
                            }
                    } else {
                        Color.clear
                    }
                }
            }
            .frame(width: side, height: side)
        }
    }
}
