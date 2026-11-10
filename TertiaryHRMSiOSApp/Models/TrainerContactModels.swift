import Foundation

// MARK: - Trainer contacts (every signed-in staff member and intern)
// GET /api/mobile/trainers/contacts?q=  → TrainerContactsResponse
// A read-only contact card per trainer: no NRIC, no admin notes. The full directory with
// filters stays in `TrainersView` for Trainer Admins only.

struct TrainerContactsResponse: Decodable {
    let count: Int
    let trainers: [TrainerContact]

    enum CodingKeys: String, CodingKey { case count, trainers }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        trainers = c.lossyArray(TrainerContact.self, .trainers)
        count = (try? c.decode(Int.self, forKey: .count)) ?? trainers.count
    }
    init(count: Int, trainers: [TrainerContact]) { self.count = count; self.trainers = trainers }
}

struct TrainerContact: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let email: String?
    let phone: String?
    let trainingCerts: [String]
    let skills: [String]
    let courseTitles: [String]
    let lastClassDate: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email, phone, trainingCerts, skills, courseTitles, lastClassDate
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.str(.id) ?? UUID().uuidString
        name = c.str(.name) ?? "Trainer"
        email = c.str(.email)
        phone = c.str(.phone)
        trainingCerts = c.strings(.trainingCerts)
        skills = c.strings(.skills)
        courseTitles = c.strings(.courseTitles)
        lastClassDate = c.str(.lastClassDate)
    }
    init(id: String, name: String, email: String? = nil, phone: String? = nil, trainingCerts: [String] = [],
         skills: [String] = [], courseTitles: [String] = [], lastClassDate: String? = nil) {
        self.id = id; self.name = name; self.email = email; self.phone = phone
        self.trainingCerts = trainingCerts; self.skills = skills
        self.courseTitles = courseTitles; self.lastClassDate = lastClassDate
    }

    /// One line under the name: courses first, then skills.
    var summaryLine: String {
        let parts = courseTitles.isEmpty ? skills : courseTitles
        return parts.prefix(3).joined(separator: " · ")
    }

    /// Digits only, e.g. "+65 9123 4567" → "6591234567".
    var phoneDigits: String { (phone ?? "").filter(\.isNumber) }

    /// WhatsApp link for a Singapore mobile (8 digits, or 65 + 8 digits).
    var whatsAppURL: URL? {
        let d = phoneDigits
        let local: String
        if d.count == 8 { local = d }
        else if d.count == 10, d.hasPrefix("65") { local = String(d.dropFirst(2)) }
        else { return nil }
        guard local.first == "8" || local.first == "9" else { return nil }
        return URL(string: "https://wa.me/65\(local)")
    }

    var telURL: URL? { phoneDigits.isEmpty ? nil : URL(string: "tel:\(phone!.filter { $0.isNumber || $0 == "+" })") }
    var mailURL: URL? {
        guard let e = email, e.contains("@") else { return nil }
        return URL(string: "mailto:\(e)")
    }
}
