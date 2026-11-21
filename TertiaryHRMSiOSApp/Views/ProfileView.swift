import SwiftUI

/// My profile — full employee record from /api/mobile/profile.
struct ProfileView: View {
    @State private var state: LoadState<ProfileResponse> = .idle
    /// The record the Edit sheet works on, captured when Edit is tapped. The sheet used to read
    /// `state`, and drew nothing (a blank white sheet) whenever the profile was reloading.
    @State private var editing: EditTarget?
    private struct EditTarget: Identifiable { let id = UUID(); let employee: EmployeeProfile }
    @State private var showPassword = false

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                if let e = data.employee {
                    ScrollView {
                        VStack(spacing: 18) {
                            avatar(e)
                            HStack(spacing: 10) {
                                actionButton("Edit profile", "square.and.pencil") { editing = EditTarget(employee: e) }
                                actionButton("Password", "lock.fill") { showPassword = true }
                            }
                            Card {
                                detail("Employee ID", e.employeeId)
                                detail("Email", e.email)
                                detail("Phone", e.phone ?? "—")
                                detail("Position", e.position ?? "—")
                                detail("Department", e.department ?? "—")
                                detail("Employment", e.employmentType.capitalized)
                            }
                            if let rows = e.workSchedule { workScheduleCard(rows) }
                            Card {
                                detail("Nationality", e.nationality)
                                detail("Gender", e.gender.capitalized)
                                detail("Date of birth", Fmt.date(e.dateOfBirth))
                                detail("Joined", Fmt.date(e.startDate))
                                detail("Status", e.status.capitalized, last: true)
                            }
                            AppearanceCard()
                        }
                        .padding(20)
                    }
                    .refreshable { await load() }
                } else {
                    EmptyHint(icon: "person.crop.circle.badge.exclamationmark", text: "No profile linked to this account.")
                }
            }
        }
        .brandBar()
        .sheet(item: $editing) { target in
            EditProfileView(employee: target.employee) { Task { await load() } }
        }
        .sheet(isPresented: $showPassword) { ChangePasswordView() }
    }

    private func actionButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Theme.ink.opacity(0.1)).foregroundStyle(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.ink.opacity(0.18), lineWidth: 1))
        }
    }

    private func avatar(_ e: EmployeeProfile) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accent).frame(width: 88, height: 88)
                Text(initials(e.name)).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }
            .shadow(color: Theme.premier.opacity(0.5), radius: 14, y: 8)
            Text(e.name).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            Text(e.roles.joined(separator: " · "))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Theme.ink.opacity(0.16)).clipShape(Capsule()).foregroundStyle(Theme.ink)
        }
    }

    /// Work Schedule (the web My Profile card, 20 Nov 2026): title, department, working hours,
    /// working days and off days, from `/api/mobile/profile`.
    private func workScheduleCard(_ rows: [(label: String, value: String, icon: String)]) -> some View {
        Card {
            Text("Work Schedule").font(.headline).foregroundStyle(Theme.ink).padding(.bottom, 4)
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: r.icon).font(.subheadline).foregroundStyle(Theme.sky).frame(width: 22)
                        Text(r.label).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.7))
                        Spacer()
                        Text(r.value).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 11)
                    .accessibilityElement(children: .combine)
                    if i < rows.count - 1 { Rectangle().fill(Theme.ink.opacity(0.08)).frame(height: 1) }
                }
            }
        }
        .accessibilityIdentifier("profile.workSchedule")
    }

    private func detail(_ label: String, _ value: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.7))
                Spacer()
                Text(value).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 11)
            if !last { Rectangle().fill(Theme.ink.opacity(0.08)).frame(height: 1) }
        }
    }

    private func initials(_ name: String) -> String {
        String(name.split(separator: " ").prefix(2).compactMap { $0.first }).uppercased()
    }

    private func load() async {
        // Keep the shown profile while refreshing (after a save, pull to refresh).
        if case .loaded = state {} else { state = .loading }
        do { state = .loaded(try await HRMSAPI.shared.profile()) }
        catch { if case .loaded = state { return }; state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
