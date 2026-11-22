import Foundation

// The details behind the accountant Home's Finance card (Alfred, 22 Nov 2026: "click on the
// expenses, income and bank reconciliation, bank statement to see the details").
// Income / expenses and statements: /api/mobile/finance/*; reconciliation: the web's
// /api/accounting/reconciliation (runs) and /api/accounting/reconciliation/{id} (lines).
// Admin / accountant only, enforced by the server. Decoded leniently: the server sends money as
// a number on the mobile routes and as a Decimal string on the accounting routes.

/// A number or a numeric string ("1234.50"); nil when absent or unreadable.
private func flexibleDouble<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
    if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
    if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s) }
    return nil
}

enum BankDirection: String {
    case credit = "CREDIT", debit = "DEBIT"
    var title: String { self == .credit ? "Income" : "Expenses" }
    var noun: String { self == .credit ? "credit" : "debit" }
}

/// `GET /api/mobile/finance/transactions?direction=&month=`: one month of bank credits or debits.
struct BankTransactionsMonth: Decodable {
    let month: String
    let direction: String
    let count: Int
    let total: Double
    let transactions: [BankTransaction]
}

struct BankTransaction: Decodable, Identifiable, Equatable {
    let id: String
    let paymentDate: String
    let title: String
    let amount: Double
    let direction: String
    var type: String?
    var paymentType: String?
    var paymentRef: String?
    var invoiceNo: String?
    var status: String?
    var remarks: String?
    var rawDescription: String?
    var statementRef: String?

    init(id: String, paymentDate: String, title: String, amount: Double, direction: String,
         type: String? = nil, paymentType: String? = nil, paymentRef: String? = nil, invoiceNo: String? = nil,
         status: String? = nil, remarks: String? = nil, rawDescription: String? = nil, statementRef: String? = nil) {
        self.id = id; self.paymentDate = paymentDate; self.title = title; self.amount = amount
        self.direction = direction; self.type = type; self.paymentType = paymentType; self.paymentRef = paymentRef
        self.invoiceNo = invoiceNo; self.status = status; self.remarks = remarks
        self.rawDescription = rawDescription; self.statementRef = statementRef
    }

    private enum K: String, CodingKey {
        case id, paymentDate, title, amount, direction, type, paymentType, paymentRef, invoiceNo, status,
             remarks, rawDescription, statementRef
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        id = try c.decode(String.self, forKey: .id)
        paymentDate = String(((try? c.decode(String.self, forKey: .paymentDate)) ?? "").prefix(10))
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        amount = flexibleDouble(c, .amount) ?? 0
        direction = (try? c.decodeIfPresent(String.self, forKey: .direction)) ?? ""
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        paymentType = try? c.decodeIfPresent(String.self, forKey: .paymentType)
        paymentRef = try? c.decodeIfPresent(String.self, forKey: .paymentRef)
        invoiceNo = try? c.decodeIfPresent(String.self, forKey: .invoiceNo)
        status = try? c.decodeIfPresent(String.self, forKey: .status)
        remarks = try? c.decodeIfPresent(String.self, forKey: .remarks)
        rawDescription = try? c.decodeIfPresent(String.self, forKey: .rawDescription)
        statementRef = try? c.decodeIfPresent(String.self, forKey: .statementRef)
    }

    /// The bank's title, else the first line of the raw statement text.
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        return rawDescription?.split(separator: "\n").first.map(String.init) ?? "Bank transaction"
    }

    /// Search over title, statement text, type, references and remarks (case-insensitive).
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return true }
        return [title, rawDescription, type, paymentRef, invoiceNo, remarks]
            .compactMap { $0?.lowercased() }.contains { $0.contains(q) }
    }
}

/// `GET /api/mobile/finance/statements`: one entry per bank statement import, newest first.
struct StatementImportsResponse: Decodable {
    let imports: [StatementImport]
}

struct StatementImport: Decodable, Identifiable, Equatable {
    let batchId: String
    var importedAt: String?
    var from: String?
    var to: String?
    var credits: Int
    var debits: Int
    var creditTotal: Double
    var debitTotal: Double
    var statementRef: String?
    var id: String { batchId }

    init(batchId: String, importedAt: String?, from: String?, to: String?, credits: Int, debits: Int,
         creditTotal: Double, debitTotal: Double, statementRef: String? = nil) {
        self.batchId = batchId; self.importedAt = importedAt; self.from = from; self.to = to
        self.credits = credits; self.debits = debits; self.creditTotal = creditTotal; self.debitTotal = debitTotal
        self.statementRef = statementRef
    }

    private enum K: String, CodingKey {
        case batchId, importedAt, from, to, credits, debits, creditTotal, debitTotal, statementRef
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        batchId = try c.decode(String.self, forKey: .batchId)
        importedAt = try? c.decodeIfPresent(String.self, forKey: .importedAt)
        from = try? c.decodeIfPresent(String.self, forKey: .from)
        to = try? c.decodeIfPresent(String.self, forKey: .to)
        credits = (try? c.decodeIfPresent(Int.self, forKey: .credits)) ?? 0
        debits = (try? c.decodeIfPresent(Int.self, forKey: .debits)) ?? 0
        creditTotal = flexibleDouble(c, .creditTotal) ?? 0
        debitTotal = flexibleDouble(c, .debitTotal) ?? 0
        statementRef = try? c.decodeIfPresent(String.self, forKey: .statementRef)
    }

    var lines: Int { credits + debits }
}

/// `GET /api/accounting/reconciliation`: the latest runs, newest first.
struct ReconciliationRunsResponse: Decodable {
    let runs: [ReconciliationRun]
}

struct ReconciliationRun: Decodable, Identifiable, Equatable {
    let id: String
    let periodStart: String
    let periodEnd: String
    let status: String
    var trigger: String?
    var bankAccountLabel: String?
    var qbAccountName: String?
    var bankCount: Int
    var qbCount: Int
    var matchedCount: Int
    var mismatchCount: Int
    var unmatchedBankCount: Int
    var unmatchedQbCount: Int
    var reviewedCount: Int
    var matchRate: Double
    var bankClosingBalance: Double?
    var qbClosingBalance: Double?
    var error: String?
    var createdAt: String?

    init(id: String, periodStart: String, periodEnd: String, status: String, bankCount: Int, qbCount: Int,
         matchedCount: Int, mismatchCount: Int, unmatchedBankCount: Int, unmatchedQbCount: Int,
         reviewedCount: Int, matchRate: Double, createdAt: String?) {
        self.id = id; self.periodStart = periodStart; self.periodEnd = periodEnd; self.status = status
        self.bankCount = bankCount; self.qbCount = qbCount; self.matchedCount = matchedCount
        self.mismatchCount = mismatchCount; self.unmatchedBankCount = unmatchedBankCount
        self.unmatchedQbCount = unmatchedQbCount; self.reviewedCount = reviewedCount
        self.matchRate = matchRate; self.createdAt = createdAt
    }

    private enum K: String, CodingKey {
        case id, periodStart, periodEnd, status, trigger, bankAccountLabel, qbAccountName, bankCount, qbCount,
             matchedCount, mismatchCount, unmatchedBankCount, unmatchedQbCount, reviewedCount, matchRate,
             bankClosingBalance, qbClosingBalance, error, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        id = try c.decode(String.self, forKey: .id)
        periodStart = (try? c.decode(String.self, forKey: .periodStart)) ?? ""
        periodEnd = (try? c.decode(String.self, forKey: .periodEnd)) ?? ""
        status = (try? c.decode(String.self, forKey: .status)) ?? ""
        trigger = try? c.decodeIfPresent(String.self, forKey: .trigger)
        bankAccountLabel = try? c.decodeIfPresent(String.self, forKey: .bankAccountLabel)
        qbAccountName = try? c.decodeIfPresent(String.self, forKey: .qbAccountName)
        let int = { (k: K) in (try? c.decodeIfPresent(Int.self, forKey: k)) ?? 0 }
        bankCount = int(.bankCount); qbCount = int(.qbCount); matchedCount = int(.matchedCount)
        mismatchCount = int(.mismatchCount); unmatchedBankCount = int(.unmatchedBankCount)
        unmatchedQbCount = int(.unmatchedQbCount); reviewedCount = int(.reviewedCount)
        matchRate = flexibleDouble(c, .matchRate) ?? 0
        bankClosingBalance = flexibleDouble(c, .bankClosingBalance)
        qbClosingBalance = flexibleDouble(c, .qbClosingBalance)
        error = try? c.decodeIfPresent(String.self, forKey: .error)
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

/// `GET /api/accounting/reconciliation/{id}`: the run and every line (bank, QuickBooks or both).
struct ReconciliationDetail: Decodable {
    let run: ReconciliationRun
    let items: [ReconciliationItem]
}

struct ReconciliationItem: Decodable, Identifiable, Equatable {
    let id: String
    let status: String
    var matchMethod: String?
    var bankDate: String?
    var bankAmount: Double?
    var bankDirection: String?
    var bankDescription: String?
    var qbTxnType: String?
    var qbDate: String?
    var qbAmount: Double?
    var qbDirection: String?
    var qbDocNumber: String?
    var qbPayee: String?
    var qbMemo: String?
    var amountDifference: Double?
    var dayDifference: Int?
    var reviewed: Bool
    var reviewNote: String?

    init(id: String, status: String, bankDate: String? = nil, bankAmount: Double? = nil, bankDirection: String? = nil,
         bankDescription: String? = nil, qbTxnType: String? = nil, qbDate: String? = nil, qbAmount: Double? = nil,
         qbDirection: String? = nil, qbDocNumber: String? = nil, qbPayee: String? = nil, reviewed: Bool = false) {
        self.id = id; self.status = status; self.bankDate = bankDate; self.bankAmount = bankAmount
        self.bankDirection = bankDirection; self.bankDescription = bankDescription; self.qbTxnType = qbTxnType
        self.qbDate = qbDate; self.qbAmount = qbAmount; self.qbDirection = qbDirection
        self.qbDocNumber = qbDocNumber; self.qbPayee = qbPayee; self.reviewed = reviewed
    }

    private enum K: String, CodingKey {
        case id, status, matchMethod, bankDate, bankAmount, bankDirection, bankDescription, qbTxnType, qbDate,
             qbAmount, qbDirection, qbDocNumber, qbPayee, qbMemo, amountDifference, dayDifference, reviewed, reviewNote
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        id = try c.decode(String.self, forKey: .id)
        status = (try? c.decode(String.self, forKey: .status)) ?? ""
        let str = { (k: K) in (try? c.decodeIfPresent(String.self, forKey: k)) ?? nil }
        matchMethod = str(.matchMethod); bankDate = str(.bankDate); bankDirection = str(.bankDirection)
        bankDescription = str(.bankDescription); qbTxnType = str(.qbTxnType); qbDate = str(.qbDate)
        qbDirection = str(.qbDirection); qbDocNumber = str(.qbDocNumber); qbPayee = str(.qbPayee)
        qbMemo = str(.qbMemo); reviewNote = str(.reviewNote)
        bankAmount = flexibleDouble(c, .bankAmount)
        qbAmount = flexibleDouble(c, .qbAmount)
        amountDifference = flexibleDouble(c, .amountDifference)
        dayDifference = (try? c.decodeIfPresent(Int.self, forKey: .dayDifference)) ?? nil
        reviewed = (try? c.decodeIfPresent(Bool.self, forKey: .reviewed)) ?? false
    }

    /// Needs a person's eye: not a match and not yet reviewed (the Home tile's "to review").
    var needsReview: Bool { status != "MATCHED" && !reviewed }
    var date: String? { bankDate ?? qbDate }
    var amount: Double? { bankAmount ?? qbAmount }
    var direction: String? { bankDirection ?? qbDirection }
    var displayTitle: String {
        let bank = bankDescription?.split(separator: "\n").first.map(String.init)
        return [bank, qbPayee, qbDocNumber.map { "QuickBooks \($0)" }].compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? "Reconciliation line"
    }
}

/// The reconciliation line filters, in the order a reviewer works through them.
enum ReconciliationFilter: String, CaseIterable, Identifiable {
    case toReview, mismatch, bankOnly, qbOnly, matched, all
    var id: String { rawValue }

    var title: String {
        switch self {
        case .toReview: return "To review"
        case .mismatch: return "Amount differs"
        case .bankOnly: return "Bank only"
        case .qbOnly: return "QuickBooks only"
        case .matched: return "Matched"
        case .all: return "All lines"
        }
    }

    func includes(_ i: ReconciliationItem) -> Bool {
        switch self {
        case .toReview: return i.needsReview
        case .mismatch: return i.status == "AMOUNT_MISMATCH"
        case .bankOnly: return i.status == "UNMATCHED_BANK"
        case .qbOnly: return i.status == "UNMATCHED_QB"
        case .matched: return i.status == "MATCHED"
        case .all: return true
        }
    }

    static func label(forStatus s: String) -> String {
        switch s {
        case "MATCHED": return "Matched"
        case "AMOUNT_MISMATCH": return "Amount differs"
        case "UNMATCHED_BANK": return "Bank only"
        case "UNMATCHED_QB": return "QuickBooks only"
        default: return s.capitalized
        }
    }
}
