import Foundation

// MARK: - Trainer directory (Trainer Admins only)
// GET /api/mobile/trainers?q=&cert=&tag=&finance=1&ibfFit=1&status=  → TrainersResponse
// GET /api/mobile/trainers/{id}                                        → TrainerDetailResponse
// Decoded leniently: the profile is assembled by an importer, so any list may be missing
// or null and the JSON columns (courses, classes) are free-form. One odd field must never
// fail the whole screen.

/// Accreditation flags shown on every trainer (server `TRAINING_CERTS`).
enum TrainingCert: String, CaseIterable, Identifiable {
    case aclp = "ACLP", acta = "ACTA", dace = "DACE", dddlp = "DDDLP"
    var id: String { rawValue }
    var fullName: String {
        switch self {
        case .aclp: return "Advanced Certificate in Learning and Performance"
        case .acta: return "Advanced Certificate in Training and Assessment"
        case .dace: return "Diploma in Adult and Continuing Education"
        case .dddlp: return "Diploma in Design and Delivery of Learning and Performance"
        }
    }
}

struct TrainersResponse: Decodable {
    let count: Int
    let trainers: [TrainerListItem]

    enum CodingKeys: String, CodingKey { case count, trainers }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        trainers = (try? c.decode([TrainerListItem].self, forKey: .trainers)) ?? []
        count = (try? c.decode(Int.self, forKey: .count)) ?? trainers.count
    }
    init(count: Int, trainers: [TrainerListItem]) { self.count = count; self.trainers = trainers }
}

struct TrainerListItem: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let nickname: String?
    let phone: String?
    let email: String?
    let trainerType: String?
    let status: String
    let inTms: Bool
    let trainingCerts: [String]
    let certifications: [String]
    let skills: [String]
    let education: String?
    let summary: String?
    let financeBackground: Bool
    let ibfFitDeclaration: Bool
    let classesCount: Int
    let lastClassDate: String?
    let courseTitles: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, nickname, phone, email, trainerType, status, inTms, trainingCerts,
             certifications, skills, education, summary, financeBackground, ibfFitDeclaration,
             classesCount, lastClassDate, courseTitles
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "—"
        nickname = c.str(.nickname)
        phone = c.str(.phone)
        email = c.str(.email)
        trainerType = c.str(.trainerType)
        status = c.str(.status) ?? "Active"
        inTms = c.bool(.inTms)
        trainingCerts = c.strings(.trainingCerts)
        certifications = c.strings(.certifications)
        skills = c.strings(.skills)
        education = c.str(.education)
        summary = c.str(.summary)
        financeBackground = c.bool(.financeBackground)
        ibfFitDeclaration = c.bool(.ibfFitDeclaration)
        classesCount = c.int(.classesCount)
        lastClassDate = c.str(.lastClassDate)
        courseTitles = c.strings(.courseTitles)
    }

    init(id: String, name: String, nickname: String? = nil, phone: String? = nil, email: String? = nil,
         trainerType: String? = nil, status: String = "Active", inTms: Bool = true,
         trainingCerts: [String] = [], certifications: [String] = [], skills: [String] = [],
         education: String? = nil, summary: String? = nil, financeBackground: Bool = false,
         ibfFitDeclaration: Bool = false, classesCount: Int = 0, lastClassDate: String? = nil,
         courseTitles: [String] = []) {
        self.id = id; self.name = name; self.nickname = nickname; self.phone = phone
        self.email = email; self.trainerType = trainerType; self.status = status; self.inTms = inTms
        self.trainingCerts = trainingCerts; self.certifications = certifications; self.skills = skills
        self.education = education; self.summary = summary; self.financeBackground = financeBackground
        self.ibfFitDeclaration = ibfFitDeclaration; self.classesCount = classesCount
        self.lastClassDate = lastClassDate; self.courseTitles = courseTitles
    }

    /// Professional certs first, then skills — the row's "top tags".
    func topTags(_ limit: Int = 4) -> [String] { Array((certifications + skills).prefix(limit)) }
}

struct TrainerDetailResponse: Decodable {
    let trainer: TrainerDetail
}

struct TrainerDetail: Decodable, Identifiable {
    let id: String
    let name: String
    let nickname: String?
    let nric: String?
    let phone: String?
    let email: String?
    let secondaryEmail: String?
    let nationality: String?
    let linkedinUrl: String?
    let trainerType: String?
    let status: String
    let inTms: Bool
    let trainingCerts: [String]
    let certifications: [String]
    let skills: [String]
    let education: String?
    let experience: [String]
    let summary: String?
    let financeBackground: Bool
    let financeEvidence: [String]
    let ibfFitDeclaration: Bool
    let ibfFitFiles: [String]
    let actaFolder: String?
    let evidenceFiles: [String]
    let courses: [TrainerCourse]
    let recentClasses: [TrainerRecentClass]
    let calendarClasses: [TrainerCalendarClass]
    let classesCount: Int
    let lastClassDate: String?
    let adminNotes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, nickname, nric, phone, email, secondaryEmail, nationality, linkedinUrl,
             trainerType, status, inTms, trainingCerts, certifications, skills, education, experience,
             summary, financeBackground, financeEvidence, ibfFitDeclaration, ibfFitFiles, actaFolder,
             evidenceFiles, courses, recentClasses, calendarClasses, classesCount, lastClassDate, adminNotes
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "—"
        nickname = c.str(.nickname)
        nric = c.str(.nric)
        phone = c.str(.phone)
        email = c.str(.email)
        secondaryEmail = c.str(.secondaryEmail)
        nationality = c.str(.nationality)
        linkedinUrl = c.str(.linkedinUrl)
        trainerType = c.str(.trainerType)
        status = c.str(.status) ?? "Active"
        inTms = c.bool(.inTms)
        trainingCerts = c.strings(.trainingCerts)
        certifications = c.strings(.certifications)
        skills = c.strings(.skills)
        education = c.str(.education)
        experience = c.strings(.experience)
        summary = c.str(.summary)
        financeBackground = c.bool(.financeBackground)
        financeEvidence = c.strings(.financeEvidence)
        ibfFitDeclaration = c.bool(.ibfFitDeclaration)
        ibfFitFiles = c.strings(.ibfFitFiles)
        actaFolder = c.str(.actaFolder)
        evidenceFiles = c.strings(.evidenceFiles)
        courses = c.lossyArray(TrainerCourse.self, .courses)
        recentClasses = c.lossyArray(TrainerRecentClass.self, .recentClasses)
        calendarClasses = c.lossyArray(TrainerCalendarClass.self, .calendarClasses)
        classesCount = c.int(.classesCount)
        lastClassDate = c.str(.lastClassDate)
        adminNotes = c.str(.adminNotes)
    }

    /// Masked NRIC: first letter + **** + last 4 (server `maskNric`).
    var maskedNric: String { Self.mask(nric) }

    static func mask(_ nric: String?) -> String {
        guard let n = nric?.trimmingCharacters(in: .whitespaces), !n.isEmpty else { return "" }
        guard n.count >= 6 else { return "****" }
        return "\(n.prefix(1))****\(n.suffix(4))"
    }
}

struct TrainerCourse: Decodable, Identifiable {
    let title: String
    let code: String?
    let classes: Int
    let first: String?
    let last: String?
    var id: String { "\(code ?? "")|\(title)" }

    enum CodingKeys: String, CodingKey { case title, code, classes, first, last }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        title = c.str(.title) ?? "Untitled course"
        code = c.str(.code)
        classes = c.int(.classes)
        first = c.str(.first)
        last = c.str(.last)
    }
    init(title: String, code: String?, classes: Int, first: String?, last: String?) {
        self.title = title; self.code = code; self.classes = classes; self.first = first; self.last = last
    }
}

struct TrainerRecentClass: Decodable, Identifiable {
    let start: String?
    let title: String
    let run: String?
    let status: String?
    var id: String { "\(start ?? "")|\(title)|\(run ?? "")" }

    enum CodingKeys: String, CodingKey { case start, title, run, status }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        start = c.str(.start)
        title = c.str(.title) ?? "Class"
        run = c.str(.run)
        status = c.str(.status)
    }
    init(start: String?, title: String, run: String?, status: String?) {
        self.start = start; self.title = title; self.run = run; self.status = status
    }
}

struct TrainerCalendarClass: Decodable, Identifiable {
    let date: String?
    let title: String
    let calendar: String?
    var id: String { "\(date ?? "")|\(title)" }

    enum CodingKeys: String, CodingKey { case date, title, calendar }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        date = c.str(.date)
        title = c.str(.title) ?? "Class"
        calendar = c.str(.calendar)
    }
}

/// Server-side filters for the directory list.
struct TrainerFilter: Equatable {
    enum Status: String, CaseIterable, Identifiable {
        case all, trainers, applicants
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }
    var query = ""
    var certs: Set<TrainingCert> = []
    var finance = false
    var ibfFit = false
    var status: Status = .all

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
        for cert in TrainingCert.allCases where certs.contains(cert) {
            items.append(URLQueryItem(name: "cert", value: cert.rawValue))
        }
        if finance { items.append(URLQueryItem(name: "finance", value: "1")) }
        if ibfFit { items.append(URLQueryItem(name: "ibfFit", value: "1")) }
        if status != .all { items.append(URLQueryItem(name: "status", value: status.rawValue)) }
        return items
    }
}

// MARK: - Lenient decoding helpers

extension KeyedDecodingContainer {
    /// A non-empty string, or a number rendered as a string (e.g. a class "run" of 3).
    func str(_ k: Key) -> String? {
        if let s = try? decodeIfPresent(String.self, forKey: k) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        if let i = try? decodeIfPresent(Int.self, forKey: k) { return String(i) }
        if let d = try? decodeIfPresent(Double.self, forKey: k) { return String(d) }
        return nil
    }
    func bool(_ k: Key) -> Bool { (try? decodeIfPresent(Bool.self, forKey: k)) ?? false }
    func int(_ k: Key) -> Int {
        if let i = try? decodeIfPresent(Int.self, forKey: k) { return i }
        if let d = try? decodeIfPresent(Double.self, forKey: k) { return Int(d) }
        if let s = try? decodeIfPresent(String.self, forKey: k), let i = Int(s) { return i }
        return 0
    }
    /// A string array with blanks removed; null / missing → [].
    func strings(_ k: Key) -> [String] {
        let raw = (try? decodeIfPresent([String?].self, forKey: k)) ?? []
        return raw.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    /// An array that drops elements that fail to decode instead of failing the whole array.
    func lossyArray<T: Decodable>(_ type: T.Type, _ k: Key) -> [T] {
        guard let wrapped = try? decodeIfPresent([Lossy<T>].self, forKey: k) else { return [] }
        return wrapped.compactMap(\.value)
    }
}

private struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from d: Decoder) throws { value = try? T(from: d) }
}
