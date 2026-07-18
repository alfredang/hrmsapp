import SwiftUI

/// Timesheet — a simple clock in / out with a live elapsed timer and a
/// last-7-days log. This is the employee's day-to-day time record; it reuses
/// the attendance clock experience (`ClockView`, backed by
/// /api/mobile/attendance) so there is one place to punch in and out.
struct TimesheetView: View {
    var body: some View { ClockView() }
}
