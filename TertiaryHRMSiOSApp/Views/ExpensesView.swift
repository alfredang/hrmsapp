import SwiftUI

/// Expense claims — personal claims from /api/mobile/expenses, plus the
/// snap-a-receipt submission flow (camera → Google Drive → approval).
struct ExpensesView: View {
    @State private var state: LoadState<ExpensesResponse> = .idle
    @State private var showNewClaim = false

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PremierButton(title: "New claim — snap receipt", systemImage: "camera.fill") {
                            showNewClaim = true
                        }
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
                .sheet(isPresented: $showNewClaim, onDismiss: { Task { await load() } }) {
                    NavigationStack {
                        NewClaimView(categories: data.categories)
                    }
                    .preferredColorScheme(.dark)
                }
            }
        }
        .navigationTitle("Expenses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewClaim = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.white)
                }
            }
        }
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
