import Foundation

/// Shared formatting for ISO dates and SGD money coming off the API.
enum Fmt {
    private static let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()

    static func date(_ iso: String?, style: DateFormatter.Style = .medium) -> String {
        guard let iso, let d = parse(iso) else { return "—" }
        let f = DateFormatter(); f.dateStyle = style; f.timeStyle = .none
        return f.string(from: d)
    }

    static func dateObj(_ iso: String?) -> Date? { iso.flatMap(parse) }

    /// Parses a plain `yyyy-MM-dd` calendar date (e.g. from /api/public-holidays)
    /// in UTC so the day never shifts across time zones.
    private static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func ymdDate(_ s: String) -> Date? { ymd.date(from: s) }

    static func parse(_ iso: String) -> Date? {
        isoFull.date(from: iso) ?? isoPlain.date(from: iso) ?? ymd.date(from: iso)
    }

    static func money(_ v: Double, currency: String = "SGD") -> String {
        let f = NumberFormatter(); f.numberStyle = .currency
        f.currencyCode = currency; f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }

    /// 12 → "12", 12.5 → "12.5".
    static func num(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    /// "20 Jul 2026" / "20 – 22 Jul 2026" / "30 Jul – 2 Aug 2026" — compact for one-line rows.
    static func range(_ start: String?, _ end: String?) -> String {
        guard let s = start.flatMap(parse) else { return "—" }
        let e = end.flatMap(parse) ?? s
        let cal = Calendar.current
        let full = DateFormatter(); full.dateFormat = "d MMM yyyy"
        if cal.isDate(s, inSameDayAs: e) { return full.string(from: s) }
        let sameYear = cal.component(.year, from: s) == cal.component(.year, from: e)
        let sameMonth = sameYear && cal.component(.month, from: s) == cal.component(.month, from: e)
        let left = DateFormatter(); left.dateFormat = sameMonth ? "d" : (sameYear ? "d MMM" : "d MMM yyyy")
        return "\(left.string(from: s)) – \(full.string(from: e))"
    }

    /// "8 Nov" (short day for compact rows).
    static func shortDay(_ iso: String?) -> String {
        guard let iso, let d = parse(iso) else { return "—" }
        let f = DateFormatter(); f.dateFormat = "d MMM"
        return f.string(from: d)
    }

    static func days(_ v: Double) -> String {
        let s = v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v)
        return "\(s) day\(v == 1 ? "" : "s")"
    }
}
