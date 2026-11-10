import SwiftUI
import EventKit

/// More → iPhone Calendar sync: copies the user's approved leave, MC and time off (and,
/// optionally, public holidays and — admins only — everyone's leave) into the iPhone calendars
/// they tick, e.g. their Google work calendar. One-way: HRMS is the source of truth.
struct CalendarSyncSettingsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @ObservedObject private var sync = CalendarAutoSync.shared

    @AppStorage(CalendarAutoSync.enabledKey) private var enabled = false
    @AppStorage(CalendarAutoSync.ownLeaveKey) private var ownLeave = true
    @AppStorage(CalendarAutoSync.ownTimeOffKey) private var ownTimeOff = true
    @AppStorage(CalendarAutoSync.holidaysKey) private var holidays = false
    @AppStorage(CalendarAutoSync.teamLeaveKey) private var teamLeave = false
    @State private var selectedIDs = CalendarAutoSync.shared.calendarIDs
    @State private var calendars: [EKCalendar] = []
    @State private var denied = false

    private var isAdmin: Bool { ["ADMIN", "HR", "MANAGER"].contains(auth.user?.primaryRole.uppercased() ?? "") }

    var body: some View {
        GradientScreen {
            Form {
                Section {
                    Toggle("Sync to iPhone Calendar", isOn: $enabled).tint(Theme.premier)
                } footer: {
                    Text("TIA HRMS adds your approved leave, MC and time off to the calendars you choose, and keeps them up to date. Your other events are never changed. To use a Google calendar, add the account in Settings ▸ Apps ▸ Calendar ▸ Calendar Accounts.")
                }

                if enabled {
                    if denied {
                        Section {
                            Text("Calendar access is off. Allow Full Access for TIA HRMS in Settings ▸ Privacy & Security ▸ Calendars.")
                                .font(.subheadline).foregroundStyle(Theme.danger)
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                        }
                    } else {
                        Section("Calendars") {
                            if calendars.isEmpty {
                                Text("No calendars you can write to.").foregroundStyle(Theme.mist)
                            }
                            ForEach(calendars, id: \.calendarIdentifier) { cal in
                                Toggle(isOn: binding(for: cal)) {
                                    HStack(spacing: 8) {
                                        Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 10, height: 10)
                                        Text(label(cal)).lineLimit(1)
                                    }
                                }
                                .tint(Theme.premier)
                            }
                        }
                        Section("What to add") {
                            Toggle("My approved leave & MC", isOn: $ownLeave).tint(Theme.premier)
                            Toggle("My approved time off", isOn: $ownTimeOff).tint(Theme.premier)
                            Toggle("Public holidays", isOn: $holidays).tint(Theme.premier)
                            if isAdmin {
                                Toggle("Team leave (everyone)", isOn: $teamLeave).tint(Theme.premier)
                            }
                        }
                        Section {
                            Button {
                                Task { await sync.runNow() }
                            } label: {
                                HStack {
                                    Text("Sync Now")
                                    Spacer()
                                    if sync.isSyncing { ProgressView() }
                                }
                            }
                            .disabled(selectedIDs.isEmpty || sync.isSyncing)
                        } footer: {
                            Text(status)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .brandBar()
        .navigationTitle("iPhone Calendar")
        .task { if enabled { await prepare() } }
        .onChange(of: enabled) { on in
            if on {
                Task { await prepare(); await sync.runNow() }
            } else {
                sync.removeAll(fromCalendarIds: selectedIDs)   // stop mirroring: take our copies out
            }
        }
        .onChange(of: selectedIDs) { [selectedIDs] ids in
            let removed = Set(selectedIDs).subtracting(ids)
            sync.calendarIDs = ids
            if !removed.isEmpty { sync.removeAll(fromCalendarIds: Array(removed)) }
            Task { await sync.runNow() }
        }
        .onChange(of: ownLeave) { _ in Task { await sync.runNow() } }
        .onChange(of: ownTimeOff) { _ in Task { await sync.runNow() } }
        .onChange(of: holidays) { _ in Task { await sync.runNow() } }
        .onChange(of: teamLeave) { _ in Task { await sync.runNow() } }
    }

    private var status: String {
        if selectedIDs.isEmpty { return "Tick at least one calendar to start syncing." }
        var s = "Syncs when you open the app, after you apply or approve, and every 2 minutes while it is open."
        if let t = sync.lastSynced {
            s += "\n\nLast synced \(t.formatted(date: .omitted, time: .shortened))"
            if let sum = sync.lastSummary, !sum.isEmpty { s += sum == "Up to date." ? " — up to date." : ": \(sum)." }
        }
        return s
    }

    private func prepare() async {
        if !sync.hasFullAccess { _ = await sync.requestAccess() }
        denied = !sync.hasFullAccess
        calendars = sync.writableCalendars()
            .sorted { label($0).localizedCaseInsensitiveCompare(label($1)) == .orderedAscending }
        // Forget calendars that no longer exist.
        let live = Set(calendars.map(\.calendarIdentifier))
        if selectedIDs.contains(where: { !live.contains($0) }) { selectedIDs = selectedIDs.filter(live.contains) }
    }

    private func binding(for cal: EKCalendar) -> Binding<Bool> {
        Binding {
            selectedIDs.contains(cal.calendarIdentifier)
        } set: { on in
            selectedIDs.removeAll { $0 == cal.calendarIdentifier }
            if on { selectedIDs.append(cal.calendarIdentifier) }
        }
    }

    /// "Work (angch@tertiaryinfotech.com)" — the account name tells same-named calendars apart.
    private func label(_ cal: EKCalendar) -> String {
        let source = cal.source?.title ?? ""
        return source.isEmpty || source == cal.title ? cal.title : "\(cal.title) (\(source))"
    }
}
