import SwiftUI

struct CompletionView: View {
    let summary: LevelCompletionSummary
    let repository: LevelRepository
    let onReturnHome: () -> Void
    let onPlayNext: () -> Void

    private let celebrationCopies = [
        "SO SATISFYING!",
        "SUPER ENJOYABLE!",
        "SUPER FUN!",
        "LOOKS GREAT!"
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Text(summary.level.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)

            if let image = repository.solvedImage(for: summary.level) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 360, maxHeight: 360)
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 40, style: .continuous)
                            .fill(AppTheme.cardBackground)
                            .shadow(color: AppTheme.shadowColor, radius: 24, x: 0, y: 18)
                    )
            }

            Text(celebrationCopies[abs(summary.level.id.hashValue) % celebrationCopies.count])
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.accentOrange)
                .multilineTextAlignment(.center)

            Text("\(summary.filledCells) cells painted · \(summary.level.palette.count) colors mastered")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 12) {
                Button(action: onReturnHome) {
                    Text("Back To Home")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(AppTheme.accentOrange)
                        )
                }
                .buttonStyle(.plain)

                if summary.nextLevel != nil {
                    Button(action: onPlayNext) {
                        Text("Play Next Level")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.9))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 360)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
}
