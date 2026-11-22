import SwiftUI

/// Team tab — the company directory. Approvers can tap a person for their
/// clock-in, MC and leave history (`EmployeeRecordsView`), and see staff and interns as two
/// lists (`EmployeeGroup`, like the web's Staff Management / Intern Management) when the
/// server flags interns; otherwise it stays one list.
struct TeamView: View {
    @State private var state: LoadState<EmployeesResponse> = .idle
    @State private var query = ""
    @State private var group: EmployeeGroup

    init(group: EmployeeGroup = .staff) { _group = State(initialValue: group) }

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                let found = filtered(data.employees)
                let split = data.isAdmin && EmployeeGroup.isAvailable(data.employees)
                let shown = split ? group.filter(found) : found
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if split {
                            Picker("List", selection: $group) {
                                ForEach(EmployeeGroup.allCases) { g in
                                    Text("\(g.title) \(g.filter(found).count)").tag(g)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("team.group")
                        }
                        ForEach(shown) { e in
                            // Approvers drill into a person's clock-in, MC and leave history.
                            if data.isAdmin {
                                NavigationLink { EmployeeRecordsView(employee: e) } label: { row(e, isAdmin: true) }
                                    .buttonStyle(.plain)
                            } else {
                                row(e, isAdmin: false)
                            }
                        }
                        if shown.isEmpty {
                            EmptyHint(icon: "person.2", text: !split ? "No colleagues found."
                                      : group == .staff ? "No staff found." : "No interns found.")
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
        .searchable(text: $query, prompt: "Name, department, email or role")
    }

    private func filtered(_ list: [Employee]) -> [Employee] {
        guard !query.isEmpty else { return list }
        let q = query.lowercased()
        return list.filter { e in
            [e.name, e.position, e.department, e.email, e.employmentLabel].compactMap { $0?.lowercased() }.contains { $0.contains(q) }
        }
    }

    private func row(_ e: Employee, isAdmin: Bool) -> some View {
        Card {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.accent).frame(width: 46, height: 46)
                    Text(initials(e.name)).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                }
                // Full name, department, full time / part time and email (Alfred, 22 Nov 2026).
                VStack(alignment: .leading, spacing: 4) {
                    Text(e.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(e.department ?? "No department")
                            .font(.caption).foregroundStyle(Theme.ink.opacity(0.7)).lineLimit(1)
                        if let type = e.employmentLabel {
                            Text(type)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background((e.employmentType == "PART_TIME" ? Theme.gold : Theme.chipFill).opacity(0.55))
                                .foregroundStyle(e.employmentType == "PART_TIME" ? Theme.navy950 : Theme.chipInk)
                                .clipShape(Capsule())
                                .accessibilityIdentifier("team.type.\(e.employeeId)")
                        }
                    }
                    if isAdmin, let email = e.email {
                        Text(email).font(.caption).foregroundStyle(Theme.sky).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                Spacer()
                if isAdmin {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.ink.opacity(0.4))
                }
            }
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return String(parts).uppercased()
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.employees()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
