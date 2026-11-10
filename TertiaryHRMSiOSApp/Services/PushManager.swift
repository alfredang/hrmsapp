import SwiftUI
import UIKit
import UserNotifications

/// Remote (APNs) push notifications.
///
/// - After sign-in: ask for alert/badge/sound permission, register with APNs and upload the
///   device token to `POST /api/mobile/push-token`. The token is re-uploaded whenever APNs
///   hands us a new one.
/// - On sign-out: `DELETE /api/mobile/push-token` (best effort) so the phone stops receiving
///   the previous user's alerts.
/// - Foreground pushes show as banners; a tap routes by the payload's `link` (a web path such
///   as `/approvals` or `/attendance`) through `pendingLink`, which `MainTabView` observes.
@MainActor
final class PushManager: NSObject, ObservableObject {
    static let shared = PushManager()

    /// The web path of the notification the user tapped; consumed (set back to nil) by `MainTabView`.
    @Published var pendingLink: String?

    private var token: String?
    private var signedIn = false
    private var uploadedToken: String?

    private static var environment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    /// Never prompt or register while running the screenshot / UI-preview harness.
    private var isPreview: Bool { ProcessInfo.processInfo.arguments.contains("-uiPreview") }

    // MARK: Session lifecycle

    func onSignedIn() {
        guard !isPreview else { return }
        signedIn = true
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            await uploadIfNeeded()
        }
    }

    /// Call BEFORE the session cookie is cleared, so the DELETE is still authenticated.
    func onSignedOut() async {
        signedIn = false
        if let t = uploadedToken { try? await HRMSAPI.shared.unregisterPushToken(t) }
        uploadedToken = nil
        Self.setBadge(0)
    }

    private static func setBadge(_ n: Int) {
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(n) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = n
        }
    }

    // MARK: APNs callbacks (via AppDelegate)

    func didRegister(deviceToken: Data) {
        token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await uploadIfNeeded() }
    }

    private func uploadIfNeeded() async {
        guard signedIn, let t = token, t != uploadedToken else { return }
        do {
            try await HRMSAPI.shared.registerPushToken(t, environment: Self.environment)
            uploadedToken = t
        } catch {
            // Retried on the next sign-in / token refresh / foreground.
        }
    }

    /// Foreground: retry a failed token upload and sync the app badge with the unread count.
    func onForeground() async {
        guard signedIn else { return }
        await uploadIfNeeded()
        await NotificationStore.shared.refresh()
        Self.setBadge(NotificationStore.shared.unread)
    }
}

extension PushManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        Task { @MainActor in await NotificationStore.shared.refresh() }
        return [.banner, .list, .sound, .badge]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let link = response.notification.request.content.userInfo["link"] as? String
        await MainActor.run {
            self.pendingLink = link ?? "/notifications"
        }
    }
}

/// Bridges the UIKit APNs callbacks into SwiftUI (`@UIApplicationDelegateAdaptor`).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = PushManager.shared
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushManager.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // No APNs (simulator without push, no network): the in-app bell still works.
    }
}

/// Where a notification's web `link` opens in the app. Shared by push taps and the
/// in-app notifications list.
enum PushRoute: Identifiable, Equatable {
    case tab(Int)
    case approvals, clock, expenses, timeOff, adminTimesheet, myTimesheet, notifications

    var id: String { "\(self)" }

    static func from(link: String?, isAdmin: Bool, isIntern: Bool) -> PushRoute {
        let path = (link ?? "").split(separator: "?").first.map(String.init) ?? ""
        switch true {
        case path.hasPrefix("/approvals"), path.hasPrefix("/leave/approv"):
            return isAdmin ? .approvals : .tab(1)
        case path.hasPrefix("/attendance"), path.hasPrefix("/clock"):
            return .clock
        case path.hasPrefix("/timesheet/overview"):
            return isAdmin ? .adminTimesheet : .myTimesheet
        case path.hasPrefix("/timesheet"):
            return isIntern ? .myTimesheet : (isAdmin ? .adminTimesheet : .notifications)
        case path.hasPrefix("/expenses"):
            return isAdmin && path.contains("approv") ? .approvals : .expenses
        case path.hasPrefix("/time-off"):
            return .timeOff
        case path.hasPrefix("/leave"):
            return .tab(1)
        case path.hasPrefix("/calendar"):
            return .tab(2)
        default:
            return .notifications
        }
    }
}
