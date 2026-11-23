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
                        read: true, link: link, createdAt: createdAt, action: action)
    }
}

/// The notifications list. Tapping a row marks it read and opens the related screen. For an
/// approver, a request notice (leave, MC, time off, claim, No Pay Leave payback, missed punch)
/// carries Approve / Reject itself (Alfred, 23 Nov 2026: "the notice should not be just info only").
struct NotificationsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @ObservedObject private var store = NotificationStore.shared
    @State private var loading = true
    @State private var actingId: String?
    @State private var rejecting: AppNotification?
    @State private var rejectReason = ""
    @State private var errorMessage: String?

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
                            if let errorMessage { StatusBanner(kind: .error, text: errorMessage) }
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
        .alert("Reject request", isPresented: Binding(
            get: { rejecting != nil },
            set: { if !$0 { rejecting = nil; rejectReason = "" } }
        )) {
            TextField("Reason (optional)", text: $rejectReason)
            Button("Reject", role: .destructive) {
                if let n = rejecting {
                    let reason = rejectReason
                    rejecting = nil; rejectReason = ""
                    Task { await decide(n, approve: false, reason: reason) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(rejecting?.message ?? "")
        }
    }

    /// Approve / Reject on the notice: only approvers acting as themselves (not a role preview).
    private func action(_ n: AppNotification) -> NoticeAction? {
        auth.showsAdmin ? n.requestAction : nil
    }

    private func decide(_ n: AppNotification, approve: Bool, reason: String?) async {
        guard let a = action(n) else { return }
        actingId = n.id
        errorMessage = nil
        do {
            try await HRMSAPI.shared.decide(a, approve: approve, reason: reason)
            CalendarAutoSync.shared.kick()
            await store.markRead(n.id)
            // The server drops a decided request's notice; refresh so the list and badge follow.
            store.items.removeAll { $0.id == n.id }
            await store.refresh()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        actingId = nil
    }

    private func actionButtons(_ n: AppNotification) -> some View {
        HStack(spacing: 10) {
            Button { rejecting = n } label: {
                actionLabel("Reject", "xmark.circle.fill", Theme.danger, busy: false)
            }
            .accessibilityIdentifier("notice.reject.\(n.id)")
            Button { Task { await decide(n, approve: true, reason: nil) } } label: {
                actionLabel("Approve", "checkmark.circle.fill", Theme.success, busy: actingId == n.id)
            }
            .accessibilityIdentifier("notice.approve.\(n.id)")
        }
        .disabled(actingId != nil)
        .padding(.leading, 52)
    }

    private func actionLabel(_ title: String, _ icon: String, _ tint: Color, busy: Bool) -> some View {
        HStack(spacing: 6) {
            if busy { ProgressView().tint(tint).scaleEffect(0.8) } else { Image(systemName: icon) }
            Text(title).fontWeight(.semibold)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(tint.opacity(0.3), lineWidth: 1))
        .foregroundStyle(tint)
    }

    @ViewBuilder
    private func row(_ n: AppNotification) -> some View {
        if action(n) != nil {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    openButton(n, inCard: false)
                    actionButtons(n)
                }
            }
        } else {
            openButton(n, inCard: true)
        }
    }

    private func openButton(_ n: AppNotification, inCard: Bool) -> some View {
        Button {
            Task { await store.markRead(n.id) }
            // Open the related screen (approvals, clock, leave…) when the link maps to one.
            let isAdmin = ["ADMIN", "HR", "MANAGER"].contains(auth.user?.primaryRole.uppercased() ?? "")
            if PushRoute.from(link: n.link, isAdmin: isAdmin, mustClockIn: auth.mustClockIn) != .notifications {
                PushManager.shared.pendingLink = n.link
            }
        } label: {
            NoticeCardWrap(inCard: inCard) {
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
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("notice.\(n.id)")
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
        case "LEAVE_REQUEST", "EXPENSE_REQUEST", "TIME_OFF_REQUEST", "APPROVAL_REQUEST",
             "LEAVE_SUBMITTED", "TIME_OFF_SUBMITTED", "EXPENSE_SUBMITTED",
             "ATTENDANCE_CORRECTION_SUBMITTED": return "tray.full.fill"
        case "PAYBACK_SUBMITTED": return "arrow.uturn.backward.circle.fill"
        case "PAYBACK_APPROVED", "ATTENDANCE_CORRECTION_APPROVED": return "checkmark.circle.fill"
        case "PAYBACK_REJECTED", "ATTENDANCE_CORRECTION_REJECTED": return "xmark.circle.fill"
        case "EXPENSE_APPROVED", "TIME_OFF_APPROVED": return "checkmark.circle.fill"
        case "EXPENSE_REJECTED", "TIME_OFF_REJECTED": return "xmark.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private func tint(_ n: AppNotification) -> Color {
        switch n.type {
        case "LEAVE_APPROVED", "OT_APPROVED", "WOODS_SQUARE_APPROVED", "EXPENSE_APPROVED", "TIME_OFF_APPROVED",
             "PAYBACK_APPROVED", "ATTENDANCE_CORRECTION_APPROVED": return Theme.success
        case "LEAVE_REJECTED", "OT_REJECTED", "WOODS_SQUARE_DECLINED", "EXPENSE_REJECTED", "TIME_OFF_REJECTED",
             "PAYBACK_REJECTED", "ATTENDANCE_CORRECTION_REJECTED": return Theme.danger
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

/// The notice body in its own Card, or bare when the caller's Card also holds the action buttons.
private struct NoticeCardWrap<Content: View>: View {
    let inCard: Bool
    @ViewBuilder let content: () -> Content
    var body: some View {
        if inCard { Card { content() } } else { content() }
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
