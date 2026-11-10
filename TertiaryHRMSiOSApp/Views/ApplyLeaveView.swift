import SwiftUI
import PhotosUI

/// Apply-for-leave form. Posts to the existing /api/leave endpoint; the server
/// computes working days, proration, and balance deductions. For medical leave
/// the MC photo is uploaded first (/api/upload) and attached to the request,
/// which files it in the employee's "Medical Certificates" Drive folder.
///
/// Leave rules (enforced server-side, mirrored here so the form guides the user):
/// - AL beyond the balance is rejected with `AL_EXCEEDS_BALANCE` → offer "Apply as No Pay
///   Leave instead", resubmitting the same dates with the NPL type.
/// - Interns have no paid MC: picking MC switches the form to No Pay Leave up front, reason
///   prefilled "Sick leave (MC)", certificate kept (mirrors the web form's `internSick`).
/// - No Pay Leave is capped (prorated 21 days/yr): the cap and remaining days are shown.
struct ApplyLeaveView: View {
    let types: [LeaveType]
    var balances: [LeaveBalance] = []
    var isIntern = false
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
    @State private var submitError: LeaveSubmitError?
    @State private var done = false
    @State private var submittedAsNoPay = false
    /// Intern picked MC → the request goes in as No Pay Leave with the MC attached.
    @State private var internSick = false
    /// The uploaded MC, reused if the request is resubmitted (no double upload).
    @State private var uploadedDoc: (url: String, name: String)?
    @State private var holidayKeys: Set<String> = []
    @State private var loadedYears: Set<Int> = []
    @FocusState private var reasonFocused: Bool

    private var workingDays: WorkingDays.Result {
        WorkingDays.compute(start: start, end: end, holidayKeys: holidayKeys)
    }

    private var isSingleDay: Bool { Calendar.current.isDate(start, inSameDayAs: end) }
    private var selectedType: LeaveType? { types.first(where: { $0.id == typeId }) }
    private var nplType: LeaveType? { LeaveRules.noPayLeaveType(in: types) }
    private var nplBalance: LeaveBalance? { balances.first(where: \.isNoPayLeave) }
    private var isNoPay: Bool { selectedType?.code.uppercased() == LeaveRules.nplCode }
    /// Show the MC photo: medical leave, or an intern's sick leave going in as NPL.
    private var isMedical: Bool { LeaveRules.isMedical(selectedType) || internSick }

    /// Interns picking MC/SL are switched to No Pay Leave (they have no paid MC).
    private func applyInternSickRule() {
        guard isIntern else { return }
        if LeaveRules.isMedical(selectedType), let npl = nplType {
            internSick = true
            typeId = npl.id
            if reason.trimmingCharacters(in: .whitespaces).isEmpty { reason = LeaveRules.internSickReason }
        } else if typeId != nplType?.id, internSick {
            internSick = false
            if reason == LeaveRules.internSickReason { reason = "" }
        }
    }

    private func typeLabel(_ t: LeaveType) -> String {
        if isIntern && LeaveRules.isMedical(t) { return "\(t.name) (as No Pay Leave)" }
        if t.code.uppercased() == LeaveRules.nplCode, let b = nplBalance {
            return "\(t.name) (\(Fmt.num(b.available)) of \(Fmt.num(b.proRated ?? b.entitlement)) left)"
        }
        return t.name
    }

    /// The server only honours half days on single-day Annual Leave; anything else
    /// is recorded as a full day, so don't offer it.
    private var allowsHalfDay: Bool {
        isSingleDay && types.first(where: { $0.id == typeId })?.code == "AL"
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
                        if let submitError { errorSection(submitError) }

                        field("Leave type") {
                            Picker("", selection: $typeId) {
                                Text("Select…").tag("")
                                ForEach(types) { t in Text(typeLabel(t)).tag(t.id) }
                            }
                            .pickerStyle(.menu).tint(Theme.premier)
                        }

                        if internSick {
                            StatusBanner(kind: .notice, text: "Interns do not have paid medical leave. This sick leave will be submitted as No Pay Leave with your medical certificate attached.")
                        }

                        if isMedical { mcPhotoSection }

                        field("From") {
                            DatePicker("", selection: $start, displayedComponents: .date)
                                .labelsHidden()
                        }
                        field("To") {
                            DatePicker("", selection: $end, in: start..., displayedComponents: .date)
                                .labelsHidden()
                        }

                        if allowsHalfDay {
                            field("Duration") {
                                Picker("", selection: $dayType) {
                                    Text("Full day").tag("FULL_DAY")
                                    Text("Morning half").tag("AM_HALF")
                                    Text("Afternoon half").tag("PM_HALF")
                                }.pickerStyle(.segmented)
                            }
                        }

                        workingDaysPreview

                        if isNoPay { nplPanel }

                        field("Reason (optional)") {
                            TextField("", text: $reason, prompt: Text("e.g. Family matters").foregroundColor(Theme.ink.opacity(0.5)), axis: .vertical)
                                .lineLimit(2...4).foregroundStyle(Theme.ink)
                                .focused($reasonFocused)
                                .tint(Theme.sky)
                        }

                        PremierButton(title: internSick ? "Submit as No Pay Leave" : "Submit request",
                                      systemImage: "paperplane.fill",
                                      loading: submitting, enabled: !typeId.isEmpty,
                                      action: { submit() })
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
            } message: {
                Text(submittedAsNoPay ? "Your No Pay Leave request was submitted for approval."
                                      : "Your leave request was submitted for approval.")
            }
            .onAppear { defaultType(); loadHolidays(); applyPreviewSeed() }
            .onChange(of: typeId) { _ in
                applyInternSickRule()
                submitError = nil
            }
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
            Text("Medical certificate").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink.opacity(0.85))
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
                                .background(Theme.ink.opacity(0.1)).foregroundStyle(Theme.danger)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                } else {
                    mcButton("Take photo of MC", "camera.fill", prominent: true, disabled: !CameraPicker.isAvailable) { showCamera = true }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(Theme.ink.opacity(0.1)).foregroundStyle(Theme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Text("Your MC photo is filed to your Medical Certificates folder and attached to this request.")
                        .font(.caption2).foregroundStyle(Theme.ink.opacity(0.6))
                }
            }
            .padding(12)
            .background(Theme.ink.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func mcButton(_ title: String, _ icon: String, prominent: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(prominent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.ink.opacity(0.1)))
                .foregroundStyle(prominent ? Color.white : Theme.ink)
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
            Text("Number of working days").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink.opacity(0.85))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(r.workingDays)").font(.title.weight(.bold)).foregroundStyle(Theme.ink)
                        .monospacedDigit()
                    Text(r.workingDays == 1 ? "working day" : "working days")
                        .font(.subheadline).foregroundStyle(Theme.ink.opacity(0.7))
                    Spacer()
                    Image(systemName: "calendar.badge.checkmark").foregroundStyle(Theme.sky)
                }
                if r.allNonWorking {
                    Text("This range falls entirely on weekends / public holidays.")
                        .font(.caption).foregroundStyle(Theme.warning)
                } else if r.calendarDays != r.workingDays {
                    Text(breakdown(r)).font(.caption).foregroundStyle(Theme.ink.opacity(0.7))
                }
                Text("Weekends and Singapore public holidays are automatically excluded.")
                    .font(.caption2).foregroundStyle(Theme.ink.opacity(0.5))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.ink.opacity(0.08))
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
        let cal = Calendar(identifier: .gregorian) // device time zone, same as the date pickers
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
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink.opacity(0.85))
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Theme.ink.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    /// Submit the form. `asNoPay` resubmits the same dates / day type as No Pay Leave
    /// (the server's suggestion after `AL_EXCEEDS_BALANCE` / `INTERN_MC_NOT_PAID`).
    private func submit(asNoPay: Bool = false) {
        reasonFocused = false
        let previous = submitError
        submitError = nil; submitting = true
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let s = df.string(from: start), e = df.string(from: end)
        let dt = allowsHalfDay ? dayType : "FULL_DAY"
        let sendTypeId = asNoPay ? (nplType?.id ?? typeId) : typeId
        var wasInternMc = false
        if case .internMcNotPaid? = previous { wasInternMc = true }
        let sickAsNoPay = internSick || (asNoPay && wasInternMc)
        let sendReason = sickAsNoPay ? LeaveRules.internSickReason(reason) : reason
        // Keep the certificate for medical / intern sick leave; an AL→NPL retry has none.
        let attachment = (isMedical || sickAsNoPay) ? mcImage : nil
        Task {
            do {
                var docUrl: String?, docName: String?
                if let attachment {
                    if let cached = uploadedDoc {
                        docUrl = cached.url; docName = cached.name
                    } else if let data = attachment.receiptJPEGData() {
                        let uploaded = try await HRMSAPI.shared.uploadDocument(imageData: data, fileName: "medical-certificate.jpg")
                        uploadedDoc = (uploaded.url, uploaded.fileName)
                        docUrl = uploaded.url; docName = uploaded.fileName
                    }
                }
                try await HRMSAPI.shared.applyLeave(leaveTypeId: sendTypeId, startDate: s, endDate: e,
                                                    dayType: dt, reason: sendReason,
                                                    documentUrl: docUrl, documentFileName: docName)
                submittedAsNoPay = asNoPay || internSick || isNoPay
                submitting = false; done = true
            } catch let err as LeaveSubmitError {
                submitting = false
                submitError = err
            } catch {
                submitting = false
                submitError = .other(message: (error as NSError).localizedDescription, status: 0)
            }
        }
    }

    // MARK: Leave-rule feedback

    /// The server's message, plus "Apply as No Pay Leave instead" when it suggests NPL.
    private func errorSection(_ err: LeaveSubmitError) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            StatusBanner(kind: .error, text: err.errorDescription ?? LeaveSubmitError.fallbackMessage)
            if let npl = err.npl {
                Text("Your No Pay Leave this year").font(.caption.weight(.semibold)).foregroundStyle(Theme.mist)
                nplFigures(npl)
            }
            if err.suggestsNoPayLeave, nplType != nil {
                Button { submit(asNoPay: true) } label: {
                    Label("Apply as No Pay Leave instead", systemImage: "arrow.uturn.right.circle.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).frame(height: Theme.controlHeight)
                        .foregroundStyle(Theme.navy950)
                        .background(Theme.gold)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                }
                .disabled(submitting)
                .accessibilityHint("Resubmits the same dates as No Pay Leave")
            }
        }
    }

    /// The No Pay Leave cap panel shown while NPL is selected.
    private var nplPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No Pay Leave").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink.opacity(0.85))
            VStack(alignment: .leading, spacing: 8) {
                if let b = nplBalance {
                    let cap = b.proRated ?? b.entitlement
                    nplFigures(NplStatus(cap: cap, used: max(0, cap - b.available), pending: 0, remaining: b.available),
                               bookedLabel: "Booked")
                    if Double(workingDays.workingDays) > b.available {
                        Text("This request (\(workingDays.workingDays) day\(workingDays.workingDays == 1 ? "" : "s")) is more than your remaining No Pay Leave (\(Fmt.num(b.available))). Please shorten it or speak to HR.")
                            .font(.caption).foregroundStyle(Theme.warning)
                    }
                }
                Text("No Pay Leave is capped at 21 days a year, prorated by the full months you have served.")
                    .font(.caption2).foregroundStyle(Theme.ink.opacity(0.55))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.ink.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func nplFigures(_ npl: NplStatus, bookedLabel: String? = nil) -> some View {
        HStack(spacing: 0) {
            figure("Cap to date", npl.cap, Theme.ink)
            if let bookedLabel {
                figure(bookedLabel, npl.used, Theme.mist)
            } else {
                figure("Taken", npl.used, Theme.mist)
                figure("Pending", npl.pending, Theme.mist)
            }
            figure("Remaining", npl.remaining, npl.remaining > 0 ? .green : .red)
        }
    }

    private func figure(_ label: String, _ v: Double, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(Fmt.num(v)).font(.headline.weight(.bold)).foregroundStyle(tint).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(Theme.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    /// Screenshot/preview capture only (`-uiPreview` + `-uiPreviewLeave <case>`): seed the form.
    private func applyPreviewSeed() {
        let a = ProcessInfo.processInfo.arguments
        guard a.contains("-uiPreview"), let i = a.firstIndex(of: "-uiPreviewLeave"), i + 1 < a.count else { return }
        let cal = Calendar.current
        switch a[i + 1] {
        case "al-excess":
            typeId = types.first(where: { $0.code == "AL" })?.id ?? typeId
            start = cal.date(byAdding: .day, value: 14, to: Date()) ?? Date()
            end = cal.date(byAdding: .day, value: 35, to: Date()) ?? Date()
            reason = "Family trip overseas"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { submit() }
        case "intern-mc":
            typeId = types.first(where: { $0.code == "MC" })?.id ?? typeId
            mcImage = UIImage(systemName: "doc.text.image")?.withTintColor(.white, renderingMode: .alwaysOriginal)
        case "npl":
            typeId = nplType?.id ?? typeId
        default: break
        }
    }
}
