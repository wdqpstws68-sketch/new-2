import SwiftUI

struct CollectionBookView: View {
    @Environment(AppLocalization.self) private var localization

    let manifest: JourneyManifest
    let snapshot: JourneyProgressSnapshot
    let repository: LevelRepository

    @State private var selection: String

    init(
        manifest: JourneyManifest,
        snapshot: JourneyProgressSnapshot,
        repository: LevelRepository,
        initialChapterID: String? = nil
    ) {
        self.manifest = manifest
        self.snapshot = snapshot
        self.repository = repository
        _selection = State(initialValue: initialChapterID ?? snapshot.collectionRevealState.first?.id ?? "")
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(manifest.localizedCollectionTitle(using: localization))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(localization.string("collection.subtitle"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            TabView(selection: $selection) {
                ForEach(snapshot.collectionRevealState) { pageState in
                    CollectionPageView(pageState: pageState, repository: repository)
                        .padding(.horizontal, 20)
                        .tag(pageState.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
        .navigationBarTitleDisplayMode(.inline)
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
