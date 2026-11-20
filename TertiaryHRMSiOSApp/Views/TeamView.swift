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
        .searchable(text: $query, prompt: "Search name or role")
    }

    private func filtered(_ list: [Employee]) -> [Employee] {
        guard !query.isEmpty else { return list }
        let q = query.lowercased()
        return list.filter { $0.name.lowercased().contains(q) || ($0.position ?? "").lowercased().contains(q) || ($0.department ?? "").lowercased().contains(q) }
    }

    private func row(_ e: Employee, isAdmin: Bool) -> some View {
        Card {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.accent).frame(width: 46, height: 46)
                    Text(initials(e.name)).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(e.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text([e.position, e.department].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(Theme.ink.opacity(0.7))
                    if isAdmin, let email = e.email {
                        Text(email).font(.caption2).foregroundStyle(Theme.sky)
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
