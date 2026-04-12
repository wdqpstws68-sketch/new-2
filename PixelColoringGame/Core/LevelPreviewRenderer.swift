import UIKit

enum LevelPreviewStyle: Hashable {
    case solved
    case silhouette

    var cellPixelSize: CGFloat {
        switch self {
        case .solved:
            return 18
        case .silhouette:
            return 10
        }
    }

    var backgroundColor: UIColor? {
        switch self {
        case .solved:
            return UIColor(hex: "F7F1FF")
        case .silhouette:
            return nil
        }
    }
}

enum LevelPreviewRenderer {
    @MainActor
    static func renderSolved(level: LevelManifest, side _: CGFloat) -> UIImage? {
        render(level: level, style: .solved)
    }

    @MainActor
    static func renderSilhouette(level: LevelManifest, side _: CGFloat) -> UIImage? {
        render(level: level, style: .silhouette)
    }

    @MainActor
    private static func render(level: LevelManifest, style: LevelPreviewStyle) -> UIImage? {
        let metrics = LevelPreviewRasterMetrics(level: level, style: style)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = style.backgroundColor != nil

        let renderer = UIGraphicsImageRenderer(size: metrics.canvasSize, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext

            if let backgroundColor = style.backgroundColor {
                backgroundColor.setFill()
                cgContext.fill(CGRect(origin: .zero, size: metrics.canvasSize))
            }

            for (index, colorIndex) in level.cells.enumerated() where colorIndex >= 0 {
                fillColor(for: colorIndex, in: level, style: style).setFill()
                cgContext.fill(metrics.rect(forCellAt: index))
            }
        }
    }

    private static func fillColor(for colorIndex: Int, in level: LevelManifest, style: LevelPreviewStyle) -> UIColor {
        switch style {
        case .solved:
            guard let paletteEntry = level.paletteEntriesByIndex[colorIndex] else { return .black }
            return UIColor(hex: paletteEntry.hex)
        case .silhouette:
            return .black
        }
    }
}

private struct LevelPreviewRasterMetrics {
    let level: LevelManifest
    let cellPixelSize: CGFloat
    let padding: CGFloat

    init(level: LevelManifest, style: LevelPreviewStyle) {
        self.level = level
        self.cellPixelSize = style.cellPixelSize
        self.padding = style.cellPixelSize
    }

    var canvasSize: CGSize {
        CGSize(
            width: CGFloat(level.boardWidth) * cellPixelSize + padding * 2,
            height: CGFloat(level.boardHeight) * cellPixelSize + padding * 2
        )
    }

    func rect(forCellAt index: Int) -> CGRect {
        let column = index % level.boardWidth
        let row = index / level.boardWidth

        return CGRect(
            x: padding + CGFloat(column) * cellPixelSize,
            y: padding + CGFloat(row) * cellPixelSize,
            width: cellPixelSize,
            height: cellPixelSize
        )
    }
}
