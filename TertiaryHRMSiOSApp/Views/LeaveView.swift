import SwiftUI

/// Leave tab — balances, request history, and apply-for-leave.
struct LeaveView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var state: LoadState<LeaveResponse> = .idle
    @State private var applySheet: ApplySheet?

    /// Sheet payload carrying the leave types captured at tap time, so the
    /// sheet content never depends on re-matching `state` (a stale match
    /// presents an empty sheet).
    private struct ApplySheet: Identifiable {
        let id = UUID()
        let types: [LeaveType]
        let balances: [LeaveBalance]
    }

    private var loaded: LeaveResponse? {
        if case .loaded(let data) = state { return data }
        return nil
    }

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PremierButton(title: "Apply for Leave", systemImage: "plus.circle.fill") {
                            applySheet = ApplySheet(types: data.types, balances: data.balances)
                        }

                        if !data.balances.isEmpty {
                            Text("Balances").font(.headline).foregroundStyle(.white.opacity(0.9))
                            ForEach(data.balances) { b in
                                if b.isNoPayLeave { nplCard(b) } else { balanceCard(b) }
                            }
                        }

                        Text("My requests").font(.headline).foregroundStyle(.white.opacity(0.9))
                        if data.requests.isEmpty {
                            EmptyHint(icon: "calendar", text: "No leave requests yet.")
                        } else {
                            ForEach(data.requests) { LeaveRequestRow(request: $0) }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let data = loaded { applySheet = ApplySheet(types: data.types, balances: data.balances) }
                } label: { Image(systemName: "plus.circle.fill") }
                    .tint(Theme.sky)
                    .disabled(loaded == nil)
            }
        }
        .sheet(item: $applySheet, onDismiss: { Task { await load() } }) { sheet in
            ApplyLeaveView(types: sheet.types, balances: sheet.balances, isIntern: auth.isIntern)
                .preferredColorScheme(.dark)
        }
    }

    private func balanceCard(_ b: LeaveBalance) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(b.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(b.paid ? "Paid" : "Unpaid").font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Fmt.days(b.available)).font(.title3.weight(.bold))
                        .foregroundStyle(b.available < 0 ? .red : Theme.sky)
                    Text("available").font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
            }
            HStack(spacing: 16) {
                miniStat("Used", b.used)
                miniStat("Pending", b.pending)
                if b.carriedOver > 0 { miniStat("Carried", b.carriedOver) }
            }
            .padding(.top, 8)
        }
    }

    /// No Pay Leave: the server sends the prorated cap as `proRated` and what is left
    /// of it as `available` (21 days a year, prorated by months served).
    private func nplCard(_ b: LeaveBalance) -> some View {
        let cap = b.proRated ?? b.entitlement
        return Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(b.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text("Unpaid · capped").font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Fmt.days(b.available)).font(.title3.weight(.bold))
                        .foregroundStyle(b.available <= 0 ? .red : Theme.sky)
                    Text("remaining of \(Fmt.num(cap))").font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
            }
            if cap > 0 {
                ProgressView(value: min(max(cap - b.available, 0), cap), total: cap)
                    .tint(Theme.sky)
                    .padding(.top, 6)
            }
            HStack(spacing: 16) {
                // The balance row's used/pending can be stale; the server derives
                // `available` from the requests themselves, so booked = cap − remaining.
                miniStat("Cap to date", cap)
                miniStat("Booked", max(0, cap - b.available))
                miniStat("Remaining", b.available)
            }
            .padding(.top, 8)
            Text("No Pay Leave is capped at 21 days a year, prorated by the full months you have served.")
                .font(.caption2).foregroundStyle(.white.opacity(0.55))
                .padding(.top, 4)
        }
    }

    private func miniStat(_ label: String, _ v: Double) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.55))
            Text(v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v))
                .font(.footnote.weight(.semibold)).foregroundStyle(.white)
        }
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.leave()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
