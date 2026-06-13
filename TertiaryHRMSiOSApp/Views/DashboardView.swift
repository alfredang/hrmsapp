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
                                StatTile(value: "\(s.pendingLeaves)", label: "Pending leave", icon: "calendar.badge.exclamationmark", tint: .yellow)
                                StatTile(value: "\(s.pendingClaims)", label: "Pending claims", icon: "doc.badge.clock", tint: .orange)
                            }
                        }

                        sectionTitle("My balances")
                        HStack(spacing: 12) {
                            StatTile(value: fmt(s.alAvailable), label: "Annual leave", icon: "sun.max.fill", tint: Theme.sky)
                            StatTile(value: fmt(s.mcAvailable), label: "Medical leave", icon: "cross.case.fill", tint: .pink)
                        }
                        HStack(spacing: 12) {
                            StatTile(value: fmt(s.otRemaining), label: "OT leave", icon: "clock.arrow.circlepath", tint: .mint)
                            StatTile(value: Fmt.money(s.expenseYtd), label: "Expenses YTD", icon: "creditcard.fill", tint: .green)
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Dashboard")
    }

    private func greeting(_ s: DashboardSummary) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome back").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                Text(s.name ?? auth.user?.displayName ?? "Employee")
                    .font(.title.weight(.bold)).foregroundStyle(.white)
                Text(s.role?.capitalized ?? "")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.white.opacity(0.16)).clipShape(Capsule()).foregroundStyle(.white)
            }
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.headline).foregroundStyle(.white.opacity(0.9))
    }

    private func fmt(_ v: Double?) -> String {
        guard let v else { return "—" }
        return v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.summary()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
