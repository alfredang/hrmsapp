import SwiftUI

/// Weekly timesheet — the current week from the existing /api/timesheet endpoint.
struct TimesheetView: View {
    @State private var state: LoadState<TimesheetResponse> = .idle

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Week of \(Fmt.date(data.weekStart))").font(.headline).foregroundStyle(.white)
                            Spacer()
                            if data.isLocked {
                                Label("Locked", systemImage: "lock.fill").font(.caption).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        StatTile(value: String(format: "%.1f h", total(data)), label: "Total hours this week", icon: "sum", tint: .mint)
                        ForEach(data.days) { d in row(d) }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Timesheet")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ d: TimesheetDay) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(d.dayName) · \(Fmt.date(d.date, style: .short))").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    if d.isPublicHoliday, let ph = d.phName {
                        Text(ph).font(.caption2).foregroundStyle(.red.opacity(0.9))
                    } else if d.isWeekend {
                        Text("Weekend").font(.caption2).foregroundStyle(.white.opacity(0.5))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "%.1f h", d.hours)).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    if d.otCredited > 0 {
                        Text("OT +\(String(format: "%.1f", d.otCredited))").font(.caption2).foregroundStyle(.mint)
                    }
                    if let s = d.status { StatusPill(status: s) }
                }
            }
        }
    }

    private func total(_ d: TimesheetResponse) -> Double { d.days.reduce(0) { $0 + $1.hours } }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.timesheet()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
