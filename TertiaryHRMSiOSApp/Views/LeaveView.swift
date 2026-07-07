import SwiftUI

/// Leave tab — balances, request history, and apply-for-leave.
struct LeaveView: View {
    @State private var state: LoadState<LeaveResponse> = .idle
    @State private var applySheet: ApplySheet?

    /// Sheet payload carrying the leave types captured at tap time, so the
    /// sheet content never depends on re-matching `state` (a stale match
    /// presents an empty sheet).
    private struct ApplySheet: Identifiable {
        let id = UUID()
        let types: [LeaveType]
    }

    private var loadedTypes: [LeaveType]? {
        if case .loaded(let data) = state { return data.types }
        return nil
    }

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PremierButton(title: "Apply for Leave", systemImage: "plus.circle.fill") {
                            applySheet = ApplySheet(types: data.types)
                        }

                        if !data.balances.isEmpty {
                            Text("Balances").font(.headline).foregroundStyle(.white.opacity(0.9))
                            ForEach(data.balances) { b in balanceCard(b) }
                        }

                        Text("My requests").font(.headline).foregroundStyle(.white.opacity(0.9))
                        if data.requests.isEmpty {
                            EmptyHint(icon: "calendar", text: "No leave requests yet.")
                        } else {
                            ForEach(data.requests) { r in requestRow(r) }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Leave")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let types = loadedTypes { applySheet = ApplySheet(types: types) }
                } label: { Image(systemName: "plus.circle.fill") }
                    .tint(Theme.sky)
                    .disabled(loadedTypes == nil)
            }
        }
        .sheet(item: $applySheet, onDismiss: { Task { await load() } }) { sheet in
            ApplyLeaveView(types: sheet.types)
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

    private func miniStat(_ label: String, _ v: Double) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.55))
            Text(v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v))
                .font(.footnote.weight(.semibold)).foregroundStyle(.white)
        }
    }

    private func requestRow(_ r: LeaveRequest) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.leaveType).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text("\(Fmt.date(r.startDate)) → \(Fmt.date(r.endDate))")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    if let reason = r.reason, !reason.isEmpty {
                        Text(reason).font(.caption2).foregroundStyle(.white.opacity(0.55)).lineLimit(2)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    StatusPill(status: r.status)
                    Text(Fmt.days(r.days)).font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.leave()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
