import SwiftUI

struct EventOverviewHeaderCard: View {
    @Environment(AppLocalization.self) private var localization

    let eventState: EventCollectionState

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                if eventState.isActive {
                    Text(localization.string("event.currentMonth"))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(eventState.event.accentColor)
                }

                Text(eventState.localizedHeaderTitle(using: localization))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(eventState.localizedHeaderSubtitle(using: localization))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    localization.string(
                        "collection.events.progress",
                        eventState.completedEntryCount,
                        max(eventState.totalEntryCount, 1)
                    )
                )
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(eventState.event.accentColor)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                Image("EventTitleMedallion")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 52, height: 52)

                Text(
                    localization.string(
                        "collection.events.progress",
                        eventState.completedEntryCount,
                        max(eventState.totalEntryCount, 1)
                    )
                )
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(eventState.event.accentColor)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(eventState.event.accentColor.opacity(0.18), lineWidth: 1.3)
                }
                .overlay(alignment: .topTrailing) {
                    Image("EventTitleMedallion")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .opacity(0.2)
                        .offset(x: 18, y: -18)
                }
        )
    }
}

struct EventRewardTitleCard: View {
    @Environment(AppLocalization.self) private var localization

    let eventState: EventCollectionState
    let onEquipEventTitle: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(eventState.titleDefinition.localizedTitle(using: localization))
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(
                        eventState.isTitleUnlocked
                            ? eventState.titleDefinition.localizedSubtitle(using: localization)
                            : localization.string("collection.events.title.locked")
                    )
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if let onEquipEventTitle, eventState.isTitleUnlocked {
                    Button(action: { onEquipEventTitle(eventState.titleDefinition.id) }) {
                        Text(
                            localization.string(
                                eventState.isTitleEquipped
                                    ? "collection.events.title.equipped"
                                    : "collection.events.title.equip"
                            )
                        )
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(eventState.isTitleEquipped ? .white : eventState.event.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    eventState.isTitleEquipped
                                        ? eventState.event.accentColor
                                        : eventState.event.accentColor.opacity(0.14)
                                )
                        )
                    }
                    .buttonStyle(.tapSound)
                    .disabled(eventState.isTitleEquipped)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(eventState.event.accentColor.opacity(0.1))
        )
    }
}

struct EventArtworkTileView: View {
    @Environment(AppLocalization.self) private var localization

    let entry: DailyAlbumEntryState
    let image: UIImage?
    let accentColor: Color
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(.tapSound)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            artworkPreview

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.level.localizedTitle(using: localization))
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    statusChips
                }

                Spacer(minLength: 0)

                if action != nil {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(accentColor)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(accentColor.opacity(0.16), lineWidth: 1.2)
                }
        )
    }

    private var artworkPreview: some View {
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
                        Image(systemName: "wand.and.stars")
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
        .overlay(alignment: .topLeading) {
            // Past daily artworks cost a heart on first entry; today's daily and already-finished
            // artworks are free, so only flag the ones that will actually charge.
            if !entry.isToday, !entry.isCompleted {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                    Text(verbatim: "−1")
                }
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(AppTheme.accentOrange))
                .padding(10)
            }
        }
    }

    private var statusChips: some View {
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
}
