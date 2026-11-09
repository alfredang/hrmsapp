import SwiftUI

/// Approvals queue (MANAGER/HR/ADMIN): pending leave (incl. MC), hourly time off and expense
/// claims. Leave and time off are one-line tables — name, status, type, dates, days, applied,
/// then the reason (truncated); tap a row for the full record and Approve / Reject.
/// Leave + claims: /api/mobile/approvals; time off: /api/time-off (approvers get everyone's).
/// Actions call the existing web routes; the server enforces the role.
struct ApprovalsView: View {
    @State private var state: LoadState<ApprovalsResponse> = .idle
    @State private var timeOff: [TimeOffRequest] = []
    @State private var actingId: String? = nil
    @State private var rejecting: RejectTarget? = nil
    @State private var rejectReason = ""
    @State private var errorMessage: String? = nil
    @State private var openLeave: PendingLeave?
    @State private var openTimeOff: TimeOffRequest?

    private struct RejectTarget: Identifiable {
        let kind: HRMSAPI.ApprovalKind
        let id: String
        let who: String
    }

    private var pendingTimeOff: [TimeOffRequest] { timeOff.filter { $0.status.uppercased() == "PENDING" } }

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { a in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Approvals").font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                        if let errorMessage {
                            StatusBanner(kind: .error, text: errorMessage)
                        }

                        CollapsibleSection(title: "Leave & MC", icon: "calendar.badge.exclamationmark",
                                           count: a.leaves.count, countIsAttention: true) {
                            if a.leaves.isEmpty {
                                emptyCard("No leave requests waiting.")
                            } else {
                                LeaveRequestTable(rows: a.leaves.map(LeaveRow.init)) { row in
                                    openLeave = a.leaves.first { $0.id == row.id }
                                }
                            }
                        }

                        CollapsibleSection(title: "Time off", icon: "hourglass",
                                           count: pendingTimeOff.count, countIsAttention: true) {
                            if pendingTimeOff.isEmpty {
                                emptyCard("No time-off requests waiting.")
                            } else {
                                TimeOffTable(rows: pendingTimeOff) { openTimeOff = $0 }
                            }
                        }

                        CollapsibleSection(title: "Expense claims", icon: "creditcard.fill",
                                           count: a.claims.count, countIsAttention: true) {
                            if a.claims.isEmpty {
                                emptyCard("No expense claims waiting.")
                            }
                            ForEach(a.claims) { c in claimCard(c) }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
        .sheet(item: $openLeave) { r in
            RecordSheet(title: r.employee, status: "PENDING", fields: LeaveRow(r).fields,
                        longText: r.reason,
                        onApprove: { await decide(.leave, id: r.id, approve: true, reason: nil) },
                        onReject: { reason in await decide(.leave, id: r.id, approve: false, reason: reason) })
        }
        .sheet(item: $openTimeOff) { r in
            RecordSheet(title: r.employeeName ?? "Time off", status: r.status, fields: TimeOffTable.fields(r),
                        longText: r.reasonText,
                        onApprove: { await decide(.timeOff, id: r.id, approve: true, reason: nil) },
                        onReject: { reason in await decide(.timeOff, id: r.id, approve: false, reason: reason) })
        }
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

    // MARK: Claims (cards — amount and receipt matter more than a one-line row here)

    private func claimCard(_ c: PendingClaim) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(c.employee).font(.headline).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(Fmt.money(c.amount))
                        .font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                }
                Text([c.category, Fmt.date(c.expenseDate)].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(Theme.mist)
                Text(c.description).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85)).lineLimit(2)
                actionRow(.claim, id: c.id, who: c.employee)
            }
        }
    }

    private func actionRow(_ kind: HRMSAPI.ApprovalKind, id: String, who: String) -> some View {
        HStack(spacing: 12) {
            Button {
                rejecting = RejectTarget(kind: kind, id: id, who: who)
            } label: {
                actionLabel("Reject", "xmark.circle.fill", Theme.danger, busy: false)
            }
            Button {
                Task { await decide(kind, id: id, approve: true, reason: nil) }
            } label: {
                actionLabel("Approve", "checkmark.circle.fill", Theme.success, busy: actingId == id)
            }
        }
        .disabled(actingId != nil)
    }

    private func actionLabel(_ title: String, _ icon: String, _ tint: Color, busy: Bool) -> some View {
        HStack(spacing: 6) {
            if busy { ProgressView().tint(tint).scaleEffect(0.8) }
            else { Image(systemName: icon) }
            Text(title).fontWeight(.semibold)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(tint.opacity(0.3), lineWidth: 1))
        .foregroundStyle(tint)
    }

    private func emptyCard(_ text: String) -> some View {
        Card {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.success)
                Text(text).font(.subheadline).foregroundStyle(Theme.mist)
            }
        }
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
        if case .loaded = state {} else { state = .loading }
        // Time off is best-effort (a failure must not hide the leave queue); both land together.
        async let t = try? HRMSAPI.shared.allTimeOff()
        async let a = HRMSAPI.shared.approvals()
        do {
            let approvals = try await a
            timeOff = await t ?? []
            state = .loaded(approvals)
        } catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}

// MARK: - One-line leave table (shared by Approvals and Leave & MC)

/// A leave / MC request flattened for a one-line row.
struct LeaveRow: Identifiable {
    let id: String
    let name: String
    let status: String
    let type: String
    let start: String?
    let end: String?
    let days: Double
    var applied: String? = nil
    var reason: String? = nil
    var extra: [RecordField] = []

    init(id: String, name: String, status: String, type: String, start: String?, end: String?,
         days: Double, applied: String? = nil, reason: String? = nil, extra: [RecordField] = []) {
        self.id = id; self.name = name; self.status = status; self.type = type; self.start = start
        self.end = end; self.days = days; self.applied = applied; self.reason = reason; self.extra = extra
    }

    init(_ r: PendingLeave) {
        self.init(id: r.id, name: r.employee, status: "PENDING", type: r.leaveType, start: r.startDate,
                  end: r.endDate, days: r.days, applied: r.createdAt, reason: r.reason,
                  extra: r.dayType == "FULL_DAY" ? [] : [RecordField(label: "Day type", value: r.dayType.replacingOccurrences(of: "_", with: " ").capitalized)]
                    + (r.documentUrl == nil ? [] : [RecordField(label: "Certificate", value: "Attached")]))
    }

    var fields: [RecordField] {
        [RecordField(label: "Type", value: type),
         RecordField(label: "Dates", value: Fmt.range(start, end)),
         RecordField(label: "Days", value: Fmt.days(days))]
        + (applied.map { [RecordField(label: "Applied", value: Fmt.date($0))] } ?? [])
        + extra
    }
}

/// Name · Status · Type · Dates · Days · Applied · Reason — one line per request.
struct LeaveRequestTable: View {
    let rows: [LeaveRow]
    var showApplied = true
    let onTap: (LeaveRow) -> Void

    private var columns: [OneLineColumn] {
        var c = [OneLineColumn(id: "Status", width: 76),
                 OneLineColumn(id: "Type", width: 112),
                 OneLineColumn(id: "Dates", width: 118),
                 OneLineColumn(id: "Days", width: 44, alignment: .trailing)]
        if showApplied {
            c += [OneLineColumn(id: "Applied", width: 70), OneLineColumn(id: "Reason", width: 200)]
        }
        return c
    }

    var body: some View {
        OneLineTable(rows: rows, columns: columns, name: \.name) { r, col in
            switch col.id {
            case "Status": StatusPill(status: r.status)
            case "Type": TableText(text: r.type)
            case "Dates": TableText(text: Fmt.range(r.start, r.end))
            case "Days": TableText(text: Fmt.num(r.days), bold: true)
            case "Applied": TableText(text: Fmt.shortDay(r.applied), secondary: true)
            default: TableText(text: (r.reason?.isEmpty == false ? r.reason : nil) ?? "—", secondary: true)
            }
        } onTap: { onTap($0) }
    }
}

/// Name · Status · Date · Time · Hours · Applied · Reason — one line per time-off request.
struct TimeOffTable: View {
    let rows: [TimeOffRequest]
    let onTap: (TimeOffRequest) -> Void

    var body: some View {
        OneLineTable(rows: rows, columns: [
            OneLineColumn(id: "Status", width: 76),
            OneLineColumn(id: "Date", width: 84),
            OneLineColumn(id: "Time", width: 124),
            OneLineColumn(id: "Hours", width: 48, alignment: .trailing),
            OneLineColumn(id: "Applied", width: 70),
            OneLineColumn(id: "Reason", width: 200),
        ], name: { $0.employeeName ?? "—" }) { r, col in
            switch col.id {
            case "Status": StatusPill(status: r.status)
            case "Date": TableText(text: Fmt.shortDay(r.date))
            case "Time": TableText(text: "\(TimeOffView.time12(r.startTime)) – \(TimeOffView.time12(r.endTime))")
            case "Hours": TableText(text: Fmt.num(r.hours), bold: true)
            case "Applied": TableText(text: Fmt.shortDay(r.createdAt), secondary: true)
            default: TableText(text: r.reasonText, secondary: true)
            }
        } onTap: { onTap($0) }
    }

    static func fields(_ r: TimeOffRequest) -> [RecordField] {
        [RecordField(label: "Date", value: Fmt.date(r.date)),
         RecordField(label: "Time", value: "\(TimeOffView.time12(r.startTime)) – \(TimeOffView.time12(r.endTime))"),
         RecordField(label: "Hours", value: Fmt.num(r.hours)),
         RecordField(label: "Applied", value: Fmt.date(r.createdAt))]
        + (r.rejectionReason.map { [RecordField(label: "Rejection reason", value: $0)] } ?? [])
    }
}
