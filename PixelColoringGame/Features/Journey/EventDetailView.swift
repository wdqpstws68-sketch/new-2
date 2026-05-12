import SwiftUI

struct MonthDetailView: View {
    @Environment(AppLocalization.self) private var localization

    let monthID: String
    let eventState: EventCollectionState?
    let repository: LevelRepository
    let onOpenArtwork: (LevelManifest, String, String) -> Void
    let onEquipEventTitle: (String) -> Void
    let onDismissMissing: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 2)

    var body: some View {
        Group {
            if let eventState {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EventOverviewHeaderCard(eventState: eventState)

                        sectionLabel("month.detail.reward")
                        EventRewardTitleCard(
                            eventState: eventState,
                            onEquipEventTitle: onEquipEventTitle
                        )

                        sectionLabel("month.detail.artworks")
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(eventState.entries) { entry in
                                EventArtworkTileView(
                                    entry: entry,
                                    image: entry.isCompleted ? repository.thumbnailImage(for: entry.level) : nil,
                                    accentColor: eventState.event.accentColor,
                                    action: {
                                        onOpenArtwork(
                                            entry.level,
                                            eventState.event.id,
                                            eventState.event.titleKey
                                        )
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            } else {
                EventDetailMissingView(
                    eventID: monthID,
                    onDismiss: onDismissMissing
                )
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var navigationTitle: String {
        guard let eventState else {
            return localization.string("month.detail.navigationFallback")
        }
        return eventState.event.localizedTitle(using: localization)
    }

    @ViewBuilder
    private func sectionLabel(_ key: String) -> some View {
        Text(localization.string(key))
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 4)
    }
}

private struct EventDetailMissingView: View {
    @Environment(AppLocalization.self) private var localization

    let eventID: String
    let onDismiss: () -> Void

    @State private var didLogAppearance = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)

            Text(localization.string("month.detail.missing.title"))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(localization.string("month.detail.missing.subtitle"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: onDismiss) {
                Text(localization.string("month.detail.missing.action"))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(AppTheme.textPrimary)
                    )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard !didLogAppearance else { return }
            didLogAppearance = true
            AppLogger.eventDetailMissing(eventID: eventID)
        }
    }
}

@MainActor
private struct MonthDetailPreviewContainer: View {
    let completedStorageKeys: Set<String>

    private let levelRepository: LevelRepository
    private let dailyRepository: DailyChallengeRepository

    init(completedStorageKeys: Set<String>) {
        let levelRepository = LevelRepository()
        self.levelRepository = levelRepository
        self.dailyRepository = DailyChallengeRepository(levelRepository: levelRepository)
        self.completedStorageKeys = completedStorageKeys
    }

    var body: some View {
        NavigationStack {
            MonthDetailView(
                monthID: previewEvent?.id ?? "missing",
                eventState: eventState,
                repository: levelRepository,
                onOpenArtwork: { _, _, _ in },
                onEquipEventTitle: { _ in },
                onDismissMissing: {}
            )
        }
        .environment(AppLocalization.preview)
    }

    private var previewEvent: EventManifest? {
        dailyRepository.events.first
    }

    private var eventState: EventCollectionState? {
        guard let previewEvent else { return nil }

        let entries = previewEvent.availableEntries(on: .now).compactMap { entry -> DailyAlbumEntryState? in
            guard let level = dailyRepository.level(storageKey: entry.levelKey) else {
                return nil
            }

            return DailyAlbumEntryState(
                level: level,
                isCompleted: completedStorageKeys.contains(level.storageKey),
                bestRank: completedStorageKeys.contains(level.storageKey) ? .perfect : .normal,
                isToday: false
            )
        }

        return EventCollectionState(
            event: previewEvent,
            entries: entries,
            isActive: true,
            isTitleUnlocked: completedStorageKeys.count == entries.count && !entries.isEmpty,
            isTitleEquipped: false
        )
    }
}

#Preview("Month Detail - In Progress") {
    MonthDetailPreviewContainer(completedStorageKeys: [])
}
