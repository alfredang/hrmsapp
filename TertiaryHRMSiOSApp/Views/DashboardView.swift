import SwiftUI

/// Home tab — a snapshot pulled from /api/mobile/summary.
struct DashboardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var state: LoadState<DashboardSummary> = .idle

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { s in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        greeting(s)

                        if s.isAdmin {
                            sectionTitle("Approvals queue")
                            HStack(spacing: 12) {
                                NavigationLink(destination: ApprovalsView()) {
                                    StatTile(value: "\(s.pendingLeaves)", label: "Pending leave", icon: "calendar.badge.exclamationmark", tint: Theme.gold600)
                                }
                                NavigationLink(destination: ApprovalsView()) {
                                    StatTile(value: "\(s.pendingClaims)", label: "Pending claims", icon: "doc.badge.clock", tint: .orange)
                                }
                            }
                        }

                        sectionTitle("Quick actions")
                        HStack(spacing: 12) {
                            quickAction("Clock in / out", "clock.badge.checkmark.fill", Theme.gold600) { ClockView() }
                            quickAction("Snap a claim", "camera.fill", .orange) { NewClaimView() }
                        }

                        sectionTitle("My balances")
                        HStack(spacing: 12) {
                            StatTile(value: fmt(s.alAvailable), label: "Annual leave", icon: "sun.max.fill", tint: Theme.sky)
                            StatTile(value: fmt(s.mcAvailable), label: "Medical leave", icon: "cross.case.fill", tint: .pink)
                        }
                        HStack(spacing: 12) {
                            StatTile(value: fmt(s.otRemaining), label: "OT leave", icon: "clock.arrow.circlepath", tint: .teal)
                            StatTile(value: Fmt.money(s.expenseYtd), label: "Expenses YTD", icon: "creditcard.fill", tint: .green)
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar(bell: true)
        .task { await NotificationStore.shared.refresh() }
    }

    private func greeting(_ s: DashboardSummary) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome back").font(.subheadline).foregroundStyle(Theme.ink.opacity(0.75))
                Text(s.name ?? auth.user?.displayName ?? "Employee")
                    .font(.title.weight(.bold)).foregroundStyle(Theme.ink)
                Text(s.role?.capitalized ?? "")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.mist100.opacity(0.55)).clipShape(Capsule()).foregroundStyle(Theme.navy800)
            }
        }
    }

    private func quickAction<D: View>(_ title: String, _ icon: String, _ tint: Color,
                                      @ViewBuilder _ dest: () -> D) -> some View {
        NavigationLink(destination: dest()) {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: icon).foregroundStyle(tint)
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                }
            }
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.headline).foregroundStyle(Theme.ink.opacity(0.9))
    }

    private func fmt(_ v: Double?) -> String {
        guard let v else { return "—" }
        return v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    private func load() async {
        state = .loading
        do {
            let s = try await HRMSAPI.shared.summary()
            auth.canManageTrainers = s.showsTrainers
            state = .loaded(s)
        }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
