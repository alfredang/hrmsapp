import SwiftUI
import PDFKit

/// Payslips list — personal payslips from /api/mobile/payslips.
struct PayslipsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var state: LoadState<PayslipsResponse> = .idle

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(spacing: 12) {
                        // Admins and accountants: the CPF statements the payslips come from.
                        if auth.showsCpfSubmissions {
                            NavigationLink(destination: CpfSubmissionsView()) { cpfRow }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("payslips.cpfSubmissions")
                        }
                        if data.payslips.isEmpty {
                            EmptyHint(icon: "doc.text", text: "No payslips available yet.")
                        }
                        ForEach(data.payslips) { p in
                            NavigationLink(destination: PayslipPDFView(payslip: p)) { row(p) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("payslip.row.\(p.id)")
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
    }

    private var cpfRow: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "building.columns.fill").foregroundStyle(Theme.sky).frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text("CPF Submissions").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text("Monthly CPF EZPay statements").font(.caption).foregroundStyle(Theme.mist)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.ink.opacity(0.4))
            }
        }
    }

    private func row(_ p: Payslip) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Self.period(p)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        Text("Paid \(Fmt.date(p.paymentDate))").font(.caption).foregroundStyle(Theme.ink.opacity(0.7))
                    }
                    Spacer()
                    StatusPill(status: p.status)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.ink.opacity(0.4))
                }
                Divider()
                PayslipBreakdownView(payslip: p)
            }
        }
    }

    static func period(_ p: Payslip) -> String {
        guard let d = Fmt.dateObj(p.payPeriodStart) else { return "Payslip" }
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: d)
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.payslips()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}

/// Renders the authenticated payslip PDF natively with PDFKit.
struct PayslipPDFView: View {
    @EnvironmentObject private var auth: AuthViewModel
    let payslip: Payslip
    @State private var data: Data?
    @State private var error: String?

    var body: some View {
        GradientScreen {
            VStack(spacing: 0) {
                // The pay figures first, then the payslip PDF below.
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(PayslipsView.period(payslip)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        PayslipBreakdownView(payslip: payslip)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
                .accessibilityIdentifier("payslip.breakdown")

                if let data {
                    PDFKitView(data: data).ignoresSafeArea(edges: .bottom)
                } else if let error {
                    VStack(spacing: 14) {
                        Image(systemName: "doc.questionmark").font(.largeTitle).foregroundStyle(Theme.ink.opacity(0.8))
                        Text(error).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.8)).multilineTextAlignment(.center)
                    }.padding(32)
                    Spacer()
                } else {
                    Spacer()
                    ProgressView().tint(Theme.premier)
                    Spacer()
                }
            }
        }
        .navigationTitle("Payslip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Admins and accountants: the CPF statement this payslip was generated from.
            if auth.showsCpfSubmissions, let cpf = payslip.cpfSubmission {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        CpfStatementPDFView(title: cpf.title, path: cpf.downloadPath, fileName: cpf.name)
                    } label: {
                        Label("CPF statement", systemImage: "doc.richtext").labelStyle(.titleAndIcon)
                    }
                    .accessibilityIdentifier("payslip.cpfStatement")
                }
            }
        }
        .task {
            do { data = try await HRMSAPI.shared.downloadPDF(path: payslip.pdfPath) }
            catch { self.error = "Could not load this payslip PDF." }
        }
    }
}

/// A payslip's figures (`Payslip.breakdown`): gross pay, payback added back, unpaid leave, CPF
/// (staff: employee, employer, total; interns: none) and take-home pay, emphasised.
struct PayslipBreakdownView: View {
    let payslip: Payslip

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(payslip.breakdown) { line in
                if line.style == .total { Divider() }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(line.label)
                            .font(line.style == .total ? .subheadline.weight(.bold) : .footnote)
                            .foregroundStyle(line.style == .info && line.value == nil ? Theme.mist : Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if let note = line.note {
                            Text(note).font(.caption2).foregroundStyle(Theme.mist)
                        }
                    }
                    Spacer(minLength: 8)
                    if let value = line.value {
                        Text(value)
                            .font(line.style == .total ? .headline.weight(.bold) : .footnote.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(color(line.style))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("payslip.line.\(line.id)")
            }
        }
    }

    private func color(_ style: PayslipLine.Style) -> Color {
        switch style {
        case .addition, .total: return Theme.success
        case .deduction: return Theme.danger
        case .info: return Theme.mist
        case .plain: return Theme.ink
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.backgroundColor = .clear
        v.document = PDFDocument(data: data)
        return v
    }
    func updateUIView(_ v: PDFView, context: Context) {
        if v.document == nil { v.document = PDFDocument(data: data) }
    }
}
