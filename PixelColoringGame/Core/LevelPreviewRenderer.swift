import SwiftUI
import UIKit

enum LevelPreviewStyle: Hashable {
    case solved
    case silhouette
}

enum LevelPreviewRenderer {
    @MainActor
    static func renderSolved(level: LevelManifest, side: CGFloat) -> UIImage? {
        render(level: level, side: side, style: .solved)
    }

    @MainActor
    static func renderSilhouette(level: LevelManifest, side: CGFloat) -> UIImage? {
        render(level: level, side: side, style: .silhouette)
    }

    @MainActor
    private static func render(level: LevelManifest, side: CGFloat, style: LevelPreviewStyle) -> UIImage? {
        let view = LevelPreview(level: level, style: style)
            .frame(width: side, height: side)
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

private struct LevelPreview: View {
    let level: LevelManifest
    let style: LevelPreviewStyle

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
                    if let fill = fillColor(for: colorIndex) {
                        RoundedRectangle(cornerRadius: cellSize * 0.32, style: .continuous)
                            .fill(fill)
                            .overlay(alignment: .topLeading) {
                                if style == .solved {
                                    Circle()
                                        .fill(Color.white.opacity(0.34))
                                        .frame(width: cellSize * 0.28, height: cellSize * 0.28)
                                        .offset(x: cellSize * 0.14, y: cellSize * 0.14)
                                }
                            }
                    } else {
                        Color.clear
                    }
                }
            }
            .frame(width: side, height: side)
        }
    }

    private func fillColor(for colorIndex: Int) -> Color? {
        guard colorIndex >= 0 else { return nil }

        switch style {
        case .solved:
            return level.paletteEntriesByIndex[colorIndex]?.color
        case .silhouette:
            return Color.black
        }
    }
}
