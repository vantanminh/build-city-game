import UIKit

/// Lightweight haptic feedback wrapper for build actions.
@MainActor
enum Haptics {
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func placementSuccess() {
        impactGenerator.impactOccurred()
    }

    static func placementError() {
        notificationGenerator.notificationOccurred(.error)
    }
}
