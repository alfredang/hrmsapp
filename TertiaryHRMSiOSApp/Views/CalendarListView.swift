import SwiftUI

/// Calendar — public holidays, your events, and your approved leave, grouped by month.
struct CalendarListView: View {
    @State private var state: LoadState<CalendarResponse> = .idle

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if data.events.isEmpty {
                            EmptyHint(icon: "calendar", text: "No upcoming events.")
                        }
                        ForEach(grouped(data.events), id: \.key) { month, events in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(month).font(.headline).foregroundStyle(.white.opacity(0.9))
                                ForEach(events) { e in row(e) }
                            }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ e: CalendarEvent) -> some View {
        Card {
            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(dayNum(e.startDate)).font(.title3.weight(.bold)).foregroundStyle(.white)
                    Text(weekday(e.startDate)).font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
                .frame(width: 46)
                Rectangle().fill(tint(e.type)).frame(width: 3, height: 36).clipShape(Capsule())
                VStack(alignment: .leading, spacing: 3) {
                    Text(e.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(label(e.type)).font(.caption2).foregroundStyle(tint(e.type))
                }
                Spacer()
            }
        }
    }

    private func tint(_ type: String) -> Color {
        switch type {
        case "HOLIDAY": return .red
        case "LEAVE": return Theme.sky
        case "TRAINING": return .mint
        case "MEETING": return .orange
        default: return Theme.azure
        }
    }
    private func label(_ type: String) -> String {
        type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func grouped(_ events: [CalendarEvent]) -> [(key: String, value: [CalendarEvent])] {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        let dict = Dictionary(grouping: events) { e -> String in
            guard let d = Fmt.dateObj(e.startDate) else { return "Other" }
            return f.string(from: d)
        }
        return dict.sorted { ($0.value.first?.startDate ?? "") < ($1.value.first?.startDate ?? "") }
    }
    private func dayNum(_ iso: String?) -> String {
        guard let d = Fmt.dateObj(iso) else { return "•" }
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: d)
    }
    private func weekday(_ iso: String?) -> String {
        guard let d = Fmt.dateObj(iso) else { return "" }
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: d)
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.calendar()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
