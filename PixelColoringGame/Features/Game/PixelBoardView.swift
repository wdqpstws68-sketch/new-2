import SwiftUI
import UIKit

/// Pure geometry for the zoomable board — kept free of SwiftUI/UIKit so it can
/// be unit tested. The board content lives in a `side × side` square; `scale`
/// and `offset` map a content point `p` to a screen point `offset + scale * p`
/// (anchored at the content's top-left, relative to the `area` it sits in).
enum BoardTransform {
    /// Keeps the scaled content covering `area`, or centres it when it is
    /// smaller than `area` on an axis.
    static func clampOffset(_ candidate: CGSize, scale: CGFloat, area: CGSize, side: CGFloat) -> CGSize {
        let scaled = side * scale
        func axis(_ value: CGFloat, _ dimension: CGFloat) -> CGFloat {
            if scaled <= dimension { return (dimension - scaled) / 2 }
            return min(max(value, dimension - scaled), 0)
        }
        return CGSize(
            width: axis(candidate.width, area.width),
            height: axis(candidate.height, area.height)
        )
    }

    /// Resolves a two-finger gesture into a new (scale, offset). `factor` is the
    /// current pinch ratio (currentDistance / startDistance) and the centroids
    /// drive both the zoom focal point and panning.
    static func navigated(
        startScale: CGFloat,
        startOffset: CGSize,
        startCentroid: CGPoint,
        factor: CGFloat,
        centroid: CGPoint,
        minScale: CGFloat,
        maxScale: CGFloat,
        area: CGSize,
        side: CGFloat
    ) -> (scale: CGFloat, offset: CGSize) {
        guard startScale > 0 else {
            return (minScale, clampOffset(.zero, scale: minScale, area: area, side: side))
        }
        let newScale = min(max(startScale * factor, minScale), maxScale)
        let anchorX = (startCentroid.x - startOffset.width) / startScale
        let anchorY = (startCentroid.y - startOffset.height) / startScale
        let raw = CGSize(
            width: centroid.x - newScale * anchorX,
            height: centroid.y - newScale * anchorY
        )
        return (newScale, clampOffset(raw, scale: newScale, area: area, side: side))
    }

    /// Maps a point in `area`/screen space back to a board cell index.
    static func cellIndex(
        at location: CGPoint,
        scale: CGFloat,
        offset: CGSize,
        pitch: CGFloat,
        width: Int,
        height: Int
    ) -> Int? {
        guard scale > 0, pitch > 0 else { return nil }
        let x = (location.x - offset.width) / scale
        let y = (location.y - offset.height) / scale
        let column = Int((x / pitch).rounded(.down))
        let row = Int((y / pitch).rounded(.down))
        guard column >= 0, column < width, row >= 0, row < height else { return nil }
        return row * width + column
    }
}

/// The interactive pixel board.
///
/// Interaction model (v1.1):
/// - **One finger**: paint. Tapping fills a single cell; dragging sweeps a
///   continuous stroke that fills every matching cell along the path.
/// - **Two fingers**: pinch to zoom and drag to scroll/pan the artwork.
///
/// The grid is rendered as ordinary SwiftUI (so it always draws) and is scaled /
/// offset by gesture state. A transparent UIKit overlay only *captures* the
/// touches — it draws nothing — and tracks touch count directly (one finger
/// paints, two fingers navigate) so the two never fight in a gesture arena.
struct PixelBoardView: View {
    @Environment(AppLocalization.self) private var localization

    let session: GameSessionStore
    let onPaintBegan: (Int?) -> Void
    let onPaintMoved: (Int) -> Void
    let onPaintEnded: () -> Void
    let onPaintCancelled: () -> Void
    let onAccessibilityFill: (Int) -> Void

    private let baseCell: CGFloat = 40
    private let gridSpacing: CGFloat = 2.4
    private let innerInset: CGFloat = 14
    private let maxZoomFactor: CGFloat = 4

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var didInitTransform = false
    @State private var navStartScale: CGFloat = 1
    @State private var navStartOffset: CGSize = .zero

    @AppStorage("board.coach.seen.v11") private var coachSeen = false
    @State private var showCoach = false
    @State private var coachDismissTask: Task<Void, Never>?

    private var contentSide: CGFloat {
        let count = CGFloat(session.level.boardWidth)
        return count * baseCell + max(0, count - 1) * gridSpacing
    }

    var body: some View {
        GeometryReader { proxy in
            let outer = proxy.size
            let inner = CGSize(
                width: max(1, outer.width - innerInset * 2),
                height: max(1, outer.height - innerInset * 2)
            )
            let side = contentSide
            let fit = min(inner.width, inner.height) / side
            let maxScale = max(fit * maxZoomFactor, fit)
            let appliedScale = didInitTransform ? min(max(scale, fit), maxScale) : fit
            let appliedOffset = didInitTransform
                ? clampOffset(offset, scale: appliedScale, area: inner, side: side)
                : clampOffset(.zero, scale: fit, area: inner, side: side)

            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(AppTheme.boardBackground)
                    .shadow(color: AppTheme.shadowColor, radius: 20, x: 0, y: 16)

                ZStack {
                    PixelGrid(
                        session: session,
                        cellSize: baseCell,
                        spacing: gridSpacing,
                        onFill: onAccessibilityFill
                    )
                    .environment(localization)
                    .frame(width: side, height: side)
                    .scaleEffect(appliedScale, anchor: .topLeading)
                    .offset(appliedOffset)
                    .frame(width: inner.width, height: inner.height, alignment: .topLeading)

                    BoardGestureSurface(
                        onPaintBegan: { location in
                            if showCoach { dismissCoach() }
                            onPaintBegan(cellIndex(at: location, scale: appliedScale, offset: appliedOffset))
                        },
                        onPaintMoved: { location in
                            if let index = cellIndex(at: location, scale: appliedScale, offset: appliedOffset) {
                                onPaintMoved(index)
                            }
                        },
                        onPaintEnded: onPaintEnded,
                        onPaintCancelled: onPaintCancelled,
                        onNavBegan: {
                            navStartScale = appliedScale
                            navStartOffset = appliedOffset
                        },
                        onNavChanged: { factor, centroid, startCentroid in
                            applyNavigation(
                                factor: factor,
                                centroid: centroid,
                                startCentroid: startCentroid,
                                fit: fit,
                                maxScale: maxScale,
                                area: inner,
                                side: side
                            )
                        }
                    )

                    if showCoach {
                        coachOverlay
                    }
                }
                .frame(width: inner.width, height: inner.height)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .frame(width: outer.width, height: outer.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !coachSeen else { return }
            showCoach = true
            coachDismissTask?.cancel()
            coachDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(4.5))
                guard !Task.isCancelled else { return }
                dismissCoach()
            }
        }
        .onDisappear { coachDismissTask?.cancel() }
    }

    private func applyNavigation(
        factor: CGFloat,
        centroid: CGPoint,
        startCentroid: CGPoint,
        fit: CGFloat,
        maxScale: CGFloat,
        area: CGSize,
        side: CGFloat
    ) {
        guard navStartScale > 0 else { return }
        let result = BoardTransform.navigated(
            startScale: navStartScale,
            startOffset: navStartOffset,
            startCentroid: startCentroid,
            factor: factor,
            centroid: centroid,
            minScale: fit,
            maxScale: maxScale,
            area: area,
            side: side
        )
        scale = result.scale
        offset = result.offset
        didInitTransform = true
    }

    private func cellIndex(at location: CGPoint, scale: CGFloat, offset: CGSize) -> Int? {
        BoardTransform.cellIndex(
            at: location,
            scale: scale,
            offset: offset,
            pitch: baseCell + gridSpacing,
            width: session.level.boardWidth,
            height: session.level.boardHeight
        )
    }

    private func clampOffset(_ candidate: CGSize, scale: CGFloat, area: CGSize, side: CGFloat) -> CGSize {
        BoardTransform.clampOffset(candidate, scale: scale, area: area, side: side)
    }

    private func dismissCoach() {
        coachDismissTask?.cancel()
        coachSeen = true
        withAnimation(.easeOut(duration: 0.3)) {
            showCoach = false
        }
    }

    private var coachOverlay: some View {
        VStack {
            Text(localization.string("game.board.coach"))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(AppTheme.textPrimary.opacity(0.9))
                )
                .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .allowsHitTesting(false)
    }
}

/// Deterministically laid-out grid of cells.
///
/// Using nested stacks (rather than `LazyVGrid`) guarantees that cell
/// `row * width + col` sits at exactly `(col * pitch, row * pitch)`, which is
/// the geometry the paint hit-testing relies on.
private struct PixelGrid: View {
    let session: GameSessionStore
    let cellSize: CGFloat
    let spacing: CGFloat
    let onFill: (Int) -> Void

    var body: some View {
        let width = session.level.boardWidth
        let height = session.level.boardHeight
        VStack(spacing: spacing) {
            ForEach(0..<height, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<width, id: \.self) { column in
                        PixelBoardCellView(
                            session: session,
                            cellIndex: row * width + column,
                            cellSize: cellSize,
                            onFill: onFill
                        )
                    }
                }
            }
        }
    }
}

/// Transparent overlay that captures touches only. It tracks touches directly
/// (rather than via competing gesture recognizers): one finger paints (reported
/// as content-space points), two fingers report a pinch factor + centroids for
/// zoom and pan.
private struct BoardGestureSurface: UIViewRepresentable {
    let onPaintBegan: (CGPoint) -> Void
    let onPaintMoved: (CGPoint) -> Void
    let onPaintEnded: () -> Void
    let onPaintCancelled: () -> Void
    let onNavBegan: () -> Void
    let onNavChanged: (_ factor: CGFloat, _ centroid: CGPoint, _ startCentroid: CGPoint) -> Void

    func makeUIView(context: Context) -> BoardTouchView {
        let view = BoardTouchView()
        apply(to: view)
        return view
    }

    func updateUIView(_ uiView: BoardTouchView, context: Context) {
        apply(to: uiView)
    }

    private func apply(to view: BoardTouchView) {
        view.onPaintBegan = onPaintBegan
        view.onPaintMoved = onPaintMoved
        view.onPaintEnded = onPaintEnded
        view.onPaintCancelled = onPaintCancelled
        view.onNavBegan = onNavBegan
        view.onNavChanged = onNavChanged
    }
}

/// A bare `UIView` that resolves one-finger painting versus two-finger
/// navigation by counting active touches itself. No `UIGestureRecognizer`s are
/// involved, so there is no recognition arena to lose.
private final class BoardTouchView: UIView {
    var onPaintBegan: ((CGPoint) -> Void)?
    var onPaintMoved: ((CGPoint) -> Void)?
    var onPaintEnded: (() -> Void)?
    var onPaintCancelled: (() -> Void)?
    var onNavBegan: (() -> Void)?
    var onNavChanged: ((CGFloat, CGPoint, CGPoint) -> Void)?

    private enum Mode {
        case idle
        case painting
        case navigating
        case blocked // a finger remains after navigation; it must not paint
    }

    private var mode: Mode = .idle
    private var trackedTouches: [UITouch] = []
    private var navStartDistance: CGFloat = 1
    private var navStartCentroid: CGPoint = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where !trackedTouches.contains(touch) {
            trackedTouches.append(touch)
        }
        resolveMode()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch mode {
        case .painting:
            if let touch = trackedTouches.first {
                onPaintMoved?(touch.location(in: self))
            }
        case .navigating:
            guard navStartDistance > 0 else { return }
            onNavChanged?(currentDistance() / navStartDistance, currentCentroid(), navStartCentroid)
        case .idle, .blocked:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackedTouches.removeAll { touches.contains($0) }
        resolveMode()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        trackedTouches.removeAll { touches.contains($0) }
        resolveMode()
    }

    private func resolveMode() {
        let count = trackedTouches.count
        switch mode {
        case .idle:
            if count >= 2 {
                beginNavigation()
            } else if count == 1, let touch = trackedTouches.first {
                mode = .painting
                onPaintBegan?(touch.location(in: self))
            }
        case .painting:
            if count >= 2 {
                onPaintCancelled?()
                beginNavigation()
            } else if count == 0 {
                onPaintEnded?()
                mode = .idle
            }
        case .navigating:
            if count < 2 {
                mode = (count == 0) ? .idle : .blocked
            }
        case .blocked:
            if count == 0 {
                mode = .idle
            }
        }
    }

    private func beginNavigation() {
        guard trackedTouches.count >= 2 else { return }
        navStartDistance = currentDistance()
        navStartCentroid = currentCentroid()
        mode = .navigating
        onNavBegan?()
    }

    private func currentCentroid() -> CGPoint {
        guard !trackedTouches.isEmpty else { return .zero }
        var sum = CGPoint.zero
        for touch in trackedTouches {
            let point = touch.location(in: self)
            sum.x += point.x
            sum.y += point.y
        }
        let count = CGFloat(trackedTouches.count)
        return CGPoint(x: sum.x / count, y: sum.y / count)
    }

    private func currentDistance() -> CGFloat {
        guard trackedTouches.count >= 2 else { return 1 }
        let a = trackedTouches[0].location(in: self)
        let b = trackedTouches[1].location(in: self)
        return max(1, hypot(a.x - b.x, a.y - b.y))
    }
}

private struct PixelBoardCellView: View {
    let session: GameSessionStore
    let cellIndex: Int
    let cellSize: CGFloat
    let onFill: (Int) -> Void

    @Environment(AppLocalization.self) private var localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popScale: CGFloat = 1.0

    private var profile: AnimationProfile {
        AnimationProfile(
            reduceMotion: reduceMotion,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

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
                .scaleEffect(popScale)
                .onChange(of: isFilled) { _, newValue in
                    guard newValue else { return }
                    if reduceMotion {
                        return
                    }
                    withAnimation(profile.pop()) {
                        popScale = 1.12
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        withAnimation(profile.pop()) {
                            popScale = 1.0
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(accessibilityLabel(colorIndex: colorIndex, isFilled: isFilled)))
                .accessibilityAddTraits(isFilled ? [] : .isButton)
                .accessibilityAction {
                    if !isFilled { onFill(cellIndex) }
                }
        } else {
            Color.clear
                .frame(width: cellSize, height: cellSize)
        }
    }

    private func accessibilityLabel(colorIndex: Int, isFilled: Bool) -> String {
        localization.string(isFilled ? "game.cell.filled" : "game.cell.empty", colorIndex + 1)
    }
}
