import SwiftUI
import Charts

/// Analytics (approvers only) — the app's version of the web /dashboard/analytics page:
/// the last 12 months of bank revenue and expenses, leave and MC per person, and headcount.
/// One filter card drives every tile, chart and list (`AnalyticsSlice`). Lists double as
/// slicers: tap a category to leave it out, tap a person to show only their leave.
struct AnalyticsView: View {
    @State private var state: LoadState<AnalyticsData> = .idle
    @State private var filter = AnalyticsFilter()

    // Series colours: the web's validated slots (readable on the light and the dark card).
    static let blue = Color(hex: 0x5B82F0)
    static let teal = Color(hex: 0x22978B)
    static let amber = Color(hex: 0xBF8420)

    static func color(_ c: AnalyticsLeaveCategory) -> Color {
        switch c {
        case .leave: return blue
        case .mc: return teal
        case .npl: return amber
        }
    }

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                let s = AnalyticsSlice(data, filter)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        filters(s)
                        tiles(s)
                        if s.hasFinance { finance(s, data) }
                        leave(s)
                        people(s)
                        headcount(s)
                    }
                    .padding(16)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
        .navigationTitle("Analytics")
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do { state = .loaded(try await HRMSAPI.shared.analytics()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }

    // MARK: - Filters

    private func filters(_ s: AnalyticsSlice) -> some View {
        Card(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Period", selection: $filter.period) {
                    ForEach([3, 6, 12], id: \.self) { Text("\($0) months").tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("analytics.period")

                Picker("Who", selection: Binding(get: { filter.who },
                                                 set: { filter.who = $0; filter.personId = nil })) {
                    ForEach(AnalyticsWho.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("analytics.who")

                HStack(spacing: 8) {
                    Menu {
                        Button("Everyone") { filter.personId = nil }
                        ForEach(s.selectablePeople) { p in
                            Button(p.active ? p.name : "\(p.name) (left)") { filter.personId = p.id }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle")
                            Text(s.person?.name ?? "Everyone").lineLimit(1)
                            Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                        }
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(height: 36)
                        .background(Theme.field)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.fieldBorder, lineWidth: 1))
                    }
                    .accessibilityLabel("Person")
                    .accessibilityValue(s.person?.name ?? "Everyone")
                    Spacer(minLength: 0)
                    if !filter.isDefault {
                        Button { filter = AnalyticsFilter() } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise").font(.subheadline)
                        }
                        .tint(Theme.sky)
                        .accessibilityIdentifier("analytics.reset")
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AnalyticsLeaveCategory.allCases) { c in
                            let on = !filter.leaveOff.contains(c)
                            Button {
                                if on { filter.leaveOff.insert(c) } else { filter.leaveOff.remove(c) }
                            } label: {
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 2).fill(on ? Self.color(c) : Theme.mist.opacity(0.4))
                                        .frame(width: 9, height: 9)
                                    Text(c.label).strikethrough(!on)
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(on ? Theme.ink : Theme.mist)
                                .padding(.horizontal, 10).frame(height: 32)
                                .overlay(Capsule().stroke(Theme.fieldBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(c.label)
                            .accessibilityValue(on ? "shown" : "hidden")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tiles (same filtered rows as the charts)

    private func tiles(_ s: AnalyticsSlice) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            if s.hasFinance {
                tile("Revenue", Self.money(s.revenue), s.rangeLabel)
                tile("Expenses", Self.money(s.expenses),
                     filter.typeOff.isEmpty ? "All categories" : "\(filter.typeOff.count) hidden")
                tile("Net", Self.money(s.net), "Revenue less expenses")
            }
            tile("Leave", "\(Fmt.num(s.leaveTotal(.leave))) d",
                 s.person?.name ?? (filter.who == .all ? "Staff and interns" : filter.who.title))
            tile("MC", "\(Fmt.num(s.leaveTotal(.mc))) d", Self.count(s.byPerson.filter { $0.value(.mc) > 0 }.count, "person", "people"))
            tile("Headcount", "\(s.headNow)", "\(s.headDelta >= 0 ? "+" : "−")\(abs(s.headDelta)) over \(s.months.count) months")
        }
    }

    private func tile(_ label: String, _ value: String, _ sub: String) -> some View {
        Card(padding: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.caption).foregroundStyle(Theme.mist)
                Text(value).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(sub).font(.caption2).foregroundStyle(Theme.mist).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value), \(sub)")
        .accessibilityIdentifier("analytics.tile.\(label)")
    }

    // MARK: - Revenue and expenses

    private func finance(_ s: AnalyticsSlice, _ data: AnalyticsData) -> some View {
        let series = [AnalyticsBarChart.Series(key: "revenue", label: "Revenue", color: Self.blue),
                      AnalyticsBarChart.Series(key: "expenses", label: "Expenses", color: Self.amber)]
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                heading("Revenue and expenses",
                        "Bank transactions by payment month" + (data.financeRange.map { " · data from \($0.from) to \($0.to)" } ?? ""))
                legend([("Revenue", Self.blue, Self.money(s.revenue)), ("Expenses", Self.amber, Self.money(s.expenses))])
                if s.types.isEmpty {
                    empty("No bank transactions in this period.")
                } else {
                    AnalyticsBarChart(rows: s.financeByMonth, series: series, grouped: true,
                                      format: Self.money, axisFormat: Self.moneyAxis,
                                      footer: { ("Net", Self.money($0.value("revenue") - $0.value("expenses"))) })
                    HStack {
                        Text("By category · tap to hide").font(.caption).foregroundStyle(Theme.mist)
                        Spacer()
                        if !filter.typeOff.isEmpty {
                            Button("Show all") { filter.typeOff = [] }.font(.caption.weight(.semibold)).tint(Theme.sky)
                        }
                    }
                    .padding(.top, 2)
                    let top = max(1, s.types.map(\.amount).max() ?? 1)
                    VStack(spacing: 0) {
                        ForEach(s.types) { t in
                            let on = !filter.typeOff.contains(t.type)
                            Button {
                                if on { filter.typeOff.insert(t.type) } else { filter.typeOff.remove(t.type) }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(t.type).font(.footnote).strikethrough(!on).foregroundStyle(Theme.ink)
                                        .lineLimit(1).frame(width: 112, alignment: .leading)
                                    GeometryReader { g in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Theme.mist.opacity(0.14))
                                            Capsule().fill(t.isRevenue ? Self.blue : Self.amber)
                                                .frame(width: max(3, g.size.width * t.amount / top))
                                        }
                                    }
                                    .frame(height: 7)
                                    Text(Self.money(t.amount)).font(.footnote).monospacedDigit().foregroundStyle(Theme.ink)
                                        .lineLimit(1).frame(width: 92, alignment: .trailing)
                                }
                                .frame(minHeight: 36)
                                .opacity(on ? 1 : 0.45)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(t.type)
                            .accessibilityValue("\(Self.money(t.amount)), \(on ? "shown" : "hidden")")
                            .accessibilityIdentifier("analytics.type.\(t.type)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Leave and MC

    private func leave(_ s: AnalyticsSlice) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                heading("Leave and MC" + (s.person.map { " · \($0.name)" } ?? ""), "Approved days, by the month the leave starts")
                legend(s.leaveSeries.map { ($0.label, Self.color($0), "\(Fmt.num(s.leaveTotal($0))) d") })
                if s.leaveSeries.isEmpty {
                    empty("Every leave type is switched off.")
                } else if s.byPerson.isEmpty {
                    empty("No approved leave in this period.")
                } else {
                    AnalyticsBarChart(rows: s.leaveByMonth,
                                      series: s.leaveSeries.map { .init(key: $0.rawValue, label: $0.label, color: Self.color($0)) },
                                      grouped: false,
                                      format: { "\(Fmt.num($0)) d" }, axisFormat: Fmt.num,
                                      footer: { row in ("Total", "\(Fmt.num(s.leaveSeries.reduce(0) { $0 + row.value($1.rawValue) })) d") })
                }
            }
        }
    }

    private func people(_ s: AnalyticsSlice) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    heading("By person", "Tap a name to show only that person")
                    Spacer()
                    if s.person != nil {
                        Button("Everyone") { filter.personId = nil }.font(.caption.weight(.semibold)).tint(Theme.sky)
                    }
                }
                if s.byPerson.isEmpty {
                    empty("No approved leave in this period.")
                } else {
                    HStack(spacing: 0) {
                        Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(s.leaveSeries) { Text($0.short).frame(width: 44, alignment: .trailing) }
                        Text("Total").frame(width: 48, alignment: .trailing)
                    }
                    .font(.caption2.weight(.semibold)).foregroundStyle(Theme.mist)
                    VStack(spacing: 0) {
                        ForEach(s.byPerson) { row in
                            let picked = row.id == s.person?.id
                            Button { filter.personId = picked ? nil : row.id } label: {
                                HStack(spacing: 0) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(row.person.name).font(.footnote.weight(.medium)).foregroundStyle(Theme.ink).lineLimit(1)
                                        Text(row.person.intern ? "Intern" : "Staff").font(.caption2).foregroundStyle(Theme.mist)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    ForEach(s.leaveSeries) { c in
                                        Text(Fmt.num(row.value(c))).font(.footnote).monospacedDigit().foregroundStyle(Theme.ink.opacity(0.85))
                                            .frame(width: 44, alignment: .trailing)
                                    }
                                    Text(Fmt.num(row.total)).font(.footnote.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                                        .frame(width: 48, alignment: .trailing)
                                }
                                .padding(.horizontal, 6)
                                .frame(minHeight: 44)
                                .background(picked ? Theme.chipFill.opacity(0.5) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(row.person.name)
                            .accessibilityValue("\(Fmt.num(row.total)) days\(picked ? ", selected" : "")")
                            Divider().opacity(0.5)
                        }
                    }
                    .padding(.horizontal, -6)
                }
            }
        }
    }

    // MARK: - Headcount

    private func headcount(_ s: AnalyticsSlice) -> some View {
        let showStaff = filter.who != .interns, showInterns = filter.who != .staff
        var series: [AnalyticsBarChart.Series] = []
        if showStaff { series.append(.init(key: "staff", label: "Staff", color: Self.blue)) }
        if showInterns { series.append(.init(key: "interns", label: "Interns", color: Self.teal)) }
        let rows = s.headcount.map { AnalyticsSlice.MonthValue(month: $0.month, values: ["staff": Double($0.staff), "interns": Double($0.interns)]) }
        let last = s.headcount.last
        var legendItems: [(String, Color, String)] = []
        if showStaff { legendItems.append(("Staff", Self.blue, "\(last?.staff ?? 0) now")) }
        if showInterns { legendItems.append(("Interns", Self.teal, "\(last?.interns ?? 0) now")) }
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                heading("Number of staff", "People employed on the last day of each month (today for this month)")
                legend(legendItems)
                AnalyticsBarChart(rows: rows, series: series, grouped: false,
                                  format: { String(Int($0)) }, axisFormat: { String(Int($0)) },
                                  footer: series.count > 1 ? { ("Total", String(Int($0.value("staff") + $0.value("interns")))) } : nil)
                Text("Change by month").font(.caption).foregroundStyle(Theme.mist).padding(.top, 2)
                HStack(spacing: 0) {
                    Text("Month").frame(maxWidth: .infinity, alignment: .leading)
                    if showStaff { Text("Staff").frame(width: 48, alignment: .trailing) }
                    if showInterns { Text("Interns").frame(width: 56, alignment: .trailing) }
                    Text("Total").frame(width: 48, alignment: .trailing)
                    Text("Change").frame(width: 58, alignment: .trailing)
                }
                .font(.caption2.weight(.semibold)).foregroundStyle(Theme.mist)
                VStack(spacing: 0) {
                    ForEach(s.headcount.reversed()) { h in
                        HStack(spacing: 0) {
                            Text(h.month.title).foregroundStyle(Theme.ink).frame(maxWidth: .infinity, alignment: .leading)
                            if showStaff { Text("\(h.staff)").foregroundStyle(Theme.ink.opacity(0.85)).frame(width: 48, alignment: .trailing) }
                            if showInterns { Text("\(h.interns)").foregroundStyle(Theme.ink.opacity(0.85)).frame(width: 56, alignment: .trailing) }
                            Text("\(h.total)").fontWeight(.semibold).foregroundStyle(Theme.ink).frame(width: 48, alignment: .trailing)
                            Text(Self.change(h.change)).foregroundStyle(Theme.ink.opacity(0.85)).frame(width: 58, alignment: .trailing)
                        }
                        .font(.footnote).monospacedDigit()
                        .frame(minHeight: 32)
                        Divider().opacity(0.5)
                    }
                }
            }
        }
    }

    // MARK: - Small pieces

    private func heading(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
            Text(sub).font(.caption).foregroundStyle(Theme.mist).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Legend: the swatch carries identity; the text stays in ink colours.
    private func legend(_ items: [(String, Color, String)]) -> some View {
        HStack(spacing: 14) {
            ForEach(items, id: \.0) { item in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(item.1).frame(width: 9, height: 9)
                    Text(item.0).foregroundStyle(Theme.ink)
                    Text(item.2).monospacedDigit().foregroundStyle(Theme.mist)
                }
                .font(.caption)
                .lineLimit(1)
            }
        }
        .minimumScaleFactor(0.8)
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(Theme.mist)
            .frame(maxWidth: .infinity).padding(.vertical, 22)
    }

    static func money(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "SGD"; f.currencySymbol = "$"
        f.maximumFractionDigits = 0
        let s = f.string(from: NSNumber(value: abs(v.rounded()))) ?? String(format: "$%.0f", abs(v))
        return v.rounded() < 0 ? "−\(s)" : s
    }
    static func moneyAxis(_ v: Double) -> String {
        if v >= 1_000_000 { return "$\(Fmt.num((v / 100_000).rounded() / 10))M" }
        if v >= 1000 { return "$\(Int((v / 1000).rounded()))k" }
        return "$\(Int(v))"
    }
    static func change(_ c: Int?) -> String {
        guard let c else { return "" }
        return c == 0 ? "0" : "\(c > 0 ? "+" : "−")\(abs(c))"
    }
    static func count(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }
}

/// Stacked or grouped month bars on one axis. Tap a month to read its figures below the chart.
struct AnalyticsBarChart: View {
    struct Series: Identifiable {
        let key: String
        let label: String
        let color: Color
        var id: String { key }
    }

    let rows: [AnalyticsSlice.MonthValue]
    let series: [Series]
    let grouped: Bool
    let format: (Double) -> String
    let axisFormat: (Double) -> String
    var footer: ((AnalyticsSlice.MonthValue) -> (String, String))? = nil
    @State private var selected: String?

    private var picked: AnalyticsSlice.MonthValue? { rows.first { $0.month.key == selected } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(rows) { r in
                    ForEach(series) { s in
                        if grouped {
                            BarMark(x: .value("Month", r.month.label), y: .value(s.label, r.value(s.key)))
                                .foregroundStyle(by: .value("Series", s.label))
                                .position(by: .value("Series", s.label))
                                .cornerRadius(3)
                                .opacity(selected == nil || selected == r.month.key ? 1 : 0.45)
                        } else {
                            BarMark(x: .value("Month", r.month.label), y: .value(s.label, r.value(s.key)), width: .ratio(0.6))
                                .foregroundStyle(by: .value("Series", s.label))
                                .cornerRadius(3)
                                .opacity(selected == nil || selected == r.month.key ? 1 : 0.45)
                        }
                    }
                }
            }
            .chartForegroundStyleScale(domain: series.map(\.label), range: series.map(\.color))
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.system(size: rows.count > 6 ? 9 : 11)).foregroundStyle(Theme.mist)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(Theme.mist.opacity(0.22))
                    AxisValueLabel {
                        if let d = v.as(Double.self) { Text(axisFormat(d)).font(.system(size: 10)).foregroundStyle(Theme.mist) }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in
                            let x = location.x - geo[proxy.plotAreaFrame].origin.x
                            guard let label: String = proxy.value(atX: x),
                                  let row = rows.first(where: { $0.month.label == label }) else { selected = nil; return }
                            selected = selected == row.month.key ? nil : row.month.key
                        }
                }
            }
            .frame(height: 190)
            .accessibilityLabel(series.map(\.label).joined(separator: ", ") + " by month")

            if let p = picked {
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.month.title).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink)
                    ForEach(series) { s in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(s.color).frame(width: 8, height: 8)
                            Text(s.label).foregroundStyle(Theme.ink.opacity(0.85))
                            Spacer()
                            Text(format(p.value(s.key))).monospacedDigit().foregroundStyle(Theme.ink)
                        }
                        .font(.caption)
                    }
                    if let f = footer?(p) {
                        Divider()
                        HStack {
                            Text(f.0).foregroundStyle(Theme.ink.opacity(0.85))
                            Spacer()
                            Text(f.1).fontWeight(.semibold).monospacedDigit().foregroundStyle(Theme.ink)
                        }
                        .font(.caption)
                    }
                }
                .padding(10)
                .background(Theme.cardStripe)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Text("Tap a month for its figures").font(.caption2).foregroundStyle(Theme.mist)
            }
        }
        .onChange(of: rows.map(\.month.key)) { keys in
            if let selected, !keys.contains(selected) { self.selected = nil }
        }
    }
}
