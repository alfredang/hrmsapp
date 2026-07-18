import SwiftUI
import PDFKit

/// Payslips list — personal payslips from /api/mobile/payslips.
struct PayslipsView: View {
    @State private var state: LoadState<PayslipsResponse> = .idle

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    VStack(spacing: 12) {
                        if data.payslips.isEmpty {
                            EmptyHint(icon: "doc.text", text: "No payslips available yet.")
                        }
                        ForEach(data.payslips) { p in
                            NavigationLink(destination: PayslipPDFView(payslip: p)) { row(p) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
    }

    private func row(_ p: Payslip) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(period(p)).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text("Paid \(Fmt.date(p.paymentDate))").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(Fmt.money(p.netSalary)).font(.subheadline.weight(.bold)).foregroundStyle(.green)
                    StatusPill(status: p.status)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func period(_ p: Payslip) -> String {
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
    let payslip: Payslip
    @State private var data: Data?
    @State private var error: String?

    var body: some View {
        GradientScreen {
            if let data {
                PDFKitView(data: data).ignoresSafeArea(edges: .bottom)
            } else if let error {
                VStack(spacing: 14) {
                    Image(systemName: "doc.questionmark").font(.largeTitle).foregroundStyle(.white.opacity(0.8))
                    Text(error).font(.subheadline).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
                }.padding(32)
            } else {
                ProgressView().tint(.white)
            }
        }
        .navigationTitle("Payslip")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do { data = try await HRMSAPI.shared.downloadPDF(path: payslip.pdfPath) }
            catch { self.error = "Could not load this payslip PDF." }
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
