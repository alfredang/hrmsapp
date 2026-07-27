import SwiftUI

/// More tab — entry points to the remaining modules + sign out.
struct MoreView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var signingOut = false

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    Card(padding: 6) {
                        VStack(spacing: 0) {
                            link("Payslips", "doc.text.fill", .green) { PayslipsView() }
                            divider
                            link("Expense claims", "creditcard.fill", .orange) { ExpensesView() }
                            divider
                            link("Calendar", "calendar", Theme.sky) { CalendarListView() }
                            divider
                            link("Clock In / Out", "clock.badge.checkmark.fill", .yellow) { ClockView() }
                            divider
                            link("Timesheet", "tablecells.badge.ellipsis", .mint) { WeeklyTimesheetView() }
                            divider
                            link("Time Off", "hourglass", .purple) { TimeOffView() }
                            divider
                            link("My profile", "person.crop.circle.fill", Theme.azure) { ProfileView() }
                        }
                    }
                    signOut
                    Text("Tertiary HRMS · v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1")")
                        .font(.caption2).foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 6)
                }
                .padding(20)
            }
        }
        .brandBar()
    }

    private var header: some View {
        Card {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.accent).frame(width: 52, height: 52)
                    Text(auth.user?.initials ?? "?").font(.headline.weight(.bold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(auth.user?.displayName ?? "Employee").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(auth.user?.email ?? "").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
            }
        }
    }

    private func link<D: View>(_ title: String, _ icon: String, _ tint: Color, @ViewBuilder _ dest: () -> D) -> some View {
        NavigationLink(destination: dest()) {
            HStack(spacing: 14) {
                Image(systemName: icon).foregroundStyle(tint).frame(width: 26)
                Text(title).foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 12).padding(.vertical, 15)
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.leading, 52)
    }

    private var signOut: some View {
        Button {
            signingOut = true
            Task { await auth.signOut(); signingOut = false }
        } label: {
            HStack(spacing: 8) {
                if signingOut { ProgressView().tint(.white) }
                else { Image(systemName: "rectangle.portrait.and.arrow.right") }
                Text("Sign out").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).frame(height: Theme.controlHeight)
            .foregroundStyle(.white).background(.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 1))
        }
        .disabled(signingOut)
    }
}
