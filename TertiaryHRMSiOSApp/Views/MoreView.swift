import SwiftUI

/// More tab = the web sidebar (Alfred, 22 Nov 2026): My Stuff, People, Processes, Finance,
/// Accounting, Documents and System, each row shown under the same rules as the web
/// (`src/components/layout/sidebar.tsx` `isVisible`), then Help and sign out. Screens the app
/// has natively open in the app; accounting, SOP and settings open the web page.
/// Departures from the web, by product decision: Clock In/Out only for people who must clock in
/// (never admins or staff), Approvals as its own row for admins, no Woods Square, no NPL Payback.
/// View As (approvers, Trainer Admins) sits on top; the Trainer Admin view shows My Stuff,
/// People → Trainers and Documents only (web TRAINER_VIEW_HREFS).
struct MoreView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var signingOut = false
    /// The leave form opened from Applications → MC / Leave, with the types loaded at tap time.
    @State private var applySheet: ApplySheet?
    @State private var loadingApply = false
    @State private var applyError: String?

    private struct ApplySheet: Identifiable {
        let id = UUID()
        let types: [LeaveType]
        let balances: [LeaveBalance]
        let code: String
    }

    /// One More row: pushes a screen, opens the leave form preset to a type, or opens a web page.
    private struct Row: Identifiable {
        enum Kind { case push(AnyView), apply(String), web(String) }
        let id: String
        let title: String
        let icon: String
        let tint: Color
        let kind: Kind
        init(_ id: String, _ title: String, _ icon: String, _ tint: Color, _ kind: Kind) {
            self.id = id; self.title = title; self.icon = icon; self.tint = tint; self.kind = kind
        }
        static func push<V: View>(_ id: String, _ title: String, _ icon: String, _ tint: Color, _ v: V) -> Row {
            Row(id, title, icon, tint, .push(AnyView(v)))
        }
    }

    /// The sections, as the web sidebar shows them for the current view.
    private var sections: [(title: String, rows: [Row])] {
        if auth.isTrainerView {
            return [
                ("My Stuff", [.push("profile", "My Profile", "person.crop.circle.fill", Theme.azure, ProfileView()),
                              .push("calendar", "Calendar", "calendar", Theme.sky, CalendarListView())]),
                ("People", [.push("trainers", "Trainers", "person.text.rectangle.fill", Theme.gold600, TrainersView())]),
                ("Documents", [.push("sop", "SOP", "book.fill", Theme.sky, SopListView())]),
            ]
        }
        let admin = auth.showsAdmin
        let accountant = auth.showsAccountant && !admin
        let intern = auth.showsIntern && !admin
        let staff = !admin && !accountant && !intern
        var people: [Row] = []
        if admin {
            people.append(.push("staff", "Staff", "person.2.fill", Theme.sky, TeamView(group: .staff)))
            people.append(.push("interns", "Interns", "person.badge.plus", Theme.sky, TeamView(group: .interns)))
        }
        if auth.canManageTrainers && !auth.isRolePreview {
            people.append(.push("trainers", "Trainers", "person.text.rectangle.fill", Theme.gold600, TrainersView()))
        } else {
            // Everyone can reach a trainer (app-only contact list; the directory is Trainer Admin's).
            people.append(.push("trainercontacts", "Trainer contacts", "person.crop.rectangle.stack.fill", Theme.gold600, TrainerContactsView()))
        }

        var processes: [Row] = []
        if admin {
            processes.append(.push("approvals", "Approvals", "checkmark.circle.fill", Theme.success, ApprovalsView()))
            processes.append(.push("leavemgmt", "Leave Management", "calendar.badge.clock", Theme.sky, LeaveSummaryView()))
            processes.append(.push("timeoff", "Time Off Approvals", "hourglass", .orange, TimeOffView()))
            processes.append(.push("timesheet", "Timesheet", "person.badge.clock.fill", .teal, TimesheetAdminView()))
        } else if !accountant {
            processes.append(Row("AL", "Annual Leave", "sun.max.fill", Theme.sky, .apply("AL")))
            processes.append(Row("MC", "Medical Leave", "cross.case.fill", .pink, .apply("MC")))
            processes.append(.push("timeoff", "Time Off Application", "hourglass", .orange, TimeOffView()))
        }
        if !admin && auth.showsMustClockIn {
            processes.append(.push("clock", "Clock In/Out", "clock.badge.checkmark.fill", Theme.gold600, ClockView()))
        }
        if intern || accountant {
            processes.append(.push("mytimesheet", "Timesheet", "tablecells", .teal, MyTimesheetView()))
        }
        if staff {
            processes.append(.push("offinlieu", "Off In Lieu", "calendar.badge.plus", .teal, WeeklyTimesheetView()))
        }

        var finance: [Row] = []
        if !intern { finance.append(.push("payslips", "Payslips", "doc.text.fill", Theme.success, PayslipsView())) }
        if admin {
            finance.append(.push("claims", "Claim Management", "creditcard.fill", .orange, ApprovalsView()))
        } else if !accountant {
            finance.append(.push("claims", "Expense Claims", "creditcard.fill", .orange, ExpensesView()))
        }

        var accounting: [Row] = []
        if admin || accountant {
            accounting = [
                Row("expensetracking", "Expense Tracking", "arrow.down.right", Theme.danger, .web("accounting/expense-tracking")),
                Row("incometracking", "Income Tracking", "arrow.up.right", Theme.success, .web("accounting/income-tracking")),
                Row("reconciliation", "Bank Reconciliation", "scale.3d", Theme.gold600, .web("accounting/reconciliation")),
                Row("statements", "Bank Statements", "folder.fill", Theme.sky, .web(Self.bankStatementsFolder)),
            ]
        }

        return [
            ("My Stuff", [.push("profile", "My Profile", "person.crop.circle.fill", Theme.azure, ProfileView()),
                          .push("calendar", "Calendar", "calendar", Theme.sky, CalendarListView())]),
            ("People", people),
            ("Processes", processes),
            ("Finance", finance),
            ("Accounting", accounting),
            ("Documents", [.push("sop", "SOP", "book.fill", Theme.sky, SopListView())]),
            ("System", admin ? [Row("settings", "Settings", "gearshape.fill", Theme.mist, .web("settings"))] : []),
        ]
    }

    /// Web sidebar "Bank Statements": the shared Drive folder of DBS statements.
    static let bankStatementsFolder = "https://drive.google.com/drive/u/1/folders/1U6MCWuKZQ4wWZqn36AVHUeOD7a-URAaY"

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    if auth.availableViews.count > 1 { viewAsControl }

                    ForEach(sections.filter { !$0.rows.isEmpty }, id: \.title) { section in
                        rowGroup(section.title, section.rows)
                    }

                    group("Help") {
                        link("iPhone Calendar sync", "calendar.badge.checkmark", Theme.premier) { CalendarSyncSettingsView() }
                        divider
                        link("Feedback", "bubble.left.and.bubble.right.fill", Theme.sky) { FeedbackView() }
                        divider
                        link("About", "info.circle.fill", Theme.sky) { AboutView() }
                    }

                    signOut
                    Text("TIA HRMS · v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1")")
                        .font(.caption2).foregroundStyle(Theme.mist)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }
                .padding(20)
            }
        }
        .brandBar()
        .task { await auth.refreshCapabilities() }
        .sheet(item: $applySheet) { sheet in
            ApplyLeaveView(types: sheet.types, balances: sheet.balances, isIntern: auth.isIntern,
                           initialTypeCode: sheet.code)
        }
        .alert("Could not open the form", isPresented: Binding(get: { applyError != nil },
                                                               set: { if !$0 { applyError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(applyError ?? "") }
    }

    /// View As: approvers get the menu (Admin / Staff / Intern / Accountant / Trainer Admin);
    /// Trainer Admins who are not approvers keep the two-way control (My view / Trainer Admin).
    private var viewAsControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VIEW AS")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.mist)
                .padding(.leading, 6)
                .accessibilityAddTraits(.isHeader)
            if auth.isApprover {
                ViewAsMenu(id: "more.viewAs")
            } else {
                Card(padding: 10) {
                    Picker("View as", selection: $auth.viewAs) {
                        ForEach(auth.availableViews) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("more.viewAs")
                }
            }
        }
    }

    private var header: some View {
        Card {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.accent).frame(width: 52, height: 52)
                    Text(auth.user?.initials ?? "?").font(.headline.weight(.bold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(auth.user?.displayName ?? "Employee").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(auth.user?.email ?? "").font(.caption).foregroundStyle(Theme.mist)
                }
                Spacer()
            }
        }
    }

    private func rowGroup(_ title: String, _ rows: [Row]) -> some View {
        group(title) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                if i > 0 { divider }
                switch row.kind {
                case .push(let view):
                    link(row.title, row.icon, row.tint) { view }
                        .accessibilityIdentifier("more.row.\(row.id)")
                case .apply(let code):
                    action(row.title, row.icon, row.tint) { await openApply(code) }
                        .accessibilityIdentifier("more.apply.\(code)")
                case .web(let path):
                    webLink(row.title, row.icon, row.tint, path)
                        .accessibilityIdentifier("more.row.\(row.id)")
                }
            }
        }
    }

    /// A row that opens a web page (the HRMS web app, or a full URL) in Safari.
    private func webLink(_ title: String, _ icon: String, _ tint: Color, _ path: String) -> some View {
        let url = path.hasPrefix("http") ? URL(string: path)! : AuthService.baseURL.appendingPathComponent(path)
        return Link(destination: url) {
            HStack(spacing: 14) {
                Image(systemName: icon).foregroundStyle(tint).frame(width: 26)
                Text(title).foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "arrow.up.right.square").font(.caption).foregroundStyle(Theme.mist.opacity(0.7))
            }
            .padding(.horizontal, 12).padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .accessibilityHint("Opens the web page")
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.mist)
                .padding(.leading, 6)
                .accessibilityAddTraits(.isHeader)
            Card(padding: 6) { VStack(spacing: 0) { content() } }
        }
    }

    private func link<D: View>(_ title: String, _ icon: String, _ tint: Color, @ViewBuilder _ dest: () -> D) -> some View {
        NavigationLink(destination: dest()) {
            HStack(spacing: 14) {
                Image(systemName: icon).foregroundStyle(tint).frame(width: 26)
                Text(title).foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.mist.opacity(0.6))
            }
            .padding(.horizontal, 12).padding(.vertical, 14)
            .contentShape(Rectangle())
        }
    }

    /// A row that runs an action (opens a sheet) instead of pushing a screen.
    private func action(_ title: String, _ icon: String, _ tint: Color, _ run: @escaping () async -> Void) -> some View {
        Button { Task { await run() } } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).foregroundStyle(tint).frame(width: 26)
                Text(title).foregroundStyle(Theme.ink)
                Spacer()
                if loadingApply { ProgressView().controlSize(.small) }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.mist.opacity(0.6))
            }
            .padding(.horizontal, 12).padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(loadingApply)
    }

    /// Load the leave types / balances, then open the leave form preselected on `code`.
    private func openApply(_ code: String) async {
        loadingApply = true
        defer { loadingApply = false }
        do {
            let data = try await HRMSAPI.shared.leave()
            applySheet = ApplySheet(types: data.types, balances: data.balances, code: code)
        } catch {
            applyError = (error as? LocalizedError)?.errorDescription ?? "Please try again."
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.cardBorder).frame(height: 1).padding(.leading, 52)
    }

    private var signOut: some View {
        Button {
            signingOut = true
            Task { await auth.signOut(); signingOut = false }
        } label: {
            HStack(spacing: 8) {
                if signingOut { ProgressView().tint(Theme.danger) }
                else { Image(systemName: "rectangle.portrait.and.arrow.right") }
                Text("Sign out").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).frame(height: Theme.controlHeight)
            .foregroundStyle(Theme.danger).background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).stroke(Theme.danger.opacity(0.25), lineWidth: 1))
        }
        .disabled(signingOut)
    }
}

// MARK: - Help: Feedback + About (house style)

/// Feedback: title + message, sent to the Tertiary Infotech WhatsApp line.
struct FeedbackView: View {
    @State private var title = ""
    @State private var message = ""
    @Environment(\.openURL) private var openURL

    private var canSend: Bool { !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Feedback").font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                    Text("Tell us what to improve in TIA HRMS. Your note opens in WhatsApp, ready to send.")
                        .font(.subheadline).foregroundStyle(Theme.mist)
                    PremierField(title: "Title", systemImage: "textformat", text: $title)
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Message").foregroundStyle(Theme.mist.opacity(0.7))
                                .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                        TextEditor(text: $message)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                    }
                    .frame(minHeight: 160)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).stroke(Theme.fieldBorder, lineWidth: 1))
                    PremierButton(title: "Send via WhatsApp", systemImage: "paperplane.fill", enabled: canSend) {
                        if let url = Self.whatsAppURL(title: title, message: message) { openURL(url) }
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .brandBar()
    }

    /// `https://wa.me/6588666375?text=…`, percent-encoded via URLComponents.
    static func whatsAppURL(title: String, message: String) -> URL? {
        var comps = URLComponents(string: "https://wa.me/6588666375")
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = ["TIA HRMS (iOS) feedback", t.isEmpty ? nil : t, m].compactMap { $0 }.joined(separator: "\n\n")
        comps?.queryItems = [URLQueryItem(name: "text", value: text)]
        return comps?.url
    }
}

/// About: the app, the developer and the version.
struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "—"
        let b = info?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("About").font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                    Card {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.brand)
                                    .frame(width: 56, height: 56)
                                Image(systemName: "person.2.fill").font(.title2.weight(.bold)).foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TIA HRMS").font(.headline).foregroundStyle(Theme.ink)
                                Text("Leave, MC, claims, payslips, timesheets and approvals for Tertiary Infotech Academy staff and interns.")
                                    .font(.footnote).foregroundStyle(Theme.mist)
                            }
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Developer").font(.caption.weight(.semibold)).foregroundStyle(Theme.mist)
                            Text("Tertiary Infotech Academy Pte Ltd").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            Link("tertiaryinfotech.com", destination: URL(string: "https://www.tertiaryinfotech.com")!)
                                .font(.subheadline).tint(Theme.sky)
                        }
                    }
                    Card {
                        HStack {
                            Text("Version").font(.subheadline).foregroundStyle(Theme.mist)
                            Spacer()
                            Text(version).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                        }
                    }
                }
                .padding(20)
            }
        }
        .brandBar()
    }
}
