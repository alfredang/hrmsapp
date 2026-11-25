import Foundation

// MARK: - CPF EZPay submissions  (/api/mobile/cpf-submissions, web 26 Nov 2026)
//
// The company's monthly CPF filing statements (the PDFs the payslips are generated from), kept in
// the shared CPF Drive folder. Admins (ADMIN / HR / MANAGER) and accountants only: a statement lists
// every employee's NRIC and wages. The server 403s everyone else; the app also hides the entry points
// (`AuthViewModel.showsCpfSubmissions`). Each PDF downloads from `downloadPath` with the same session
// as a payslip's `pdfPath` (`HRMSAPI.downloadPDF`).

struct CpfSubmissionsResponse: Decodable {
    let cpfSubmissions: [CpfSubmission]

    private enum K: String, CodingKey { case cpfSubmissions }

    init(cpfSubmissions: [CpfSubmission]) { self.cpfSubmissions = cpfSubmissions }

    /// Keeps the server's order (latest first). A row without an id, name or download path is dropped
    /// rather than failing the whole list.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        let rows = (try? c.decodeIfPresent([Lenient<CpfSubmission>].self, forKey: .cpfSubmissions)) ?? []
        cpfSubmissions = rows.compactMap(\.value)
    }
}

/// One statement in the list.
struct CpfSubmission: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    var month: Int?
    var year: Int?
    /// "November 2026"; nil when the file name carries no pay period.
    var periodLabel: String?
    var sizeBytes: Int?
    /// ISO-8601 (Drive's createdTime).
    var uploadedAt: String?
    /// "/api/payroll/cpf-submission/files/<id>".
    let downloadPath: String

    init(id: String, name: String, month: Int? = nil, year: Int? = nil, periodLabel: String? = nil,
         sizeBytes: Int? = nil, uploadedAt: String? = nil, downloadPath: String) {
        self.id = id; self.name = name; self.month = month; self.year = year
        self.periodLabel = periodLabel; self.sizeBytes = sizeBytes; self.uploadedAt = uploadedAt
        self.downloadPath = downloadPath
    }

    private enum K: String, CodingKey {
        case id, name, month, year, periodLabel, sizeBytes, uploadedAt, downloadPath
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        downloadPath = try c.decode(String.self, forKey: .downloadPath)
        month = lenientInt(c, .month)
        year = lenientInt(c, .year)
        periodLabel = try? c.decodeIfPresent(String.self, forKey: .periodLabel)
        sizeBytes = lenientInt(c, .sizeBytes)
        uploadedAt = try? c.decodeIfPresent(String.self, forKey: .uploadedAt)
    }

    /// Row title: the pay period, or the file name when the server could not read one.
    var title: String {
        if let p = periodLabel?.trimmingCharacters(in: .whitespaces), !p.isEmpty { return p }
        return name
    }

    /// Row secondary line: file name · uploaded date · size (each only when known).
    var detail: String {
        var parts = [name]
        if let uploadedAt, Fmt.dateObj(uploadedAt) != nil { parts.append("Uploaded \(Fmt.date(uploadedAt))") }
        if let sizeBytes, sizeBytes > 0 { parts.append(Self.size(sizeBytes)) }
        return parts.joined(separator: " · ")
    }

    static func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

/// `Payslip.cpfSubmission`: the statement a payslip was generated from (admins and accountants;
/// null for staff and when no statement is on file).
struct CpfSubmissionRef: Codable, Equatable {
    let id: String
    let name: String
    var periodLabel: String?
    let downloadPath: String

    init(id: String, name: String, periodLabel: String? = nil, downloadPath: String) {
        self.id = id; self.name = name; self.periodLabel = periodLabel; self.downloadPath = downloadPath
    }

    private enum CodingKeys: String, CodingKey { case id, name, periodLabel, downloadPath }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        downloadPath = try c.decode(String.self, forKey: .downloadPath)
        periodLabel = try? c.decodeIfPresent(String.self, forKey: .periodLabel)
    }

    var title: String {
        if let p = periodLabel?.trimmingCharacters(in: .whitespaces), !p.isEmpty { return p }
        return name
    }
}

/// Decodes one array element without failing the array: a bad element becomes nil.
private struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

/// An Int sent as a number (or, from an older importer, a numeric string).
private func lenientInt<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Int? {
    if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return i }
    if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(d) }
    if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Int(s) }
    return nil
}
