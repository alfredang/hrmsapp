import SwiftUI

/// Shared notifications state so the nav-bar bell badge and the list stay in
/// sync: refreshed on launch and after any mark-read.
@MainActor
final class NotificationStore: ObservableObject {
    static let shared = NotificationStore()
    @Published var items: [AppNotification] = []

    var unread: Int { items.filter { !$0.read }.count }
    /// Badge text: exact count up to 9, then "9+".
    var badge: String? { unread == 0 ? nil : (unread > 9 ? "9+" : "\(unread)") }

    func refresh() async {
        if let n = try? await HRMSAPI.shared.notifications() { items = n }
    }

    func markRead(_ id: String) async {
        // Optimistic: flip locally, then persist.
        if let i = items.firstIndex(where: { $0.id == id }), !items[i].read {
            items[i] = items[i].markedRead()
        }
        try? await HRMSAPI.shared.markNotificationRead(id: id)
    }
}

private extension AppNotification {
    func markedRead() -> AppNotification {
        AppNotification(id: id, title: title, message: message, type: type,
                        read: true, link: link, createdAt: createdAt)
    }
}

/// The notifications list. Tapping a row marks it read (and, where the link
/// maps to an in-app screen, could route — kept as mark-read for now to stay
/// within the current tab structure).
struct NotificationsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @ObservedObject private var store = NotificationStore.shared
    @State private var loading = true

    var body: some View {
        GradientScreen {
            Group {
                if loading && store.items.isEmpty {
                    VStack { Spacer(); ProgressView().tint(Theme.premier); Spacer() }.frame(maxWidth: .infinity)
                } else if store.items.isEmpty {
                    EmptyHint(icon: "bell.slash", text: "No notifications yet.")
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(store.items) { n in row(n) }
                        }
                        .padding(20)
                    }
                    .refreshable { await store.refresh() }
                }
            }
        }
        .brandBar()
        .task {
            await store.refresh()
            loading = false
        }
    }

    private func row(_ n: AppNotification) -> some View {
        Button {
            Task { await store.markRead(n.id) }
            // Open the related screen (approvals, clock, leave…) when the link maps to one.
            let isAdmin = ["ADMIN", "HR", "MANAGER"].contains(auth.user?.primaryRole.uppercased() ?? "")
            if PushRoute.from(link: n.link, isAdmin: isAdmin, isIntern: auth.isIntern) != .notifications {
                PushManager.shared.pendingLink = n.link
            }
        } label: {
            Card {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle().fill(tint(n).opacity(0.22)).frame(width: 40, height: 40)
                        Image(systemName: icon(n)).foregroundStyle(tint(n))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(n.title)
                                .font(.subheadline.weight(n.read ? .regular : .bold))
                                .foregroundStyle(n.read ? Theme.ink.opacity(0.7) : Theme.ink)
                            Spacer()
                            Text(relative(n.createdAt)).font(.caption2).foregroundStyle(Theme.ink.opacity(0.5))
                        }
                        Text(n.message).font(.caption).foregroundStyle(Theme.ink.opacity(0.7)).lineLimit(2)
                    }
                    if !n.read {
                        Circle().fill(Theme.sky).frame(width: 8, height: 8).padding(.top, 6)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func icon(_ n: AppNotification) -> String {
        switch n.type {
        case "LEAVE_APPROVED": return "checkmark.circle.fill"
        case "LEAVE_REJECTED": return "xmark.circle.fill"
        case "OT_APPROVED": return "clock.badge.checkmark.fill"
        case "OT_REJECTED": return "clock.badge.xmark.fill"
        case "WOODS_SQUARE_APPROVED": return "door.left.hand.open"
        case "WOODS_SQUARE_DECLINED": return "door.left.hand.closed"
        case "ATTENDANCE_MISSED", "ATTENDANCE_ROLLUP": return "clock.badge.exclamationmark.fill"
        case "TIMESHEET_REMINDER": return "calendar.badge.clock"
        case "LEAVE_REQUEST", "EXPENSE_REQUEST", "TIME_OFF_REQUEST", "APPROVAL_REQUEST": return "tray.full.fill"
        case "EXPENSE_APPROVED", "TIME_OFF_APPROVED": return "checkmark.circle.fill"
        case "EXPENSE_REJECTED", "TIME_OFF_REJECTED": return "xmark.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private func tint(_ n: AppNotification) -> Color {
        switch n.type {
        case "LEAVE_APPROVED", "OT_APPROVED", "WOODS_SQUARE_APPROVED", "EXPENSE_APPROVED", "TIME_OFF_APPROVED": return Theme.success
        case "LEAVE_REJECTED", "OT_REJECTED", "WOODS_SQUARE_DECLINED", "EXPENSE_REJECTED", "TIME_OFF_REJECTED": return Theme.danger
        case "ATTENDANCE_MISSED", "ATTENDANCE_ROLLUP", "TIMESHEET_REMINDER": return Theme.warning
        default: return Theme.sky
        }
    }

    /// Compact relative time: now / 5m / 3h / 2d.
    private func relative(_ iso: String?) -> String {
        guard let d = Fmt.dateObj(iso) else { return "" }
        let s = Int(Date().timeIntervalSince(d))
        if s < 60 { return "now" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86400 { return "\(s / 3600)h" }
        return "\(s / 86400)d"
    }
}

/// The nav-bar bell with an unread badge. Presents the notifications list.
struct NotificationBell: View {
    @ObservedObject private var store = NotificationStore.shared
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill").foregroundStyle(Theme.ink)
                if let badge = store.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.navy950)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Theme.gold)
                        .clipShape(Capsule())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .navigationDestination(isPresented: $show) { NotificationsView() }
    }
}
