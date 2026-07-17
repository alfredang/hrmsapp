import SwiftUI

/// Approvals queue (MANAGER/HR/ADMIN) — pending leave requests and expense
/// claims from /api/mobile/approvals, with approve / reject actions that call
/// the existing web routes.
struct ApprovalsView: View {
    @State private var state: LoadState<ApprovalsResponse> = .idle
    @State private var actingId: String? = nil
    @State private var rejecting: RejectTarget? = nil
    @State private var rejectReason = ""
    @State private var errorMessage: String? = nil

    private struct RejectTarget: Identifiable {
        let kind: HRMSAPI.ApprovalKind
        let id: String
        let who: String
    }

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { a in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let errorMessage {
                            StatusBanner(kind: .error, text: errorMessage)
                        }

                        sectionTitle("Pending leave (\(a.leaves.count))")
                        if a.leaves.isEmpty {
                            emptyCard("No leave requests waiting.")
                        }
                        ForEach(a.leaves) { r in leaveCard(r) }

                        sectionTitle("Pending claims (\(a.claims.count))")
                        if a.claims.isEmpty {
                            emptyCard("No expense claims waiting.")
                        }
                        ForEach(a.claims) { c in claimCard(c) }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Approvals")
        .alert("Reject request", isPresented: Binding(
            get: { rejecting != nil },
            set: { if !$0 { rejecting = nil; rejectReason = "" } }
        )) {
            TextField("Reason (optional)", text: $rejectReason)
            Button("Reject", role: .destructive) {
                if let t = rejecting {
                    let reason = rejectReason
                    rejecting = nil; rejectReason = ""
                    Task { await decide(t.kind, id: t.id, approve: false, reason: reason) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reject \(rejecting?.who ?? "this")'s request?")
        }
    }

    // MARK: Cards

    private func leaveCard(_ r: PendingLeave) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(r.employee).font(.headline).foregroundStyle(.white)
                    Spacer()
                    Text(Fmt.days(r.days))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.yellow.opacity(0.22)).clipShape(Capsule())
                        .foregroundStyle(.yellow)
                }
                Text(r.leaveType).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.sky)
                Text(dateRange(r.startDate, r.endDate))
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                if let reason = r.reason, !reason.isEmpty {
                    Text(reason).font(.footnote).foregroundStyle(.white.opacity(0.65))
                }
                actionRow(.leave, id: r.id, who: r.employee)
            }
        }
    }

    private func claimCard(_ c: PendingClaim) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(c.employee).font(.headline).foregroundStyle(.white)
                    Spacer()
                    Text(Fmt.money(c.amount))
                        .font(.subheadline.weight(.bold)).foregroundStyle(.orange)
                }
                if let category = c.category {
                    Text(category).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.sky)
                }
                Text(c.description).font(.subheadline).foregroundStyle(.white.opacity(0.85))
                Text(Fmt.date(c.expenseDate)).font(.footnote).foregroundStyle(.white.opacity(0.65))
                actionRow(.claim, id: c.id, who: c.employee)
            }
        }
    }

    private func actionRow(_ kind: HRMSAPI.ApprovalKind, id: String, who: String) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await decide(kind, id: id, approve: true, reason: nil) }
            } label: {
                actionLabel("Approve", "checkmark.circle.fill", .green, busy: actingId == id)
            }
            Button {
                rejecting = RejectTarget(kind: kind, id: id, who: who)
            } label: {
                actionLabel("Reject", "xmark.circle.fill", .red, busy: false)
            }
        }
        .disabled(actingId != nil)
    }

    private func actionLabel(_ title: String, _ icon: String, _ tint: Color, busy: Bool) -> some View {
        HStack(spacing: 6) {
            if busy { ProgressView().tint(.white).scaleEffect(0.8) }
            else { Image(systemName: icon) }
            Text(title).fontWeight(.semibold)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(tint.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(tint.opacity(0.5), lineWidth: 1))
        .foregroundStyle(.white)
    }

    private func emptyCard(_ text: String) -> some View {
        Card {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text(text).font(.subheadline).foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.headline).foregroundStyle(.white.opacity(0.9))
    }

    private func dateRange(_ start: String?, _ end: String?) -> String {
        let s = Fmt.date(start), e = Fmt.date(end)
        return s == e ? s : "\(s) → \(e)"
    }

    // MARK: Actions

    private func decide(_ kind: HRMSAPI.ApprovalKind, id: String, approve: Bool, reason: String?) async {
        actingId = id
        errorMessage = nil
        do {
            try await HRMSAPI.shared.decide(kind, id: id, approve: approve, reason: reason)
            await load()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        actingId = nil
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.approvals()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
