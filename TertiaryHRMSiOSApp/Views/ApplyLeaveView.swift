import SwiftUI

/// Apply-for-leave form. Posts to the existing /api/leave endpoint; the server
/// computes working days, proration, and balance deductions.
struct ApplyLeaveView: View {
    let types: [LeaveType]
    @Environment(\.dismiss) private var dismiss

    @State private var typeId = ""
    @State private var start = Date()
    @State private var end = Date()
    @State private var dayType = "FULL_DAY"
    @State private var reason = ""
    @State private var submitting = false
    @State private var error: String?
    @State private var done = false

    private var isSingleDay: Bool { Calendar.current.isDate(start, inSameDayAs: end) }
    private var isMedical: Bool {
        guard let t = types.first(where: { $0.id == typeId }) else { return false }
        return t.code == "MC" || t.code == "SL" || t.name.localizedCaseInsensitiveContains("medical")
    }

    /// Default the picker to Annual Leave so applying is one tap away.
    private func defaultType() {
        guard typeId.isEmpty else { return }
        typeId = types.first(where: { $0.code == "AL" })?.id ?? types.first?.id ?? ""
    }

    var body: some View {
        NavigationStack {
            GradientScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let error { StatusBanner(kind: .error, text: error) }

                        field("Leave type") {
                            Picker("", selection: $typeId) {
                                Text("Select…").tag("")
                                ForEach(types) { t in Text(t.name).tag(t.id) }
                            }
                            .pickerStyle(.menu).tint(.white)
                        }

                        if isMedical {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("For medical leave, please email your medical certificate to HR or attach it on the web portal.")
                                    .font(.caption)
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(12)
                            .background(.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        field("From") {
                            DatePicker("", selection: $start, displayedComponents: .date)
                                .labelsHidden().colorScheme(.dark)
                        }
                        field("To") {
                            DatePicker("", selection: $end, in: start..., displayedComponents: .date)
                                .labelsHidden().colorScheme(.dark)
                        }

                        if isSingleDay {
                            field("Duration") {
                                Picker("", selection: $dayType) {
                                    Text("Full day").tag("FULL_DAY")
                                    Text("Morning half").tag("AM_HALF")
                                    Text("Afternoon half").tag("PM_HALF")
                                }.pickerStyle(.segmented)
                            }
                        }

                        field("Reason (optional)") {
                            TextField("", text: $reason, prompt: Text("e.g. Family matters").foregroundColor(.white.opacity(0.5)), axis: .vertical)
                                .lineLimit(2...4).foregroundStyle(.white)
                        }

                        PremierButton(title: "Submit request", systemImage: "paperplane.fill",
                                      loading: submitting, enabled: !typeId.isEmpty,
                                      action: submit)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Apply for leave")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.tint(Theme.sky) } }
            .alert("Request submitted", isPresented: $done) {
                Button("Done") { dismiss() }
            } message: { Text("Your leave request was submitted for approval.") }
            .onAppear(perform: defaultType)
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

    private func submit() {
        error = nil; submitting = true
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let s = df.string(from: start), e = df.string(from: end)
        let dt = isSingleDay ? dayType : "FULL_DAY"
        Task {
            do {
                try await HRMSAPI.shared.applyLeave(leaveTypeId: typeId, startDate: s, endDate: e, dayType: dt, reason: reason)
                submitting = false; done = true
            } catch {
                submitting = false
                self.error = (error as NSError).localizedDescription
            }
        }
    }
}
