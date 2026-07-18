import SwiftUI

/// My profile — full employee record from /api/mobile/profile.
struct ProfileView: View {
    @State private var state: LoadState<ProfileResponse> = .idle
    @State private var showEdit = false
    @State private var showPassword = false

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                if let e = data.employee {
                    ScrollView {
                        VStack(spacing: 18) {
                            avatar(e)
                            HStack(spacing: 10) {
                                actionButton("Edit profile", "square.and.pencil") { showEdit = true }
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
                            Card {
                                detail("Nationality", e.nationality)
                                detail("Gender", e.gender.capitalized)
                                detail("Date of birth", Fmt.date(e.dateOfBirth))
                                detail("Joined", Fmt.date(e.startDate))
                                detail("Status", e.status.capitalized, last: true)
                            }
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
        .sheet(isPresented: $showEdit) {
            if case .loaded(let data) = state, let e = data.employee {
                EditProfileView(employee: e) { Task { await load() } }
            }
        }
        .sheet(isPresented: $showPassword) { ChangePasswordView() }
    }

    private func actionButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(.white.opacity(0.1)).foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1))
        }
    }

    private func avatar(_ e: EmployeeProfile) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accent).frame(width: 88, height: 88)
                Text(initials(e.name)).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }
            .shadow(color: Theme.premier.opacity(0.5), radius: 14, y: 8)
            Text(e.name).font(.title3.weight(.bold)).foregroundStyle(.white)
            Text(e.roles.joined(separator: " · "))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(.white.opacity(0.16)).clipShape(Capsule()).foregroundStyle(.white)
        }
    }

    private func detail(_ label: String, _ value: String, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(value).font(.subheadline.weight(.medium)).foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 11)
            if !last { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
        }
    }

    private func initials(_ name: String) -> String {
        String(name.split(separator: " ").prefix(2).compactMap { $0.first }).uppercased()
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.profile()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
