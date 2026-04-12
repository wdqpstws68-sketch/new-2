import SwiftUI

struct HomeView: View {
    @Environment(AppLocalization.self) private var localization

    let repository: LevelRepository
    let catalogItems: [LevelCatalogItem]
    let continueItem: LevelCatalogItem?
    let onSelectLevel: (LevelManifest) -> Void

    private var featuredItems: [LevelCatalogItem] {
        if let continueItem {
            return [continueItem] + catalogItems.filter { $0.id != continueItem.id }
        }
        return catalogItems
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(localization.string("journey.fallback.title"))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(localization.string("home.subtitle"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let continueItem {
                ContinueCard(item: continueItem, repository: repository) {
                    onSelectLevel(continueItem.level)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(localization.string("home.pickCard"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                TabView {
                    ForEach(featuredItems) { item in
                        LevelCard(item: item, repository: repository) {
                            onSelectLevel(item.level)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 430)
            }

            HStack(spacing: 14) {
                StatPill(title: localization.string("home.stat.levels"), value: "\(catalogItems.count)")
                StatPill(title: localization.string("home.stat.finished"), value: "\(catalogItems.filter(\.isCompleted).count)")
                StatPill(title: localization.string("home.stat.inProgress"), value: "\(catalogItems.filter(\.isInProgress).count)")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}

private struct ContinueCard: View {
    @Environment(AppLocalization.self) private var localization

    let item: LevelCatalogItem
    let repository: LevelRepository
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                preview

                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.string("home.continue"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.accentOrange)

                    Text(item.level.localizedTitle(using: localization))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(localization.string("journey.level.progress.inProgress", Int(item.progressFraction * 100)))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.accentOrange)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .shadow(color: AppTheme.shadowColor, radius: 18, x: 0, y: 12)
            )
        }
        .buttonStyle(.plain)
    }

    private var preview: some View {
        Group {
            if let image = repository.thumbnailImage(for: item.level) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.5))
            }
        }
        .frame(width: 92, height: 92)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.66))
        )
    }
}

private struct LevelCard: View {
    @Environment(AppLocalization.self) private var localization

    let item: LevelCatalogItem
    let repository: LevelRepository
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(item.level.localizedCategory(using: localization).uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentOrange.opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(AppTheme.accentOrange)

                    Spacer()

                    Text(statusText)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(statusColor)
                }

                Group {
                    if let image = repository.thumbnailImage(for: item.level) {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.45))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(Color.white.opacity(0.75))
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.level.localizedTitle(using: localization))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(
                        localization.string(
                            "home.card.meta",
                            item.level.localizedDifficulty(using: localization),
                            item.level.estimatedMinutes,
                            item.level.palette.count
                        )
                    )
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(Color.white.opacity(0.55))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(item.isCompleted ? AppTheme.accentGreen : AppTheme.accentOrange)
                                    .frame(width: proxy.size.width * item.progressFraction)
                            }
                    }
                    .frame(height: 10)

                    HStack {
                        Text(localization.string("journey.level.progress.inProgress", Int(item.progressFraction * 100)))
                        Spacer()
                        Text(
                            item.isCompleted
                                ? localization.string("home.stat.finished")
                                : localization.string("home.card.cells", item.level.paintableCellCount)
                        )
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                }

                Text(
                    item.isCompleted
                        ? localization.string("home.action.replay")
                        : item.isInProgress
                            ? localization.string("home.action.keepColoring")
                            : localization.string("home.action.start")
                )
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(item.isCompleted ? AppTheme.accentGreen : AppTheme.accentOrange)
                    )
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .shadow(color: AppTheme.shadowColor, radius: 22, x: 0, y: 16)
            )
        }
        .buttonStyle(.plain)
    }

    private var statusText: String {
        if item.isCompleted { return localization.string("home.status.done") }
        if item.isInProgress { return localization.string("home.status.live") }
        return localization.string("home.status.new")
    }

    private var statusColor: Color {
        if item.isCompleted { return AppTheme.accentGreen }
        if item.isInProgress { return AppTheme.accentOrange }
        return AppTheme.textSecondary
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
    }
}

#Preview {
    HomeView(
        repository: LevelRepository(),
        catalogItems: [],
        continueItem: nil,
        onSelectLevel: { _ in }
    )
    .environment(AppLocalization.preview)
}
