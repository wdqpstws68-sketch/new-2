import SwiftUI

/// Lightweight top strip used on every tab: life counter on the left, utility menu on the right.
struct TabTopStrip: View {
    let balance: LifeBalance
    let collectionTitle: String
    let defaultCollectionChapterID: String?
    let onOpenCollectionBook: (String?) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.m) {
            LifeStatusView(balance: balance)

            JourneyUtilityMenuButton(
                collectionTitle: collectionTitle,
                defaultCollectionChapterID: defaultCollectionChapterID,
                onOpenCollectionBook: onOpenCollectionBook
            )
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.s)
    }
}
