import SwiftUI
import PhotosUI

/// Apply-for-leave form. Posts to the existing /api/leave endpoint; the server
/// computes working days, proration, and balance deductions. For medical leave
/// the MC photo is uploaded first (/api/upload) and attached to the request,
/// which files it in the employee's "Medical Certificates" Drive folder.
struct ApplyLeaveView: View {
    let types: [LeaveType]
    @Environment(\.dismiss) private var dismiss

    @State private var typeId = ""
    @State private var start = Date()
    @State private var end = Date()
    @State private var dayType = "FULL_DAY"
    @State private var reason = ""
    @State private var mcImage: UIImage?
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var submitting = false
    @State private var error: String?
    @State private var done = false
    @State private var holidayKeys: Set<String> = []
    @State private var loadedYears: Set<Int> = []
    @FocusState private var reasonFocused: Bool

    private var workingDays: WorkingDays.Result {
        WorkingDays.compute(start: start, end: end, holidayKeys: holidayKeys)
    }

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

                        if isMedical { mcPhotoSection }

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

                        workingDaysPreview

                        field("Reason (optional)") {
                            TextField("", text: $reason, prompt: Text("e.g. Family matters").foregroundColor(.white.opacity(0.5)), axis: .vertical)
                                .lineLimit(2...4).foregroundStyle(.white)
                                .focused($reasonFocused)
                                .tint(Theme.sky)
                        }

                        PremierButton(title: "Submit request", systemImage: "paperplane.fill",
                                      loading: submitting, enabled: !typeId.isEmpty,
                                      action: submit)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Apply for leave")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.tint(Theme.sky) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { reasonFocused = false }.tint(Theme.sky).fontWeight(.semibold)
                }
            }
            .alert("Request submitted", isPresented: $done) {
                Button("Done") { dismiss() }
            } message: { Text("Your leave request was submitted for approval.") }
            .onAppear { defaultType(); loadHolidays() }
            .onChange(of: start) { _ in
                if end < start { end = start }
                loadHolidays()
            }
            .onChange(of: end) { _ in loadHolidays() }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { mcImage = $0 }
                    .ignoresSafeArea()
            }
            .onChange(of: photoItem) { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        mcImage = img
                    }
                    photoItem = nil
                }
            }
        }
    }

    /// Medical-certificate photo: camera or library, attached to the request.
    private var mcPhotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Medical certificate").font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 10) {
                if let mcImage {
                    Image(uiImage: mcImage)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 240)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    HStack(spacing: 10) {
                        mcButton("Retake", "camera.fill", prominent: true, disabled: !CameraPicker.isAvailable) { showCamera = true }
                        Button(role: .destructive) { self.mcImage = nil } label: {
                            Label("Remove", systemImage: "trash")
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(.white.opacity(0.1)).foregroundStyle(.red.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                } else {
                    mcButton("Take photo of MC", "camera.fill", prominent: true, disabled: !CameraPicker.isAvailable) { showCamera = true }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(.white.opacity(0.1)).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Text("Your MC photo is filed to your Medical Certificates folder and attached to this request.")
                        .font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(12)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func mcButton(_ title: String, _ icon: String, prominent: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(prominent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.white.opacity(0.1)))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(disabled ? 0.45 : 1)
        }
        .disabled(disabled)
    }

    /// Live working-days count (weekends + SG public holidays excluded). Purely
    /// informational — the server computes the real deduction on submit.
    private var workingDaysPreview: some View {
        let r = workingDays
        return VStack(alignment: .leading, spacing: 8) {
            Text("Number of working days").font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(r.workingDays)").font(.title.weight(.bold)).foregroundStyle(.white)
                        .monospacedDigit()
                    Text(r.workingDays == 1 ? "working day" : "working days")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: "calendar.badge.checkmark").foregroundStyle(Theme.sky)
                }
                if r.allNonWorking {
                    Text("This range falls entirely on weekends / public holidays.")
                        .font(.caption).foregroundStyle(.yellow)
                } else if r.calendarDays != r.workingDays {
                    Text(breakdown(r)).font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Text("Weekends and Singapore public holidays are automatically excluded.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func breakdown(_ r: WorkingDays.Result) -> String {
        var parts: [String] = []
        if r.weekendsSkipped > 0 { parts.append("\(r.weekendsSkipped) weekend\(r.weekendsSkipped == 1 ? "" : "s") skipped") }
        if r.holidaysSkipped > 0 { parts.append("\(r.holidaysSkipped) public holiday\(r.holidaysSkipped == 1 ? "" : "s") skipped") }
        let detail = parts.isEmpty ? "" : " (\(parts.joined(separator: ", ")))"
        return "\(r.calendarDays) calendar day\(r.calendarDays == 1 ? "" : "s") → \(r.workingDays) working day\(r.workingDays == 1 ? "" : "s")\(detail)"
    }

    /// Fetch the SG public-holiday keys for every year the range spans (once each).
    private func loadHolidays() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let years = Set([cal.component(.year, from: start), cal.component(.year, from: end)])
        let missing = years.subtracting(loadedYears)
        guard !missing.isEmpty else { return }
        Task {
            var keys = holidayKeys
            for y in missing {
                if let hs = try? await HRMSAPI.shared.publicHolidays(year: y) {
                    keys.formUnion(hs.map(\.date))
                    loadedYears.insert(y)
                }
            }
            holidayKeys = keys
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
        reasonFocused = false
        error = nil; submitting = true
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let s = df.string(from: start), e = df.string(from: end)
        let dt = isSingleDay ? dayType : "FULL_DAY"
        let attachment = isMedical ? mcImage : nil
        Task {
            do {
                var docUrl: String?, docName: String?
                if let attachment, let data = attachment.receiptJPEGData() {
                    let uploaded = try await HRMSAPI.shared.uploadDocument(imageData: data, fileName: "medical-certificate.jpg")
                    docUrl = uploaded.url; docName = uploaded.fileName
                }
                try await HRMSAPI.shared.applyLeave(leaveTypeId: typeId, startDate: s, endDate: e,
                                                    dayType: dt, reason: reason,
                                                    documentUrl: docUrl, documentFileName: docName)
                submitting = false; done = true
            } catch {
                submitting = false
                self.error = (error as NSError).localizedDescription
            }
        }
    }
}
