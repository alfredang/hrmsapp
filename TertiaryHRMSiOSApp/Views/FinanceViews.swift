import SwiftUI

// Details behind the accountant Home's Finance card (Alfred, 22 Nov 2026). Read-only: recording to
// QuickBooks, importing statements and running a reconciliation stay on the web, linked at the foot
// of each screen.

/// A link to a web page of the HRMS (or a full URL), for the footer of a read-only screen.
private struct WebFooterLink: View {
    let title: String
    let path: String
    var body: some View {
        let url = path.hasPrefix("http") ? URL(string: path)! : AuthService.baseURL.appendingPathComponent(path)
        Link(destination: url) {
            Label(title, systemImage: "arrow.up.right.square")
                .font(.footnote.weight(.semibold)).foregroundStyle(Theme.sky)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6).padding(.top, 2)
        }
    }
}

/// One headline figure with its caption, for the top of a finance screen.
private struct FinanceHeadline: View {
    let label: String
    let value: String
    let caption: String
    let tint: Color
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.subheadline).foregroundStyle(Theme.mist)
                Text(value).font(.title.weight(.bold)).monospacedDigit().foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(caption).font(.caption).foregroundStyle(Theme.mist)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Rows inside one card, divided like the Home cards.
private struct RowsCard<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row
    var body: some View {
        Card(padding: 0) {
            LazyVStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    if i > 0 { Divider().padding(.leading, 14) }
                    row(item)
                }
            }
        }
    }
}

// MARK: - Income / Expenses

/// One month of bank credits (Income) or debits (Expenses), searchable; a tap shows the whole line.
struct BankTransactionsView: View {
    let direction: BankDirection
    @State private var month = AttendanceMonth.current()
    @State private var state: LoadState<BankTransactionsMonth> = .idle
    @State private var query = ""
    @State private var selected: BankTransaction?

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                let shown = data.transactions.filter { $0.matches(query) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(direction.title).font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                                .accessibilityAddTraits(.isHeader)
                            Spacer()
                            MonthSwitcher(month: $month)
                        }
                        FinanceHeadline(
                            label: "\(direction.title) in \(AttendanceMonth.label(month))",
                            value: Fmt.money(data.total),
                            caption: "\(data.count) bank \(direction.noun)\(data.count == 1 ? "" : "s")",
                            tint: direction == .credit ? Theme.success : Theme.ink)
                        .accessibilityIdentifier("finance.\(direction.rawValue.lowercased()).total")

                        if shown.isEmpty {
                            EmptyHint(icon: "magnifyingglass",
                                      text: query.isEmpty ? "No bank \(direction.noun)s in \(AttendanceMonth.label(month))."
                                                          : "Nothing matches “\(query)”.")
                        } else {
                            if !query.isEmpty {
                                Text("\(shown.count) of \(data.count) · \(Fmt.money(shown.reduce(0) { $0 + $1.amount }))")
                                    .font(.caption).foregroundStyle(Theme.mist).padding(.horizontal, 6)
                            }
                            RowsCard(items: shown) { t in transactionRow(t) }
                        }
                        WebFooterLink(title: "Record in QuickBooks on the web",
                                      path: direction == .credit ? "accounting/income-tracking" : "accounting/expense-tracking")
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
        .searchable(text: $query, prompt: "Payee, reference or type")
        .autocorrectionDisabled()
        .sheet(item: $selected) { t in
            RecordSheet(title: t.displayTitle, status: t.status, fields: fields(t),
                        longTextTitle: "Bank statement text", longText: details(t))
            .presentationDetents([.medium, .large])
        }
        .onChange(of: month) { _ in Task { await load() } }
    }

    private func transactionRow(_ t: BankTransaction) -> some View {
        Button { selected = t } label: {
            HStack(spacing: 12) {
                Text(AttendanceMonth.shortLabel(t.paymentDate))
                    .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.mist)
                    .frame(width: 44, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.displayTitle).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text([t.type, t.status].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(Theme.mist).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(Fmt.money(t.amount)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(direction == .credit ? Theme.success : Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t.displayTitle)
        .accessibilityValue("\(Fmt.money(t.amount)), \(AttendanceMonth.dayLabel(t.paymentDate))")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("finance.txn.\(t.id)")
    }

    private func fields(_ t: BankTransaction) -> [RecordField] {
        var f = [RecordField(label: "Date", value: AttendanceMonth.dayLabel(t.paymentDate)),
                 RecordField(label: "Amount", value: Fmt.money(t.amount)),
                 RecordField(label: "Direction", value: t.direction == "CREDIT" ? "Credit (income)" : "Debit (expense)")]
        let optional: [(String, String?)] = [("Type", t.type), ("Payment", t.paymentType), ("Reference", t.paymentRef),
                                            ("Invoice no.", t.invoiceNo), ("Statement", t.statementRef)]
        for (label, value) in optional {
            if let v = value?.trimmingCharacters(in: .whitespaces), !v.isEmpty { f.append(RecordField(label: label, value: v)) }
        }
        return f
    }

    private func details(_ t: BankTransaction) -> String? {
        let parts = [t.rawDescription, t.remarks.map { "Remarks: \($0)" }]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do { state = .loaded(try await HRMSAPI.shared.bankTransactions(direction, month: month)) }
        catch is CancellationError {}
        catch {
            if (error as? URLError)?.code == .cancelled { return }
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load the bank \(direction.noun)s.")
        }
    }
}

// MARK: - Bank statements

/// Every bank statement import, newest first: the dates it covers and its credits and debits.
struct BankStatementsView: View {
    @State private var state: LoadState<[StatementImport]> = .idle

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { imports in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Bank statements").font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        FinanceHeadline(
                            label: "Imported up to",
                            value: imports.compactMap(\.to).max().map { AttendanceMonth.dayLabel($0) } ?? "None yet",
                            caption: "\(imports.count) import\(imports.count == 1 ? "" : "s") · "
                                + "\(imports.reduce(0) { $0 + $1.lines }) bank lines",
                            tint: Theme.ink)
                        .accessibilityIdentifier("finance.statements.total")
                        if imports.isEmpty {
                            EmptyHint(icon: "doc.richtext", text: "No bank statements imported yet.")
                        } else {
                            RowsCard(items: imports) { s in statementRow(s) }
                        }
                        WebFooterLink(title: "Open the DBS statements folder (Google Drive)", path: MoreView.bankStatementsFolder)
                        WebFooterLink(title: "Import a statement on the web", path: "accounting")
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
    }

    private func statementRow(_ s: StatementImport) -> some View {
        let period = [s.from, s.to].compactMap { $0 }.map(AttendanceMonth.shortLabel)
        let range = period.count == 2 ? "\(period[0]) – \(period[1]) \(s.to?.prefix(4) ?? "")" : "No dates"
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(range).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("Imported \(Fmt.date(s.importedAt))").font(.caption).foregroundStyle(Theme.mist)
            }
            HStack(spacing: 14) {
                Label("\(s.credits) in · \(Fmt.money(s.creditTotal))", systemImage: "arrow.up.right")
                    .labelStyle(.titleAndIcon).foregroundStyle(Theme.success)
                Label("\(s.debits) out · \(Fmt.money(s.debitTotal))", systemImage: "arrow.down.right")
                    .labelStyle(.titleAndIcon).foregroundStyle(Theme.danger)
            }
            .font(.caption.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            if let ref = s.statementRef, !ref.isEmpty {
                Text(ref).font(.caption2).foregroundStyle(Theme.mist).lineLimit(1)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("finance.statement.\(s.id)")
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do { state = .loaded(try await HRMSAPI.shared.statementImports()) }
        catch is CancellationError {}
        catch {
            if (error as? URLError)?.code == .cancelled { return }
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load the bank statements.")
        }
    }
}

// MARK: - Bank reconciliation

/// The latest reconciliation run (DBS against QuickBooks) and its lines, opening on the ones to
/// review. Earlier runs are one menu away. Reviewing and re-running stay on the web.
struct ReconciliationView: View {
    @State private var runs: LoadState<[ReconciliationRun]> = .idle
    @State private var runId: String?
    @State private var detail: ReconciliationDetail?
    @State private var detailError: String?
    @State private var filter: ReconciliationFilter = .toReview
    @State private var selected: ReconciliationItem?

    var body: some View {
        GradientScreen {
            AsyncContent(state: $runs, load: loadRuns) { list in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Bank reconciliation").font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                                .accessibilityAddTraits(.isHeader)
                            Spacer()
                            if list.count > 1 { runMenu(list) }
                        }
                        if list.isEmpty {
                            EmptyHint(icon: "scale.3d", text: "No reconciliation has been run yet.")
                        } else if let d = detail {
                            summary(d.run)
                            filterMenu(d.items)
                            let shown = d.items.filter(filter.includes)
                            if shown.isEmpty {
                                EmptyHint(icon: "checkmark.seal",
                                          text: filter == .toReview ? "Nothing left to review." : "No \(filter.title.lowercased()) lines.")
                            } else {
                                RowsCard(items: shown) { i in itemRow(i) }
                            }
                        } else if let detailError {
                            EmptyHint(icon: "exclamationmark.triangle", text: detailError)
                        } else {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
                        }
                        WebFooterLink(title: "Review or run a reconciliation on the web", path: "accounting/reconciliation")
                    }
                    .padding(20)
                }
                .refreshable { await loadRuns() }
            }
        }
        .brandBar()
        .sheet(item: $selected) { i in
            RecordSheet(title: i.displayTitle, status: ReconciliationFilter.label(forStatus: i.status),
                        fields: fields(i), longTextTitle: "Bank statement text", longText: i.bankDescription)
            .presentationDetents([.medium, .large])
        }
        .onChange(of: runId) { _ in Task { await loadDetail() } }
    }

    private func runMenu(_ list: [ReconciliationRun]) -> some View {
        Menu {
            ForEach(list) { r in
                Button { runId = r.id } label: {
                    if r.id == runId { Label(period(r), systemImage: "checkmark") } else { Text(period(r)) }
                }
            }
        } label: {
            Label("Runs", systemImage: "clock.arrow.circlepath").font(.subheadline.weight(.semibold))
        }
        .accessibilityIdentifier("reconciliation.runs")
    }

    private func period(_ r: ReconciliationRun) -> String {
        "\(AttendanceMonth.shortLabel(r.periodStart)) – \(AttendanceMonth.shortLabel(r.periodEnd)) \(r.periodEnd.prefix(4))"
    }

    private func summary(_ r: ReconciliationRun) -> some View {
        let toReview = detail?.items.filter(\.needsReview).count ?? 0
        return VStack(alignment: .leading, spacing: 10) {
            FinanceHeadline(
                label: "DBS against QuickBooks, \(period(r))",
                value: toReview > 0 ? "\(toReview) to review" : "All clear",
                caption: "\(String(format: "%.1f", r.matchRate))% of \(r.bankCount) bank lines matched · run \(Fmt.date(r.createdAt))"
                    + (r.status.uppercased() == "COMPLETED" ? "" : " · \(r.status.capitalized)"),
                tint: toReview > 0 ? Theme.gold600 : Theme.success)
            .accessibilityIdentifier("reconciliation.headline")
            HStack(spacing: 10) {
                StatTile(value: "\(r.matchedCount)", label: "Matched", icon: "checkmark.circle.fill", tint: Theme.success)
                StatTile(value: "\(r.mismatchCount)", label: "Amount differs", icon: "exclamationmark.circle.fill", tint: Theme.gold600)
            }
            HStack(spacing: 10) {
                StatTile(value: "\(r.unmatchedBankCount)", label: "Bank only", icon: "building.columns.fill", tint: Theme.sky)
                StatTile(value: "\(r.unmatchedQbCount)", label: "QuickBooks only", icon: "book.closed.fill", tint: Theme.sky)
            }
            if let e = r.error, !e.isEmpty {
                Text(e).font(.caption).foregroundStyle(Theme.danger)
            }
        }
    }

    private func filterMenu(_ items: [ReconciliationItem]) -> some View {
        Menu {
            Picker("Show", selection: $filter) {
                ForEach(ReconciliationFilter.allCases) { f in
                    Text("\(f.title) (\(items.filter(f.includes).count))").tag(f)
                }
            }
        } label: {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text("\(filter.title) · \(items.filter(filter.includes).count)")
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.caption)
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.sky)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
        }
        .accessibilityIdentifier("reconciliation.filter")
    }

    private func itemRow(_ i: ReconciliationItem) -> some View {
        Button { selected = i } label: {
            HStack(spacing: 12) {
                Text(i.date.map(AttendanceMonth.shortLabel) ?? "—")
                    .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.mist)
                    .frame(width: 44, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(i.displayTitle).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(ReconciliationFilter.label(forStatus: i.status) + (i.reviewed ? " · Reviewed" : ""))
                        .font(.caption).foregroundStyle(i.needsReview ? Theme.gold600 : Theme.mist).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(i.amount.map { Fmt.money($0) } ?? "—").font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(i.direction == "CREDIT" ? Theme.success : Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(i.displayTitle)
        .accessibilityValue("\(ReconciliationFilter.label(forStatus: i.status)), \(i.amount.map { Fmt.money($0) } ?? "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("reconciliation.item.\(i.id)")
    }

    private func fields(_ i: ReconciliationItem) -> [RecordField] {
        var f: [RecordField] = []
        let add = { (label: String, value: String?) in
            if let v = value?.trimmingCharacters(in: .whitespaces), !v.isEmpty { f.append(RecordField(label: label, value: v)) }
        }
        add("Bank date", i.bankDate.map(AttendanceMonth.dayLabel))
        add("Bank amount", i.bankAmount.map { Fmt.money($0) + (i.bankDirection == "CREDIT" ? " in" : " out") })
        add("QuickBooks date", i.qbDate.map(AttendanceMonth.dayLabel))
        add("QuickBooks amount", i.qbAmount.map { Fmt.money($0) + (i.qbDirection == "CREDIT" ? " in" : " out") })
        add("QuickBooks entry", [i.qbTxnType, i.qbDocNumber].compactMap { $0 }.joined(separator: " "))
        add("Payee", i.qbPayee)
        if let d = i.amountDifference, d != 0 { add("Difference", Fmt.money(d)) }
        if let d = i.dayDifference, d != 0 { add("Days apart", "\(d)") }
        add("Reviewed", i.reviewed ? (i.reviewNote.map { "Yes: \($0)" } ?? "Yes") : "Not yet")
        return f
    }

    private func loadRuns() async {
        if case .loaded = runs {} else { runs = .loading }
        do {
            let list = try await HRMSAPI.shared.reconciliationRuns()
            runs = .loaded(list)
            if runId == nil || !list.contains(where: { $0.id == runId }) { runId = list.first?.id }
            else { await loadDetail() }
        } catch is CancellationError {
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            runs = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load the reconciliation.")
        }
    }

    private func loadDetail() async {
        guard let runId else { detail = nil; return }
        detailError = nil
        if detail?.run.id != runId { detail = nil }
        do {
            let d = try await HRMSAPI.shared.reconciliation(id: runId)
            detail = d
            // Open on what needs a person; a clean run opens on every line.
            if !d.items.contains(where: \.needsReview), filter == .toReview { filter = .all }
        } catch is CancellationError {
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            detailError = (error as? LocalizedError)?.errorDescription ?? "Could not load this run."
        }
    }
}
