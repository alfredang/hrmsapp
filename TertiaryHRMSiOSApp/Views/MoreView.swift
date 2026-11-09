import SwiftUI

/// More tab — the remaining modules, grouped: My work, Manage (approvers / Trainer Admins)
/// and Help (Feedback + About), then sign out.
/// Timesheets are intern-only: interns see "Timesheet", other staff see "Off In Lieu", and
/// approvers get the one admin "Timesheet" (intern hours + missing punches + Off In Lieu).
struct MoreView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var signingOut = false

    /// Approver roles (mirrors the web's `hasAdminAccess`).
    private var isAdmin: Bool { ["ADMIN", "HR", "MANAGER"].contains(auth.user?.primaryRole.uppercased() ?? "") }

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    group("My work") {
                        link("Clock In / Out", "clock.badge.checkmark.fill", Theme.gold600) { ClockView() }
                        if auth.isIntern {
                            divider
                            link("Timesheet", "tablecells", .teal) { MyTimesheetView() }
                        } else {
                            divider
                            link("Off In Lieu", "calendar.badge.plus", .teal) { WeeklyTimesheetView() }
                        }
                        divider
                        link("Time Off", "hourglass", Theme.sky) { TimeOffView() }
                        divider
                        link("Payslips", "doc.text.fill", Theme.success) { PayslipsView() }
                        divider
                        link("Expense claims", "creditcard.fill", .orange) { ExpensesView() }
                        divider
                        link("Calendar", "calendar", Theme.sky) { CalendarListView() }
                        divider
                        link("My profile", "person.crop.circle.fill", Theme.azure) { ProfileView() }
                    }

                    if isAdmin || auth.canManageTrainers {
                        group("Manage") {
                            if isAdmin {
                                link("Approvals", "checkmark.circle.fill", Theme.success) { ApprovalsView() }
                                divider
                                link("Timesheet", "person.badge.clock.fill", .teal) { TimesheetAdminView() }
                                divider
                                link("Leave & MC", "cross.case.fill", .pink) { LeaveSummaryView() }
                            }
                            if isAdmin && auth.canManageTrainers { divider }
                            if auth.canManageTrainers {
                                link("Trainer Management", "person.text.rectangle.fill", Theme.gold600) { TrainersView() }
                            }
                        }
                    }

                    group("Help") {
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
