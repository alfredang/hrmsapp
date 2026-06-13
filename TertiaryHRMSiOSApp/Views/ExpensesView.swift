import SwiftUI

/// Expense claims — personal claims from /api/mobile/expenses.
struct ExpensesView: View {
    @State private var state: LoadState<ExpensesResponse> = .idle

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        StatTile(value: Fmt.money(data.approvedTotal), label: "Approved total", icon: "checkmark.seal.fill", tint: .green)

                        Text("Claims").font(.headline).foregroundStyle(.white.opacity(0.9))
                        if data.claims.isEmpty {
                            EmptyHint(icon: "creditcard", text: "No expense claims yet.")
                        } else {
                            ForEach(data.claims) { c in row(c) }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Expenses")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ c: ExpenseClaim) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.description).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                    Text([c.category, Fmt.date(c.expenseDate)].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    if let r = c.rejectionReason, !r.isEmpty {
                        Text(r).font(.caption2).foregroundStyle(.red.opacity(0.9)).lineLimit(2)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(Fmt.money(c.amount, currency: c.currency)).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    StatusPill(status: c.status)
                }
            }
        }
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.expenses()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
