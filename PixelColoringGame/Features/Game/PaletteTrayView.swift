import SwiftUI

struct PaletteTrayView: View {
    @Environment(AppLocalization.self) private var localization

    let paletteStates: [GameSessionStore.PaletteChipState]
    let progressLabel: String
    let onSelectColor: (Int) -> Void
    let onHint: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.string("game.palette.title"))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(localization.string("game.progress.filled", progressLabel))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Button(action: onHint) {
                    Label(localization.string("game.palette.hint"), systemImage: "sparkles")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(AppTheme.accentGreen)
                        )
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(paletteStates) { state in
                    Button {
                        onSelectColor(state.entry.index)
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(state.isCompleted ? AppTheme.completedTint : state.entry.color)
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.white.opacity(0.6), lineWidth: 1.8)
                                    }
                                    .overlay(alignment: .topLeading) {
                                        Circle()
                                            .fill(Color.white.opacity(state.isCompleted ? 0.12 : 0.42))
                                            .frame(width: 9, height: 9)
                                            .offset(x: 5, y: 5)
                                    }

                                Text("\(state.entry.index + 1)")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.92))
                            }

                            Text(
                                state.isCompleted
                                    ? localization.string("game.palette.done")
                                    : localization.string("game.palette.left", state.remainingCount)
                            )
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(state.isCompleted ? AppTheme.completedTint : AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(state.isSelected ? Color.white : AppTheme.chipEmpty.opacity(0.45))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(state.isSelected ? state.entry.color : AppTheme.chipBorder.opacity(0.5), lineWidth: state.isSelected ? 3 : 1.2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.trayBackground)
                .shadow(color: AppTheme.shadowColor, radius: 16, x: 0, y: 10)
        )
    }
}
