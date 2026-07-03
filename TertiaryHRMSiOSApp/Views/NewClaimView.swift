import SwiftUI
import PhotosUI

/// Submit an expense or medical claim with a receipt photo taken on the spot.
/// The photo goes to the backend, which files it in the employee's own Google
/// Drive folder ("Expense Claims" / "Medical Claims") and raises the claim
/// for approval — same flow as the web app.
struct NewClaimView: View {
    /// Categories from /api/mobile/expenses; loaded here when not supplied.
    var categories: [ExpenseCategory]? = nil
    var onSubmitted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    enum ClaimType: String, CaseIterable, Identifiable {
        case expense = "Expense"
        case medical = "Medical"
        var id: String { rawValue }
    }

    @State private var claimType: ClaimType = .expense
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var descriptionText = ""
    @State private var amountText = ""
    @State private var expenseDate = Date()
    @State private var categoryId: String?
    @State private var loadedCategories: [ExpenseCategory] = []
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var submitted = false

    private var expenseCategories: [ExpenseCategory] {
        (categories ?? loadedCategories).filter { $0.code.uppercased() != "MEDICAL" }
    }

    private var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSubmit: Bool {
        image != nil && !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty
            && (amount ?? 0) > 0
            && (claimType == .medical || categoryId != nil)
    }

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    typePicker
                    photoSection
                    detailsSection
                    if let errorMessage { StatusBanner(kind: .error, text: errorMessage) }
                    PremierButton(title: submitted ? "Submitted ✓" : "Submit claim",
                                  systemImage: submitted ? nil : "paperplane.fill",
                                  loading: submitting, enabled: canSubmit && !submitted) {
                        Task { await submit() }
                    }
                    Text("Your receipt photo is filed to your personal Google Drive folder under \(claimType == .medical ? "Medical Claims" : "Expense Claims") and sent for approval.")
                        .font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
                .padding(20)
            }
        }
        .navigationTitle("New claim")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image = $0 }
                .ignoresSafeArea()
        }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    image = img
                }
                photoItem = nil
            }
        }
        .task {
            if categories == nil, loadedCategories.isEmpty {
                loadedCategories = (try? await HRMSAPI.shared.expenses().categories) ?? []
            }
        }
    }

    // MARK: Sections

    private var typePicker: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Claim type").font(.headline).foregroundStyle(.white.opacity(0.9))
                HStack(spacing: 10) {
                    ForEach(ClaimType.allCases) { t in
                        Button {
                            claimType = t
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: t == .expense ? "creditcard.fill" : "cross.case.fill")
                                Text(t.rawValue).fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(claimType == t ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.white.opacity(0.1)))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private var photoSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Receipt photo").font(.headline).foregroundStyle(.white.opacity(0.9))
                if let image {
                    Image(uiImage: image)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    HStack(spacing: 10) {
                        photoButton("Retake", "camera.fill", disabled: !CameraPicker.isAvailable) { showCamera = true }
                        Button(role: .destructive) { self.image = nil } label: {
                            Label("Remove", systemImage: "trash")
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(.white.opacity(0.1)).foregroundStyle(.red.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                } else {
                    photoButton("Take photo", "camera.fill", disabled: !CameraPicker.isAvailable) { showCamera = true }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(.white.opacity(0.1)).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if !CameraPicker.isAvailable {
                        Text("Camera not available on this device — choose from the photo library.")
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
    }

    private func photoButton(_ title: String, _ icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Theme.accent).foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(disabled ? 0.45 : 1)
        }
        .disabled(disabled)
    }

    private var detailsSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Details").font(.headline).foregroundStyle(.white.opacity(0.9))

                if claimType == .expense {
                    Menu {
                        ForEach(expenseCategories) { c in
                            Button(c.name) { categoryId = c.id }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "tag.fill").foregroundStyle(.white.opacity(0.7)).frame(width: 22)
                            Text(expenseCategories.first(where: { $0.id == categoryId })?.name ?? "Select category")
                                .foregroundStyle(categoryId == nil ? .white.opacity(0.55) : .white)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 16).frame(height: Theme.controlHeight)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                            .stroke(Theme.fieldBorder, lineWidth: 1))
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "cross.case.fill").foregroundStyle(.pink)
                        Text("Filed under Medical Claim").foregroundStyle(.white.opacity(0.85)).font(.subheadline)
                    }
                }

                PremierField(title: "Description (e.g. Clinic visit, taxi receipt)",
                             systemImage: "text.alignleft", text: $descriptionText)

                PremierField(title: "Amount (SGD)", systemImage: "dollarsign.circle",
                             text: $amountText, keyboard: .decimalPad, submitLabel: .done)

                DatePicker(selection: $expenseDate, in: ...Date(), displayedComponents: .date) {
                    Label("Receipt date", systemImage: "calendar")
                        .foregroundStyle(.white.opacity(0.85))
                }
                .datePickerStyle(.compact)
                .tint(Theme.sky)
                .colorScheme(.dark)
                .frame(height: 44)
            }
        }
    }

    // MARK: Submit

    private func submit() async {
        guard let image, let amount else { return }
        errorMessage = nil
        guard let data = image.receiptJPEGData() else {
            errorMessage = "Could not read the photo. Try another one."
            return
        }
        submitting = true
        defer { submitting = false }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateString = df.string(from: expenseDate)

        do {
            try await HRMSAPI.shared.submitClaim(
                claimType: claimType == .medical ? "MEDICAL" : "EXPENSE",
                categoryId: claimType == .medical ? nil : categoryId,
                description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount,
                expenseDate: dateString,
                imageData: data,
                fileName: "receipt.jpg")
            submitted = true
            onSubmitted?()
            try? await Task.sleep(nanoseconds: 700_000_000)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? (error as NSError).localizedDescription
        }
    }
}
