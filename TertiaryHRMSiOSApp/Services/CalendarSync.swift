import Foundation
import EventKit
import UIKit

// MARK: - One-way HRMS → iPhone Calendar sync (since 1.15, modelled on the Planner app)
//
// Every HRMS item the user chose (own approved leave & MC, own approved time off, public
// holidays, and for admins everyone's leave) becomes one event in each ticked calendar. Each
// event's notes end with a marker line "HRMS id: <type>:<id>"; only events carrying that marker
// are ever updated or deleted — the user's other events are never touched. Events are matched by
// marker (not by a stored link), so reinstalling the app or switching phones re-adopts them, and
// same-marker duplicates in one calendar are collapsed to one.

/// One HRMS item as it should appear in the calendar.
struct HRMSCalendarItem: Equatable {
    /// "leave:<id>", "timeoff:<id>" or "holiday:<yyyy-MM-dd>".
    let key: String
    let title: String
    let notes: String
    let start: Date
    let end: Date
    let allDay: Bool

    /// The full notes written to the event, ending with the marker line.
    var eventNotes: String { notes.isEmpty ? HRMSCalendarSync.markerLine(key) : notes + "\n\n" + HRMSCalendarSync.markerLine(key) }
    var fingerprint: String { HRMSCalendarSync.fingerprint(title: title, start: start, end: end, allDay: allDay, notes: eventNotes) }
}

/// An existing calendar event that carries an HRMS marker.
struct ExistingCalendarEvent: Equatable {
    let eventId: String
    let calendarId: String
    let key: String
    let fingerprint: String
}

enum CalendarSyncAction: Equatable {
    case create(key: String, calendarId: String)
    case update(key: String, eventId: String)
    case delete(eventId: String)
}

/// Which HRMS items to copy (Settings → iPhone Calendar sync).
struct CalendarSyncOptions: Equatable {
    var ownLeave = true
    var ownTimeOff = true
    var holidays = false
    var teamLeave = false
}

enum HRMSCalendarSync {
    static let markerPrefix = "HRMS id: "
    static func markerLine(_ key: String) -> String { markerPrefix + key }

    /// The key in an event's marker line, if it has one.
    static func markerKey(in notes: String?) -> String? {
        guard let notes else { return nil }
        for line in notes.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix(markerPrefix) {
                let key = t.dropFirst(markerPrefix.count).trimmingCharacters(in: .whitespaces)
                return key.isEmpty ? nil : key
            }
        }
        return nil
    }

    /// All-day events compare by calendar day: EventKit hands back an all-day event's end as
    /// 23:59:59 of the last day, whatever was saved, so raw timestamps would never agree.
    static func fingerprint(title: String, start: Date, end: Date, allDay: Bool, notes: String,
                            calendar: Calendar = .current) -> String {
        let s = allDay ? calendar.startOfDay(for: start) : start
        let e = allDay ? calendar.startOfDay(for: end) : end
        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(title)|\(Int(s.timeIntervalSince1970))|\(Int(e.timeIntervalSince1970))|\(allDay)|\(n)"
    }

    // MARK: Plan (pure — unit tested)

    /// What to do so each calendar holds exactly one up-to-date copy of every item and no
    /// copy of anything else that carries an HRMS marker.
    static func plan(items: [HRMSCalendarItem], existing: [ExistingCalendarEvent],
                     calendarIds: [String]) -> [CalendarSyncAction] {
        var actions: [CalendarSyncAction] = []
        let wanted = Dictionary(items.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        let selected = Set(calendarIds)
        // Group existing copies per calendar + key (keep stable order).
        var groups: [String: [ExistingCalendarEvent]] = [:]
        var order: [String] = []
        for e in existing {
            let g = e.calendarId + "|" + e.key
            if groups[g] == nil { order.append(g) }
            groups[g, default: []].append(e)
        }
        var covered = Set<String>()
        for g in order {
            let copies = groups[g]!
            let first = copies[0]
            guard selected.contains(first.calendarId), let item = wanted[first.key] else {
                actions += copies.map { .delete(eventId: $0.eventId) }        // gone / not chosen
                continue
            }
            covered.insert(g)
            if first.fingerprint != item.fingerprint { actions.append(.update(key: item.key, eventId: first.eventId)) }
            actions += copies.dropFirst().map { .delete(eventId: $0.eventId) } // duplicates
        }
        for cal in calendarIds {
            for item in items where !covered.contains(cal + "|" + item.key) {
                actions.append(.create(key: item.key, calendarId: cal))
                covered.insert(cal + "|" + item.key)
            }
        }
        return actions
    }

    // MARK: Items (pure — unit tested)

    static let sgTimeZone = TimeZone(identifier: "Asia/Singapore")!

    /// The HRMS items to show, limited to the sync window.
    static func items(entries: [TeamLeaveEntry], holidays: [TeamHoliday], timeOff: [TimeOffRequest],
                      options: CalendarSyncOptions, isAdmin: Bool,
                      window: ClosedRange<Date>, calendar: Calendar = .current) -> [HRMSCalendarItem] {
        var out: [HRMSCalendarItem] = []
        var seen = Set<String>()
        func add(_ i: HRMSCalendarItem) {
            guard i.end >= window.lowerBound, i.start <= window.upperBound, seen.insert(i.key).inserted else { return }
            out.append(i)
        }
        for e in entries {
            let mine = e.isSelf
            guard (mine && options.ownLeave) || (!mine && isAdmin && options.teamLeave) else { continue }
            guard let start = day(e.startDate, calendar), let end = day(e.endDate, calendar) ?? day(e.startDate, calendar) else { continue }
            let code = leaveCode(e.leaveType)
            var title = "\(code) — \(e.employeeName)"
            if e.halfDay { title += " (half day)" }
            var notes = [e.leaveType ?? "Leave", e.halfDay ? "Half day" : Fmt.days(e.days)].joined(separator: " · ")
            if !mine, let d = e.department { notes += " · \(d)" }
            add(HRMSCalendarItem(key: "leave:\(e.id)", title: title, notes: notes + "\nFrom TIA HRMS",
                                 start: start, end: end, allDay: true))
        }
        if options.holidays {
            for h in holidays {
                guard let start = day(h.startDate, calendar) else { continue }
                let end = day(h.endDate, calendar) ?? start
                let ymd = String((h.startDate ?? "").prefix(10))
                add(HRMSCalendarItem(key: "holiday:\(ymd)", title: h.title, notes: "Singapore public holiday\nFrom TIA HRMS",
                                     start: start, end: end, allDay: true))
            }
        }
        if options.ownTimeOff {
            for t in timeOff where t.status.uppercased() == "APPROVED" {
                guard let s = time(t.date, t.startTime), let e = time(t.date, t.endTime) else { continue }
                let reason = [t.reason.capitalized, t.reasonDetail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")
                add(HRMSCalendarItem(key: "timeoff:\(t.id)", title: "Time off \(timeRange(s, e))",
                                     notes: "\(reason)\nFrom TIA HRMS", start: s, end: e, allDay: false))
            }
        }
        return out
    }

    /// "Annual Leave" → "AL", "Medical Leave" → "MC", "No Pay Leave" → "NPL".
    static func leaveCode(_ type: String?) -> String {
        guard let t = type?.lowercased(), !t.isEmpty else { return "Leave" }
        if t.contains("annual") { return "AL" }
        if t.contains("medical") || t.contains("sick") || t == "mc" { return "MC" }
        if t.contains("no pay") || t.contains("unpaid") || t == "npl" { return "NPL" }
        if t.contains("childcare") { return "CCL" }
        if t.contains("compassionate") { return "CL" }
        if t.contains("lieu") { return "Off in lieu" }
        return type!
    }

    /// "2–4pm", "2:30–4pm", "11am–1pm" (Singapore time).
    static func timeRange(_ s: Date, _ e: Date) -> String {
        var c = Calendar(identifier: .gregorian); c.timeZone = sgTimeZone
        func parts(_ d: Date) -> (String, String) {
            let h = c.component(.hour, from: d), m = c.component(.minute, from: d)
            let h12 = h % 12 == 0 ? 12 : h % 12
            return (m == 0 ? "\(h12)" : String(format: "%d:%02d", h12, m), h < 12 ? "am" : "pm")
        }
        let (a, ap) = parts(s), (b, bp) = parts(e)
        return ap == bp ? "\(a)–\(b)\(bp)" : "\(a)\(ap)–\(b)\(bp)"
    }

    /// The calendar day (local midnight) of "2026-11-08T00:00:00Z" / "2026-11-08".
    static func day(_ iso: String?, _ calendar: Calendar) -> Date? {
        guard let iso, iso.count >= 10 else { return nil }
        let p = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    /// A time-off moment: the date's yyyy-MM-dd at "HH:mm" in Singapore time.
    static func time(_ date: String, _ hhmm: String) -> Date? {
        let d = date.prefix(10).split(separator: "-").compactMap { Int($0) }
        let t = hhmm.split(separator: ":").compactMap { Int($0) }
        guard d.count == 3, t.count >= 2 else { return nil }
        var c = Calendar(identifier: .gregorian); c.timeZone = sgTimeZone
        return c.date(from: DateComponents(year: d[0], month: d[1], day: d[2], hour: t[0], minute: t[1]))
    }
}

extension Notification.Name {
    /// Posted when the app returns to the foreground: screens reload their data.
    static let hrmsForeground = Notification.Name("hrmsForeground")
}

// MARK: - EventKit side + scheduling

/// Runs the sync: at sign-in, when the app becomes active, after the user's own request or an
/// approval, on `EKEventStoreChanged`, and every 2 minutes while the app is active. Also owns
/// the "Synced h:mm" time shown in the Calendar header.
@MainActor
final class CalendarAutoSync: ObservableObject {
    static let shared = CalendarAutoSync()

    static let enabledKey = "hrms.calSync.enabled"
    static let calendarIDsKey = "hrms.calSync.calendarIDs"
    static let ownLeaveKey = "hrms.calSync.ownLeave"
    static let ownTimeOffKey = "hrms.calSync.ownTimeOff"
    static let holidaysKey = "hrms.calSync.holidays"
    static let teamLeaveKey = "hrms.calSync.teamLeave"

    /// Last time HRMS data was loaded successfully (calendar screen or a sync run).
    @Published private(set) var lastSynced: Date?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSummary: String?

    private(set) var store = EKEventStore()
    private var signedIn = false
    private var isAdmin = false
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private var lastOwnCommit = Date.distantPast
    private var pendingChange: Task<Void, Never>?

    private var isPreview: Bool { ProcessInfo.processInfo.arguments.contains("-uiPreview") }

    // MARK: Settings

    var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }
    var calendarIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.calendarIDsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Self.calendarIDsKey) }
    }
    var options: CalendarSyncOptions {
        let d = UserDefaults.standard
        return CalendarSyncOptions(ownLeave: d.object(forKey: Self.ownLeaveKey) as? Bool ?? true,
                                   ownTimeOff: d.object(forKey: Self.ownTimeOffKey) as? Bool ?? true,
                                   holidays: d.object(forKey: Self.holidaysKey) as? Bool ?? false,
                                   teamLeave: d.object(forKey: Self.teamLeaveKey) as? Bool ?? false)
    }

    // MARK: Access

    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) { granted = try await store.requestFullAccessToEvents() }
            else { granted = try await store.requestAccess(to: .event) }
            if granted { store = EKEventStore() }   // a store made before access sees no calendars
            return granted
        } catch { return false }
    }

    var hasFullAccess: Bool {
        let s = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) { return s == .fullAccess }
        return s == .authorized
    }

    func writableCalendars() -> [EKCalendar] {
        store.calendars(for: .event).filter(\.allowsContentModifications)
    }

    // MARK: Lifecycle

    func onSignedIn(isAdmin: Bool) {
        guard !isPreview else { return }
        signedIn = true
        self.isAdmin = isAdmin
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.storeChanged() }
            }
        }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard UIApplication.shared.applicationState == .active else { return }
                    await self?.runNow()
                }
            }
        }
        Task { await runNow() }
    }

    func onSignedOut() {
        signedIn = false
        timer?.invalidate(); timer = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    /// The Calendar screen loaded HRMS data: refresh the "Synced" caption.
    func noteLoaded() { lastSynced = Date() }

    /// Run soon (after the user's own request or an approval changed HRMS data).
    func kick() { Task { await runNow() } }

    private func storeChanged() {
        // Our own commits also fire this; the diff would be a no-op, so just skip them.
        guard Date().timeIntervalSince(lastOwnCommit) > 5 else { return }
        pendingChange?.cancel()
        pendingChange = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.runNow()
        }
    }

    // MARK: Run

    /// Fetch HRMS data and reconcile every ticked calendar. Never deletes anything when the
    /// HRMS fetch fails.
    func runNow() async {
        guard signedIn, enabled, !isSyncing, hasFullAccess else { return }
        let calendars = calendarIDs.compactMap { store.calendar(withIdentifier: $0) }.filter(\.allowsContentModifications)
        guard !calendars.isEmpty else { return }
        isSyncing = true
        defer { isSyncing = false }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let window = (cal.date(byAdding: .day, value: -60, to: today) ?? today)...(cal.date(byAdding: .day, value: 366, to: today) ?? today)
        let opts = options
        var entries: [TeamLeaveEntry] = [], holidays: [TeamHoliday] = [], timeOff: [TimeOffRequest] = []
        do {
            if opts.ownLeave || opts.holidays || (opts.teamLeave && isAdmin) {
                let years = Set([cal.component(.year, from: window.lowerBound), cal.component(.year, from: today),
                                 cal.component(.year, from: window.upperBound)])
                for y in years.sorted() {
                    let r = try await HRMSAPI.shared.teamCalendar(year: y)
                    entries += r.entries
                    holidays += r.holidays
                }
            }
            if opts.ownTimeOff { timeOff = try await HRMSAPI.shared.timeOff() }
        } catch {
            lastSummary = "Could not reach HRMS — calendar left unchanged."
            return
        }
        lastSynced = Date()

        let items = HRMSCalendarSync.items(entries: entries, holidays: holidays, timeOff: timeOff,
                                           options: opts, isAdmin: isAdmin, window: window)
        let summary = apply(items: items, calendars: calendars, window: window)
        lastSummary = summary
    }

    /// Remove every HRMS-marked event from these calendars (a calendar was unticked or sync
    /// turned off). Other events are never touched.
    func removeAll(fromCalendarIds ids: [String]) {
        guard hasFullAccess else { return }
        let calendars = ids.compactMap { store.calendar(withIdentifier: $0) }.filter(\.allowsContentModifications)
        guard !calendars.isEmpty else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let window = (cal.date(byAdding: .day, value: -60, to: today) ?? today)...(cal.date(byAdding: .day, value: 366, to: today) ?? today)
        _ = apply(items: [], calendars: calendars, window: window)
    }

    /// Reconcile `calendars` with `items` (internal for the EventKit integration test).
    func apply(items: [HRMSCalendarItem], calendars: [EKCalendar], window: ClosedRange<Date>) -> String {
        let predicate = store.predicateForEvents(withStart: window.lowerBound, end: window.upperBound, calendars: calendars)
        var byId: [String: EKEvent] = [:]
        var existing: [ExistingCalendarEvent] = []
        for ev in store.events(matching: predicate) {
            guard let key = HRMSCalendarSync.markerKey(in: ev.notes), let id = ev.eventIdentifier,
                  byId[id] == nil, let calId = ev.calendar?.calendarIdentifier else { continue }
            byId[id] = ev
            existing.append(ExistingCalendarEvent(
                eventId: id, calendarId: calId, key: key,
                fingerprint: HRMSCalendarSync.fingerprint(title: ev.title ?? "", start: ev.startDate, end: ev.endDate,
                                                          allDay: ev.isAllDay, notes: ev.notes ?? "")))
        }
        let actions = HRMSCalendarSync.plan(items: items, existing: existing,
                                            calendarIds: calendars.map(\.calendarIdentifier))
        guard !actions.isEmpty else { return "Up to date." }
        let itemsByKey = Dictionary(items.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        var created = 0, updated = 0, deleted = 0
        for a in actions {
            switch a {
            case let .create(key, calendarId):
                guard let item = itemsByKey[key], let c = store.calendar(withIdentifier: calendarId) else { continue }
                let ev = EKEvent(eventStore: store)
                ev.calendar = c
                write(item, to: ev)
                if (try? store.save(ev, span: .thisEvent, commit: false)) != nil { created += 1 }
            case let .update(key, eventId):
                guard let item = itemsByKey[key], let ev = byId[eventId] else { continue }
                write(item, to: ev)
                if (try? store.save(ev, span: .thisEvent, commit: false)) != nil { updated += 1 }
            case let .delete(eventId):
                guard let ev = byId[eventId], HRMSCalendarSync.markerKey(in: ev.notes) != nil else { continue }
                if (try? store.remove(ev, span: .thisEvent, commit: false)) != nil { deleted += 1 }
            }
        }
        lastOwnCommit = Date()
        try? store.commit()
        return [(created, "added"), (updated, "updated"), (deleted, "removed")]
            .filter { $0.0 > 0 }.map { "\($0.0) \($0.1)" }.joined(separator: ", ")
    }

    private func write(_ item: HRMSCalendarItem, to ev: EKEvent) {
        ev.title = item.title
        ev.isAllDay = item.allDay
        ev.startDate = item.start
        ev.endDate = item.end
        if !item.allDay { ev.timeZone = HRMSCalendarSync.sgTimeZone }
        ev.notes = item.eventNotes
    }
}
