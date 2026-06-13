import SwiftUI

/// Team tab — the company directory.
struct TeamView: View {
    @State private var state: LoadState<EmployeesResponse> = .idle
    @State private var query = ""

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(filtered(data.employees)) { e in row(e, isAdmin: data.isAdmin) }
                        if filtered(data.employees).isEmpty {
                            EmptyHint(icon: "person.2", text: "No colleagues found.")
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Team")
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
                    Text(e.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text([e.position, e.department].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    if isAdmin, let email = e.email {
                        Text(email).font(.caption2).foregroundStyle(Theme.sky)
                    }
                }
                Spacer()
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
