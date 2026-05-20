import SwiftUI
import SafariServices

/// Thin SwiftUI wrapper around `SFSafariViewController`.
/// Lets the app open a news article in an in-app browser without
/// requiring extra entitlements or launching the system Safari app.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor.systemBlue
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
