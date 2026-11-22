import Foundation

/// The company's Standard Operating Procedures (`GET /api/mobile/sops`, every signed-in employee;
/// web /sop). Shown natively, so no browser sign-in is needed (Alfred, 22 Nov 2026).
struct SopsResponse: Decodable {
    let sops: [Sop]
}

struct Sop: Decodable, Identifiable, Hashable {
    let slug: String
    let title: String
    let category: String
    let summary: String
    var purpose: String?
    var scope: String?
    var owner: String?
    var triggers: [String]?
    var steps: [SopStep]
    var references: [SopReference]?
    var source: String?
    var updatedAt: String?
    var id: String { slug }

    init(slug: String, title: String, category: String, summary: String, purpose: String? = nil, scope: String? = nil,
         owner: String? = nil, triggers: [String]? = nil, steps: [SopStep], references: [SopReference]? = nil,
         source: String? = nil, updatedAt: String? = nil) {
        self.slug = slug; self.title = title; self.category = category; self.summary = summary
        self.purpose = purpose; self.scope = scope; self.owner = owner; self.triggers = triggers
        self.steps = steps; self.references = references; self.source = source; self.updatedAt = updatedAt
    }

    private enum K: String, CodingKey { case slug, title, category, summary, purpose, scope, owner, triggers, steps, references, source, updatedAt }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        slug = try c.decode(String.self, forKey: .slug)
        title = (try? c.decode(String.self, forKey: .title)) ?? slug
        category = (try? c.decode(String.self, forKey: .category)) ?? "Other"
        summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        purpose = try? c.decodeIfPresent(String.self, forKey: .purpose)
        scope = try? c.decodeIfPresent(String.self, forKey: .scope)
        owner = try? c.decodeIfPresent(String.self, forKey: .owner)
        triggers = try? c.decodeIfPresent([String].self, forKey: .triggers)
        steps = (try? c.decodeIfPresent([SopStep].self, forKey: .steps)) ?? []
        references = try? c.decodeIfPresent([SopReference].self, forKey: .references)
        source = try? c.decodeIfPresent(String.self, forKey: .source)
        updatedAt = try? c.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    /// Every word of the query must appear in the title, summary, category, owner or a step (as the web).
    func matches(_ query: String) -> Bool {
        let terms = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return true }
        let hay = ([title, summary, category, owner ?? "", purpose ?? "", scope ?? ""] + (triggers ?? [])
                   + steps.flatMap { [$0.title, $0.detail, $0.owner ?? "", $0.timing ?? "", $0.note ?? ""] + ($0.items ?? []) })
            .joined(separator: " ").lowercased()
        return terms.allSatisfy { hay.contains($0) }
    }
}

struct SopStep: Decodable, Hashable {
    let title: String
    var detail: String
    var items: [String]?
    var owner: String?
    var timing: String?
    var note: String?
    var links: [SopLink]?

    init(title: String, detail: String, items: [String]? = nil, owner: String? = nil, timing: String? = nil,
         note: String? = nil, links: [SopLink]? = nil) {
        self.title = title; self.detail = detail; self.items = items; self.owner = owner
        self.timing = timing; self.note = note; self.links = links
    }

    private enum K: String, CodingKey { case title, detail, items, owner, timing, note, links }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        detail = (try? c.decodeIfPresent(String.self, forKey: .detail)) ?? ""
        items = try? c.decodeIfPresent([String].self, forKey: .items)
        owner = try? c.decodeIfPresent(String.self, forKey: .owner)
        timing = try? c.decodeIfPresent(String.self, forKey: .timing)
        note = try? c.decodeIfPresent(String.self, forKey: .note)
        links = try? c.decodeIfPresent([SopLink].self, forKey: .links)
    }
}

struct SopLink: Decodable, Hashable {
    let label: String
    let href: String
}

struct SopReference: Decodable, Hashable {
    let label: String
    let value: String
    var href: String?
}
