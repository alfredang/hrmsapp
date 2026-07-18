import Foundation

/// Client-side working-days preview for the Apply-Leave form. Mirrors the
/// server's rule (weekends + SG public holidays excluded) purely to show the
/// user a live count before they submit — the server remains the source of
/// truth for the actual deduction.
enum WorkingDays {
    struct Result {
        let calendarDays: Int
        let workingDays: Int
        let weekendsSkipped: Int
        let holidaysSkipped: Int
        /// True when every day in the range is a non-working day.
        var allNonWorking: Bool { calendarDays > 0 && workingDays == 0 }
    }

    /// Counts working days in `start...end` inclusive, excluding Sat/Sun and any
    /// date whose `yyyy-MM-dd` key is in `holidayKeys`. Uses a UTC calendar so a
    /// date never lands on the wrong day across time zones.
    static func compute(start: Date, end: Date, holidayKeys: Set<String>) -> Result {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end)
        guard s <= e else { return Result(calendarDays: 0, workingDays: 0, weekendsSkipped: 0, holidaysSkipped: 0) }

        let key = DateFormatter()
        key.calendar = cal; key.locale = Locale(identifier: "en_US_POSIX")
        key.timeZone = cal.timeZone; key.dateFormat = "yyyy-MM-dd"

        var calendarDays = 0, working = 0, weekends = 0, holidays = 0
        var d = s
        while d <= e {
            calendarDays += 1
            let weekday = cal.component(.weekday, from: d) // 1 = Sun, 7 = Sat
            let isWeekend = weekday == 1 || weekday == 7
            let isHoliday = holidayKeys.contains(key.string(from: d))
            if isWeekend { weekends += 1 }
            else if isHoliday { holidays += 1 }
            else { working += 1 }
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return Result(calendarDays: calendarDays, workingDays: working,
                      weekendsSkipped: weekends, holidaysSkipped: holidays)
    }
}
