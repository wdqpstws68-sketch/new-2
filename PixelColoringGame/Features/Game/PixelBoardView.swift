import SwiftUI

struct PixelBoardView: View {
    let session: GameSessionStore
    let onTapCell: (Int) -> Void

    private let spacing: CGFloat = 2.2
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let maxBoardSide: CGFloat = 560

    var body: some View {
        GeometryReader { proxy in
            let availableSide = min(proxy.size.width, proxy.size.height)
            let side = min(availableSide, maxBoardSide)
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
            .scaleEffect(scale, anchor: .center)
            .offset(offset)
            .simultaneousGesture(magnificationGesture(side: side))
            .simultaneousGesture(dragGesture(side: side))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(AppTheme.boardBackground)
                    .shadow(color: AppTheme.shadowColor, radius: 20, x: 0, y: 16)
            )
            .overlay(alignment: .topTrailing) {
                if scale > minScale {
                    resetButton
                        .padding(12)
                        .transition(.opacity.combined(with: .scale))
                }
            }
        }
    }

    private var resetButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                scale = minScale
                lastScale = minScale
                offset = .zero
                lastOffset = .zero
            }
        } label: {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.82))
                        .shadow(color: AppTheme.shadowColor, radius: 6, x: 0, y: 3)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("ズームをリセット"))
    }

    private func magnificationGesture(side: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = min(max(lastScale * value, minScale), maxScale)
                scale = newScale
                offset = clampedOffset(offset, side: side, scale: newScale)
            }
            .onEnded { _ in
                if scale <= minScale {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        scale = minScale
                        lastScale = minScale
                        offset = .zero
                        lastOffset = .zero
                    }
                } else {
                    lastScale = scale
                    lastOffset = offset
                }
            }
    }

    private func dragGesture(side: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }
                let candidate = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(candidate, side: side, scale: scale)
            }
            .onEnded { _ in
                guard scale > minScale else { return }
                lastOffset = offset
            }
    }

    private func clampedOffset(_ candidate: CGSize, side: CGFloat, scale: CGFloat) -> CGSize {
        let limit = max(0, side * (scale - 1) / 2)
        return CGSize(
            width: min(max(candidate.width, -limit), limit),
            height: min(max(candidate.height, -limit), limit)
        )
    }
}

private struct PixelBoardCellView: View {
    let session: GameSessionStore
    let cellIndex: Int
    let cellSize: CGFloat

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
        } else {
            Color.clear
                .frame(width: cellSize, height: cellSize)
        }
    }
}
