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

    @State private var showSoundSettings = false

    var body: some View {
        Menu {
            Button {
                onOpenCollectionBook(defaultCollectionChapterID)
            } label: {
                Label(collectionTitle, systemImage: "books.vertical.fill")
            }

            Button {
                showSoundSettings = true
            } label: {
                Label(localization.string("settings.sound.open"), systemImage: "slider.horizontal.3")
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
        .sheet(isPresented: $showSoundSettings) {
            SoundSettingsView()
                .environment(localization)
                .environment(audio)
                .environment(audioSettings)
        }
    }
}

/// Independent BGM and sound-effect volume controls, plus a master mute.
struct SoundSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLocalization.self) private var localization
    @Environment(AudioPlayerService.self) private var audio
    @Environment(AudioSettings.self) private var audioSettings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Toggle(isOn: Binding(
                        get: { audioSettings.isMuted },
                        set: { audio.setMuted($0) }
                    )) {
                        Label(localization.string("settings.audio.mute"), systemImage: "speaker.slash.fill")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .tint(AppTheme.accentGreen)

                    // Only the volume rows dim while muted — the mute toggle
                    // itself stays fully lit so it never looks disabled.
                    VStack(spacing: 20) {
                        volumeRow(
                            title: localization.string("settings.sound.bgm"),
                            systemImage: "music.note",
                            tint: AppTheme.accentSky,
                            value: Binding(
                                get: { audioSettings.bgmVolume },
                                set: { audio.setBGMVolume($0) }
                            )
                        )

                        volumeRow(
                            title: localization.string("settings.sound.sfx"),
                            systemImage: "waveform",
                            tint: AppTheme.accentOrange,
                            value: Binding(
                                get: { audioSettings.sfxVolume },
                                set: {
                                    audio.setSFXVolume($0)
                                    audio.playTap() // preview the new level (throttled)
                                }
                            )
                        )
                    }
                    .opacity(audioSettings.isMuted ? 0.55 : 1)
                    .animation(.easeInOut(duration: 0.2), value: audioSettings.isMuted)
                }
                .padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppTheme.surfaceSunken.ignoresSafeArea())
            .navigationTitle(localization.string("settings.sound.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.string("settings.sound.done")) { dismiss() }
                        .font(.system(size: 16, weight: .black, design: .rounded))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func volumeRow(title: String, systemImage: String, tint: Color, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .accessibilityHidden(true)
                Slider(value: value, in: 0...1)
                    .tint(tint)
                    .accessibilityLabel(Text(title))
                    .accessibilityValue(Text("\(Int((value.wrappedValue * 100).rounded()))%"))
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.surfaceElevated)
                .shadow(color: AppTheme.shadowColor, radius: 10, x: 0, y: 6)
        )
    }
}
