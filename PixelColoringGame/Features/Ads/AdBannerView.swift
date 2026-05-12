import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// SwiftUI wrapper for Google Mobile Ads adaptive banner.
/// Returns an empty view if the SDK is unavailable or consent is not granted.
struct AdBannerView: View {
    /// Test banner unit ID (Google's recommended test ID). Replace with real production unit ID before release.
    static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"

    let adUnitID: String
    let canRequestAds: Bool

    init(
        adUnitID: String = AdBannerView.testBannerUnitID,
        canRequestAds: Bool
    ) {
        self.adUnitID = adUnitID
        self.canRequestAds = canRequestAds
    }

    var body: some View {
        #if canImport(GoogleMobileAds)
        if canRequestAds {
            AdaptiveBannerRepresentable(adUnitID: adUnitID)
                .frame(height: 50)
        } else {
            EmptyView()
        }
        #else
        EmptyView()
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct AdaptiveBannerRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.rootViewController = topViewController()
        container.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        let request = Request()
        banner.load(request)

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        var top = window.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
#endif
