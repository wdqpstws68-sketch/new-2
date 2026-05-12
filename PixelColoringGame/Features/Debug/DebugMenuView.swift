#if DEBUG
import SwiftUI
import SwiftData

struct DebugMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [PlayerProfile]

    let coordinator: CelebrationCoordinator?

    @State private var showClearAllConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Celebrations Seen") {
                    Button("Clear all celebrationsSeen", role: .destructive) {
                        showClearAllConfirmation = true
                    }
                    if seenList.isEmpty {
                        Text("(none)").foregroundStyle(.secondary)
                    } else {
                        ForEach(seenList, id: \.self) { key in
                            HStack {
                                Text(key).font(.system(.body, design: .monospaced))
                                Spacer()
                                Button("Clear") { clearSeen(key) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Section("Fire celebration") {
                    Button("Chapter Clear (berry-meadow)") {
                        coordinator?.handle(trigger: .levelCompleted(
                            profileSnapshot: testSnapshot(chapterFinal: "berry-meadow")
                        ))
                    }
                    Button("Journey Complete") {
                        coordinator?.handle(trigger: .levelCompleted(
                            profileSnapshot: testSnapshot(journeyComplete: true)
                        ))
                    }
                    Button("Monthly Complete (2026-04)") {
                        coordinator?.handle(trigger: .dailyCompleted(
                            profileSnapshot: testSnapshot(monthlyCompleted: "2026-04")
                        ))
                    }
                    Button("First Perfect") {
                        coordinator?.handle(trigger: .levelCompleted(
                            profileSnapshot: testSnapshot(perfect: true)
                        ))
                    }
                    Button("Streak 7") {
                        coordinator?.handle(trigger: .dailyCompleted(
                            profileSnapshot: testSnapshot(streak: 7)
                        ))
                    }
                    Button("Streak 30 (supersedes 7/14)") {
                        coordinator?.handle(trigger: .dailyCompleted(
                            profileSnapshot: testSnapshot(streak: 30)
                        ))
                    }
                    Button("Levels 100 (supersedes 10/50)") {
                        coordinator?.handle(trigger: .levelCompleted(
                            profileSnapshot: testSnapshot(completedLevels: 100)
                        ))
                    }
                }

                Section("Profile fields") {
                    if let profile = profiles.first {
                        LabeledContent("Streak") {
                            Stepper("\(profile.currentStreak)",
                                    value: streakBinding(profile),
                                    in: 0...90)
                        }
                        LabeledContent("Best streak") { Text("\(profile.bestStreak)") }
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Clear all celebrationsSeen?",
                isPresented: $showClearAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear all", role: .destructive) {
                    clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes all 'seen' markers. Celebrations will re-fire on next trigger.")
            }
        }
    }

    private var seenList: [String] {
        Array((profiles.first?.celebrationsSeen ?? []).sorted())
    }

    private func clearAll() {
        guard let profile = profiles.first else { return }
        profile.celebrationsSeen = []
        try? modelContext.save()
    }

    private func clearSeen(_ key: String) {
        guard let profile = profiles.first else { return }
        var seen = profile.celebrationsSeen
        seen.remove(key)
        profile.celebrationsSeen = seen
        try? modelContext.save()
    }

    private func streakBinding(_ profile: PlayerProfile) -> Binding<Int> {
        Binding(
            get: { profile.currentStreak },
            set: { newValue in
                profile.currentStreak = newValue
                profile.bestStreak = max(profile.bestStreak, newValue)
                try? modelContext.save()
            }
        )
    }

    private func testSnapshot(
        completedLevels: Int = 0,
        perfect: Bool = false,
        streak: Int = 0,
        chapterFinal: String? = nil,
        journeyComplete: Bool = false,
        monthlyCompleted: String? = nil
    ) -> PlayerProfileSnapshot {
        PlayerProfileSnapshot(
            completedLevelCount: completedLevels,
            perfectLevelCount: perfect ? 1 : 0,
            currentStreakDays: streak,
            completedChapterIDs: [],
            isJourneyComplete: journeyComplete,
            lastLevelChapterID: chapterFinal,
            lastLevelWasPerfect: perfect,
            lastLevelWasChapterFinalLevel: chapterFinal != nil,
            monthlyCompletedYearMonth: monthlyCompleted
        )
    }
}
#endif
