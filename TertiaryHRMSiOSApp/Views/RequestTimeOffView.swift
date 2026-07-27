import SwiftUI

/// Request-time-off form (hourly). Posts to the existing /api/time-off
/// endpoint; the server computes the hours and enforces the business rules.
struct RequestTimeOffView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var start = RequestTimeOffView.defaultTime(hour: 14)
    @State private var end = RequestTimeOffView.defaultTime(hour: 16)
    @State private var reason = "EXAMS"
    @State private var detail = ""
    @State private var submitting = false
    @State private var error: String?
    @State private var done = false
    @FocusState private var detailFocused: Bool

    private static func defaultTime(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    /// "HH:mm" strings compare correctly as strings; the server stores them verbatim.
    private var startHM: String { RequestTimeOffView.hm.string(from: start) }
    private var endHM: String { RequestTimeOffView.hm.string(from: end) }

    private var previewHours: Double? {
        guard endHM > startHM,
              let s = RequestTimeOffView.hm.date(from: startHM),
              let e = RequestTimeOffView.hm.date(from: endHM) else { return nil }
        return e.timeIntervalSince(s) / 3600
    }

    var body: some View {
        NavigationStack {
            GradientScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let error { StatusBanner(kind: .error, text: error) }

                        field("Date") {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .labelsHidden().colorScheme(.dark)
                        }
                        field("From") {
                            DatePicker("", selection: $start, displayedComponents: .hourAndMinute)
                                .labelsHidden().colorScheme(.dark)
                        }
                        field("To") {
                            DatePicker("", selection: $end, displayedComponents: .hourAndMinute)
                                .labelsHidden().colorScheme(.dark)
                        }

                        if let h = previewHours {
                            Text(String(format: "%.1f hour%@ of time off", h, h == 1 ? "" : "s"))
                                .font(.caption).foregroundStyle(Theme.sky)
                        }

                        field("Reason") {
                            Picker("", selection: $reason) {
                                Text("Exams").tag("EXAMS")
                                Text("Emergency").tag("EMERGENCY")
                                Text("Others").tag("OTHERS")
                            }
                            .pickerStyle(.segmented)
                        }

                        if reason == "OTHERS" {
                            field("Details") {
                                TextField("", text: $detail,
                                          prompt: Text("Please describe the reason").foregroundColor(.white.opacity(0.5)),
                                          axis: .vertical)
                                    .lineLimit(2...4).foregroundStyle(.white)
                                    .focused($detailFocused)
                                    .tint(Theme.sky)
                            }
                        }

                        PremierButton(title: "Submit request", systemImage: "paperplane.fill",
                                      loading: submitting, action: submit)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Request time off")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.tint(Theme.sky) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { detailFocused = false }.tint(Theme.sky).fontWeight(.semibold)
                }
            }
            .alert("Request submitted", isPresented: $done) {
                Button("Done") { dismiss() }
            } message: { Text("Your time-off request was submitted for approval.") }
        }
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private static let hm: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private func submit() {
        detailFocused = false
        error = nil

        // Client-side validation, mirroring the web form.
        guard endHM > startHM else {
            error = "End time must be after start time."
            return
        }
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if reason == "OTHERS" && trimmedDetail.isEmpty {
            error = "Please describe the reason when choosing Others."
            return
        }

        submitting = true
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: date)
        let s = startHM, e = endHM
        let detailOut = reason == "OTHERS" ? trimmedDetail : nil
        Task {
            do {
                try await HRMSAPI.shared.submitTimeOff(date: dateStr, startTime: s, endTime: e,
                                                       reason: reason, reasonDetail: detailOut)
                submitting = false; done = true
            } catch {
                submitting = false
                self.error = (error as NSError).localizedDescription
            }
        }
    }
}
