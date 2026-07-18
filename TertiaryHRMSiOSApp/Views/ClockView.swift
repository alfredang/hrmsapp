import SwiftUI

/// Clock in / out — one-tap attendance punches for part-time contractors and
/// interns. Every punch is stored centrally (AttendancePunch table) via
/// /api/mobile/attendance; this screen shows today's state live plus the
/// last 7 days.
struct ClockView: View {
    @State private var state: LoadState<AttendanceResponse> = .idle
    @State private var punching = false
    @State private var errorMessage: String?

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        todayCard(data)
                        if let errorMessage { StatusBanner(kind: .error, text: errorMessage) }
                        weekSummary(data)
                        recentList(data)
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
    }

    // MARK: Today

    private enum Phase {
        case notClockedIn
        case working(since: Date)
        case done(inAt: Date?, outAt: Date?, hours: Double?)
    }

    private func phase(_ data: AttendanceResponse) -> Phase {
        guard let today = data.today, let inISO = today.clockIn else { return .notClockedIn }
        if today.clockOut == nil, let inDate = Fmt.dateObj(inISO) { return .working(since: inDate) }
        return .done(inAt: Fmt.dateObj(today.clockIn), outAt: Fmt.dateObj(today.clockOut), hours: today.hours)
    }

    @ViewBuilder
    private func todayCard(_ data: AttendanceResponse) -> some View {
        Card(padding: 24) {
            VStack(spacing: 18) {
                switch phase(data) {
                case .notClockedIn:
                    statusHeader(icon: "sunrise.fill", tint: .yellow,
                                 title: "Not clocked in yet",
                                 subtitle: "Tap below when you start work — your time is logged to HR automatically.")
                    punchButton("Clock in", icon: "arrow.right.circle.fill", tint: Theme.accent) {
                        await punch(.clockIn)
                    }
                case .working(let since):
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(spacing: 6) {
                            Text("Working — clocked in at \(timeString(since))")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                            Text(elapsedString(since: since, now: context.date))
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    punchButton("Clock out", icon: "arrow.left.circle.fill",
                                tint: LinearGradient(colors: [.orange, .red.opacity(0.85)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)) {
                        await punch(.clockOut)
                    }
                case .done(let inAt, let outAt, let hours):
                    statusHeader(icon: "checkmark.seal.fill", tint: .green,
                                 title: "Done for today",
                                 subtitle: "\(timeString(inAt)) – \(timeString(outAt))\(hours.map { String(format: " · %.1f h logged", $0) } ?? "")")
                    Text("See you tomorrow 👋").font(.subheadline).foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func statusHeader(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 42)).foregroundStyle(tint)
            Text(title).font(.title3.weight(.bold)).foregroundStyle(.white)
            Text(subtitle).font(.footnote).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private func punchButton(_ title: String, icon: String, tint: some ShapeStyle,
                             action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 10) {
                if punching { ProgressView().tint(.white) }
                else { Image(systemName: icon).font(.title3) }
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity).frame(height: 64)
            .background(tint)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        }
        .disabled(punching)
    }

    // MARK: Week + history

    private func weekSummary(_ data: AttendanceResponse) -> some View {
        let total = data.recent.compactMap(\.hours).reduce(0, +)
        return HStack(spacing: 12) {
            StatTile(value: String(format: "%.1f h", total), label: "Logged (last 7 days)",
                     icon: "sum", tint: .mint)
            StatTile(value: "\(data.recent.filter { $0.clockIn != nil }.count)",
                     label: "Days worked", icon: "calendar.badge.checkmark", tint: Theme.sky)
        }
    }

    @ViewBuilder
    private func recentList(_ data: AttendanceResponse) -> some View {
        Text("Recent days").font(.headline).foregroundStyle(.white.opacity(0.9))
        if data.recent.isEmpty {
            EmptyHint(icon: "clock.badge.questionmark", text: "No punches yet. Your log appears here.")
        } else {
            ForEach(data.recent) { p in
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Fmt.date(p.date ?? p.clockIn)).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text("\(timeString(Fmt.dateObj(p.clockIn))) – \(p.clockOut == nil ? "…" : timeString(Fmt.dateObj(p.clockOut)))")
                                .font(.caption).foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        if let h = p.hours {
                            Text(String(format: "%.1f h", h)).font(.subheadline.weight(.bold)).foregroundStyle(.mint)
                        } else if p.clockIn != nil {
                            StatusPill(status: "WORKING")
                        }
                    }
                }
            }
        }
    }

    // MARK: Actions & helpers

    private func punch(_ action: HRMSAPI.ClockAction) async {
        guard !punching else { return }
        errorMessage = nil
        punching = true
        defer { punching = false }
        do {
            try await HRMSAPI.shared.clock(action)
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? (error as NSError).localizedDescription
        }
    }

    private func timeString(_ d: Date?) -> String {
        guard let d else { return "—" }
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: d)
    }

    private func elapsedString(since: Date, now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(since)))
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do { state = .loaded(try await HRMSAPI.shared.attendance()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
