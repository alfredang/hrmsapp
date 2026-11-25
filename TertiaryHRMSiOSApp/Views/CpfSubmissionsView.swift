import SwiftUI

/// "CPF Submissions" (admins and accountants; web 26 Nov 2026): the company's past CPF EZPay
/// statements from `GET /api/mobile/cpf-submissions`, latest first as the server sends them. A tap
/// opens the PDF in the same PDFKit viewer as a payslip, with Share to save or send it.
/// Reached from More → Finance and the top of Payslips, both behind `auth.showsCpfSubmissions`.
struct CpfSubmissionsView: View {
    @State private var state: LoadState<[CpfSubmission]> = .idle
    /// The server said 403 (not an admin or accountant): a polite note instead of the list.
    @State private var notAllowed = false

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { files in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("CPF Submissions").font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        if notAllowed {
                            EmptyHint(icon: "lock.fill", text: "CPF submissions are for admins and accountants only.")
                                .accessibilityIdentifier("cpf.notAllowed")
                        } else if files.isEmpty {
                            EmptyHint(icon: "doc.text.magnifyingglass", text: "No CPF submissions yet")
                                .accessibilityIdentifier("cpf.empty")
                        } else {
                            Text("Monthly CPF EZPay statements, latest first. Each lists every employee's NRIC and wages.")
                                .font(.footnote).foregroundStyle(Theme.mist)
                            Card(padding: 0) {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(files.enumerated()), id: \.element.id) { i, f in
                                        if i > 0 { Divider().padding(.leading, 54) }
                                        NavigationLink {
                                            CpfStatementPDFView(title: f.title, path: f.downloadPath, fileName: f.name)
                                        } label: { row(f) }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("cpf.row.\(f.id)")
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
    }

    private func row(_ f: CpfSubmission) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext.fill")
                .font(.title3).foregroundStyle(Theme.sky)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(f.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(f.detail).font(.caption).foregroundStyle(Theme.mist)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.down.doc")
                .font(.subheadline).foregroundStyle(Theme.sky)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the CPF statement PDF")
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            let files = try await HRMSAPI.shared.cpfSubmissions()
            notAllowed = false
            state = .loaded(files)
        } catch is CancellationError {
        } catch HRMSAPI.APIError.forbidden {
            notAllowed = true
            state = .loaded([])
        } catch HRMSAPI.APIError.http(502) {
            state = .failed("Could not reach the CPF folder on Google Drive. Please try again later.")
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load the CPF submissions.")
        }
    }
}

/// One CPF statement PDF: downloaded with the session (`HRMSAPI.downloadPDF`, as a payslip's
/// `pdfPath`), shown with PDFKit, and shared from a temporary copy that is removed on close.
struct CpfStatementPDFView: View {
    let title: String
    let path: String
    let fileName: String
    @State private var data: Data?
    @State private var fileURL: URL?
    @State private var error: String?

    var body: some View {
        GradientScreen {
            if let data {
                PDFKitView(data: data).ignoresSafeArea(edges: .bottom)
            } else if let error {
                VStack(spacing: 14) {
                    Image(systemName: "doc.questionmark").font(.largeTitle).foregroundStyle(Theme.ink.opacity(0.8))
                    Text(error).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.8)).multilineTextAlignment(.center)
                }.padding(32)
            } else {
                ProgressView().tint(Theme.premier)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let fileURL {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: fileURL) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share or save the PDF")
                        .accessibilityIdentifier("cpf.share")
                }
            }
        }
        .task {
            guard data == nil else { return }
            do {
                let pdf = try await HRMSAPI.shared.downloadPDF(path: path)
                data = pdf
                fileURL = Self.writeTemporary(pdf, name: fileName)
            } catch HRMSAPI.APIError.http(let code) where code == 403 {
                error = "Only admins and accountants can open CPF statements."
            } catch HRMSAPI.APIError.http(let code) where code == 404 {
                error = "This CPF statement is no longer on file."
            } catch {
                self.error = "Could not load this CPF statement."
            }
        }
        .onDisappear {
            if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        }
    }

    /// A temporary copy under the statement's own name, for the share sheet (Save to Files, Mail …).
    static func writeTemporary(_ data: Data, name: String) -> URL? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("CPF", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var safe = name.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if safe.isEmpty { safe = "CPF statement" }
        if !safe.lowercased().hasSuffix(".pdf") { safe += ".pdf" }
        let url = dir.appendingPathComponent(safe)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            return nil
        }
    }
}
