import SwiftUI

struct JourneyTopBar: View {
    @Environment(AppLocalization.self) private var localization

    let title: String
    let equippedEventTitle: EventTitleDefinition?
    let collectionTitle: String
    let defaultCollectionChapterID: String?
    let onOpenCollectionBook: (String?) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let equippedEventTitle {
                    Label(equippedEventTitle.localizedTitle(using: localization), systemImage: "rosette")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.accentOrange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppTheme.accentOrange.opacity(0.14))
                        )
                }
            }

            Spacer(minLength: 0)

            JourneyUtilityMenuButton(
                collectionTitle: collectionTitle,
                defaultCollectionChapterID: defaultCollectionChapterID,
                onOpenCollectionBook: onOpenCollectionBook
            )
        }
    }
}

struct JourneyUtilityMenuButton: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(AudioPlayerService.self) private var audio
    @Environment(AudioSettings.self) private var audioSettings

    let collectionTitle: String
    let defaultCollectionChapterID: String?
    let onOpenCollectionBook: (String?) -> Void

    var body: some View {
        Menu {
            Button {
                onOpenCollectionBook(defaultCollectionChapterID)
            } label: {
                Label(collectionTitle, systemImage: "books.vertical.fill")
            }

            Toggle(localization.string("settings.audio.mute"), isOn: Binding(
                get: { audioSettings.isMuted },
                set: { audio.setMuted($0) }
            ))

            Menu {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        localization.setLanguage(language)
                    } label: {
                        if language == localization.language {
                            Label(language.nativeName, systemImage: "checkmark")
                        } else {
                            Text(language.nativeName)
                        }
                    }
                }
            } label: {
                Label(localization.string("app.language.menu.accessibility"), systemImage: "globe")
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppTheme.homeUtilityBackground)

                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(localization.language.badgeLabel)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppTheme.textPrimary)
                    )
                    .offset(x: 8, y: 8)
            }
            .frame(width: 54, height: 54)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.82), lineWidth: 1)
            }
        }
        .accessibilityLabel(localization.string("home.menu.accessibility"))
    }
}
