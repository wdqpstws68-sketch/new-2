import SwiftUI

struct CollectionBookView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(AudioPlayerService.self) private var audio

    let manifest: JourneyManifest
    let snapshot: JourneyProgressSnapshot
    let homeSnapshot: HomeProgressSnapshot
    let repository: LevelRepository
    let onEquipEventTitle: (String) -> Void

    @State private var section: CollectionSection = .journey
    @State private var selection: String

    init(
        manifest: JourneyManifest,
        snapshot: JourneyProgressSnapshot,
        homeSnapshot: HomeProgressSnapshot,
        repository: LevelRepository,
        initialChapterID: String? = nil,
        onEquipEventTitle: @escaping (String) -> Void
    ) {
        self.manifest = manifest
        self.snapshot = snapshot
        self.homeSnapshot = homeSnapshot
        self.repository = repository
        self.onEquipEventTitle = onEquipEventTitle
        _selection = State(initialValue: initialChapterID ?? snapshot.collectionRevealState.first?.id ?? "")
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(manifest.localizedCollectionTitle(using: localization))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(sectionSubtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Picker(localization.string("collection.section.picker"), selection: $section) {
                ForEach(CollectionSection.allCases) { section in
                    Text(localization.string(section.titleKey)).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            Group {
                switch section {
                case .journey:
                    TabView(selection: $selection) {
                        ForEach(snapshot.collectionRevealState) { pageState in
                            CollectionPageView(pageState: pageState, repository: repository)
                                .padding(.horizontal, 20)
                                .tag(pageState.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                case .daily:
                    if homeSnapshot.dailyAlbumEntries.isEmpty {
                        emptyCollectionPrompt
                    } else {
                        DailyAlbumCollectionView(
                            entries: homeSnapshot.dailyAlbumEntries,
                            repository: repository
                        )
                    }
                case .events:
                    let pastEvents = homeSnapshot.eventCollections.filter { !$0.isActive }
                    if pastEvents.isEmpty {
                        emptyCollectionPrompt
                    } else {
                        EventHistoryCollectionView(
                            events: pastEvents,
                            repository: repository,
                            onEquipEventTitle: onEquipEventTitle
                        )
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { audio.playBGM(.bgmCollection) }
    }

    private var emptyCollectionPrompt: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(localization.string("collection.empty.title"))
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text(localization.string("collection.empty.subtitle"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var sectionSubtitle: String {
        switch section {
        case .journey:
            return localization.string("collection.subtitle")
        case .daily:
            return localization.string("collection.section.daily.subtitle")
        case .events:
            return localization.string("collection.section.events.subtitle")
        }
    }
}

private enum CollectionSection: String, CaseIterable, Identifiable {
    case journey
    case daily
    case events

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .journey:
            return "collection.section.journey"
        case .daily:
            return "collection.section.daily"
        case .events:
            return "collection.section.events"
        }
    }
}

private struct DailyAlbumCollectionView: View {
    let entries: [DailyAlbumEntryState]
    let repository: LevelRepository

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: 2)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(entries) { entry in
                    DailyAlbumArtworkCard(
                        entry: entry,
                        image: entry.isCompleted ? repository.thumbnailImage(for: entry.level) : nil
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }
}

private struct EventHistoryCollectionView: View {
    let events: [EventCollectionState]
    let repository: LevelRepository
    let onEquipEventTitle: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if events.isEmpty {
                    EmptyCollectionState(
                        title: "collection.events.empty.title",
                        subtitle: "collection.events.empty.subtitle"
                    )
                } else {
                    ForEach(events) { event in
                        EventArchiveCard(
                            event: event,
                            repository: repository,
                            onEquipEventTitle: onEquipEventTitle
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }
}

private struct CollectionPageView: View {
    @Environment(AppLocalization.self) private var localization

    let pageState: JourneyCollectionPageState
    let repository: LevelRepository

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pageState.chapter.chapter.localizedTitle(using: localization))
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(pageState.chapter.chapter.localizedSubtitle(using: localization))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    if pageState.hasRibbon {
                        VStack(spacing: 4) {
                            Image(systemName: "rosette")
                                .font(.system(size: 22, weight: .black))
                            Text(pageState.chapter.chapter.localizedBadgeTitle(using: localization))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(pageState.chapter.chapter.accentColor)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(pageState.chapter.chapter.accentColor.opacity(0.12))
                        )
                    }
                }

                LazyVGrid(columns: artworkColumns, spacing: 14) {
                    ForEach(pageState.artworkSlots) { slot in
                        CollectionArtworkCard(
                            slot: slot,
                            image: slot.isRevealed ? repository.thumbnailImage(for: slot.level) : nil,
                            accentColor: pageState.chapter.chapter.accentColor
                        )
                    }
                }

                Text(
                    localization.string(
                        pageState.hasRibbon
                            ? "collection.page.ribbon.complete"
                            : "collection.page.ribbon.incomplete"
                    )
                )
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.86))
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(pageState.chapter.chapter.accentColor.opacity(0.16))
                            .frame(width: 128, height: 128)
                            .offset(x: 30, y: -30)
                    }
                    .shadow(color: AppTheme.shadowColor, radius: 20, x: 0, y: 14)
            )
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(pageState.accessibilityLabel(using: localization))
    }

    private var artworkColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: 2)
    }
}

private struct CollectionArtworkCard: View {
    @Environment(AppLocalization.self) private var localization

    let slot: JourneyArtworkSlotState
    let image: UIImage?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.9))

                        VStack(spacing: 10) {
                            Image(systemName: "lock.doc.fill")
                                .font(.system(size: 28, weight: .black))
                            Text(localization.string("collection.artwork.hidden"))
                                .font(.system(size: 14, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.86))
            )

            Text(
                slot.isRevealed
                    ? slot.level.localizedTitle(using: localization)
                    : localization.string("collection.artwork.unrevealedTitle")
            )
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text(
                slot.isRevealed
                    ? "\(slot.level.localizedCategory(using: localization)) · \(slot.level.localizedDifficulty(using: localization))"
                    : localization.string("collection.artwork.unrevealedSubtitle")
            )
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(accentColor.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1.2)
                }
        )
        .accessibilityLabel(slot.accessibilityLabel(using: localization))
    }
}

private struct DailyAlbumArtworkCard: View {
    @Environment(AppLocalization.self) private var localization

    let entry: DailyAlbumEntryState
    let image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.9))

                        VStack(spacing: 10) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 28, weight: .black))
                            Text(localization.string("collection.daily.notPainted"))
                                .font(.system(size: 14, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.86))
            )

            Text(entry.level.localizedTitle(using: localization))
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 8) {
                Text(
                    localization.string(
                        entry.isCompleted
                            ? "collection.daily.completed"
                            : "collection.daily.waiting"
                    )
                )
                if entry.bestRank == .perfect {
                    Text(localization.string("common.rank.perfect"))
                }
                if entry.isToday {
                    Text(localization.string("collection.daily.today"))
                }
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(AppTheme.accentOrange.opacity(0.16), lineWidth: 1.2)
                }
        )
    }
}

private struct EventArchiveCard: View {
    let event: EventCollectionState
    let repository: LevelRepository
    let onEquipEventTitle: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            EventOverviewHeaderCard(eventState: event)

            EventRewardTitleCard(
                eventState: event,
                onEquipEventTitle: onEquipEventTitle
            )

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(event.entries) { entry in
                    EventArtworkTileView(
                        entry: entry,
                        image: entry.isCompleted ? repository.thumbnailImage(for: entry.level) : nil,
                        accentColor: event.event.accentColor,
                        action: nil
                    )
                }
            }
        }
        .padding(.bottom, 6)
    }
}

private struct EmptyCollectionState: View {
    @Environment(AppLocalization.self) private var localization

    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(localization.string(title))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text(localization.string(subtitle))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(26)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
    }
}
