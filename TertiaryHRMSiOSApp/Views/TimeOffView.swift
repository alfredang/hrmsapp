import SwiftUI

/// Time Off — hourly time-off requests (exams / emergencies), mirroring the
/// web app's /time-off page. Lists the employee's own requests and lets them
/// raise a new one or cancel a pending one.
struct TimeOffView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var state: LoadState<[TimeOffRequest]> = .idle
    /// Approvers: "Mine" or "Team" (everyone's requests as a one-line table).
    @State private var scope: Scope = PreviewData.flag("team") ? .team : .mine
    @State private var team: LoadState<[TimeOffRequest]> = .idle
    @State private var teamStatus = "PENDING"
    @State private var openTeam: TimeOffRequest?
    private enum Scope: String, CaseIterable { case mine = "Mine", team = "Team" }
    private var isAdmin: Bool { ["ADMIN", "HR", "MANAGER"].contains(auth.user?.primaryRole.uppercased() ?? "") }
    @State private var requestSheet: RequestSheet?
    @State private var cancelTarget: TimeOffRequest?
    @State private var showCancelConfirm = false
    @State private var cancelling = false
    @State private var error: String?

    /// Sheet payload (Identifiable, house pattern — see LeaveView.ApplySheet).
    private struct RequestSheet: Identifiable { let id = UUID() }

    var body: some View {
        GradientScreen {
            VStack(spacing: 0) {
                if isAdmin {
                    Picker("Show", selection: $scope) {
                        ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20).padding(.top, 12)
                }
                if scope == .team { teamList } else { mine }
            }
        }
        .brandBar()
        .sheet(item: $openTeam) { r in
            RecordSheet(title: r.employeeName ?? "Time off", status: r.status, fields: TimeOffTable.fields(r),
                        longText: r.reasonText,
                        onApprove: r.status.uppercased() == "PENDING" ? { await decideTeam(r, approve: true, reason: nil) } : nil,
                        onReject: r.status.uppercased() == "PENDING" ? { reason in await decideTeam(r, approve: false, reason: reason) } : nil)
        }
        .sheet(item: $requestSheet, onDismiss: { Task { await load() } }) { _ in
            RequestTimeOffView()
                .preferredColorScheme(.light)
        }
        .alert("Cancel time off?", isPresented: $showCancelConfirm, presenting: cancelTarget) { r in
            Button("Cancel request", role: .destructive) { cancel(r) }
            Button("Keep request", role: .cancel) {}
        } message: { r in
            Text("Cancel your time off on \(Fmt.date(r.date)) (\(TimeOffView.time12(r.startTime)) – \(TimeOffView.time12(r.endTime)))?")
        }
    }

    // MARK: Team (approvers)

    private var teamList: some View {
        AsyncContent(state: $team, load: loadTeam) { all in
            let rows = teamStatus == "ALL" ? all : all.filter { $0.status.uppercased() == teamStatus }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Team time off").font(.headline).foregroundStyle(Theme.ink)
                        Spacer()
                        Menu {
                            Picker("Status", selection: $teamStatus) {
                                Text("Pending").tag("PENDING")
                                Text("Approved").tag("APPROVED")
                                Text("Rejected").tag("REJECTED")
                                Text("All").tag("ALL")
                            }
                        } label: {
                            Label(teamStatus == "ALL" ? "All" : teamStatus.capitalized,
                                  systemImage: "line.3.horizontal.decrease.circle")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.sky)
                        }
                    }
                    if let error { StatusBanner(kind: .error, text: error) }
                    if rows.isEmpty {
                        EmptyHint(icon: "hourglass", text: "No \(teamStatus == "ALL" ? "" : teamStatus.lowercased() + " ")time-off requests.")
                    } else {
                        TimeOffTable(rows: rows) { openTeam = $0 }
                        Text("Tap a request for the full reason and to approve or reject.")
                            .font(.caption).foregroundStyle(Theme.mist)
                    }
                }
                .padding(20)
            }
            .refreshable { await loadTeam() }
        }
    }

    private func decideTeam(_ r: TimeOffRequest, approve: Bool, reason: String?) async {
        error = nil
        do {
            try await HRMSAPI.shared.decide(.timeOff, id: r.id, approve: approve, reason: reason)
            CalendarAutoSync.shared.kick()
            await loadTeam()
        } catch { self.error = (error as NSError).localizedDescription }
    }

    private func loadTeam() async {
        if case .loaded = team {} else { team = .loading }
        do { team = .loaded(try await HRMSAPI.shared.allTimeOff()) }
        catch { team = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }

    // MARK: Mine

    private var mine: some View {
            AsyncContent(state: $state, load: load) { requests in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PremierButton(title: "Request Time Off", systemImage: "plus.circle.fill") {
                            requestSheet = RequestSheet()
                        }

                        if let error { StatusBanner(kind: .error, text: error) }

                        Text("My requests").font(.headline).foregroundStyle(Theme.ink.opacity(0.9))
                        if requests.isEmpty {
                            EmptyHint(icon: "hourglass", text: "No time-off requests yet.")
                        } else {
                            ForEach(requests) { r in requestRow(r) }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
    }

    private func requestRow(_ r: TimeOffRequest) -> some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Fmt.date(r.date)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text("\(TimeOffView.time12(r.startTime)) – \(TimeOffView.time12(r.endTime))")
                        .font(.caption).foregroundStyle(Theme.ink.opacity(0.7))
                    Text(reasonText(r))
                        .font(.caption2).foregroundStyle(Theme.ink.opacity(0.55)).lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    StatusPill(status: r.status)
                    Text(hoursText(r.hours)).font(.caption2).foregroundStyle(Theme.ink.opacity(0.7))
                }
            }
            if let reason = r.rejectionReason, !reason.isEmpty {
                Text("Rejected: \(reason)")
                    .font(.caption).foregroundStyle(Theme.danger)
                    .padding(.top, 6)
            }
            if let comment = r.approvalComment, !comment.isEmpty {
                Text(comment)
                    .font(.caption).foregroundStyle(Theme.ink.opacity(0.7))
                    .padding(.top, 6)
            }
            if r.status.uppercased() == "PENDING" {
                Button(role: .destructive) {
                    cancelTarget = r
                    showCancelConfirm = true
                } label: {
                    Label("Cancel request", systemImage: "xmark.circle")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(Theme.ink.opacity(0.1))
                        .foregroundStyle(Theme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(cancelling)
                .padding(.top, 8)
            }
        }
    }

    private func reasonText(_ r: TimeOffRequest) -> String {
        if let detail = r.reasonDetail, !detail.isEmpty { return "\(r.reasonLabel) — \(detail)" }
        return r.reasonLabel
    }

    private func hoursText(_ h: Double) -> String {
        let s = h.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", h) : String(format: "%.1f", h)
        return "\(s) hr\(h == 1 ? "" : "s")"
    }

    /// Converts an API "HH:mm" 24-hour time to a "2:00 PM" style display string.
    static func time12(_ s: String) -> String {
        hm24.date(from: s).map(hm12.string) ?? s
    }
    private static let hm24: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()
    private static let hm12: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f
    }()

    private func cancel(_ r: TimeOffRequest) {
        error = nil; cancelling = true
        Task {
            do {
                try await HRMSAPI.shared.cancelTimeOff(id: r.id)
                cancelling = false
                await load()
            } catch {
                cancelling = false
                self.error = (error as NSError).localizedDescription
            }
        }
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.timeOff()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
