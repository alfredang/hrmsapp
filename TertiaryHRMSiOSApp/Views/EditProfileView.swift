import SwiftUI

/// Self-service profile edit. Sends only the personal fields the employee is
/// allowed to change (employment/role stay admin-only) to
/// PATCH /api/employees/{id}. On success the parent reloads the profile.
struct EditProfileView: View {
    let employee: EmployeeProfile
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var nric: String
    @State private var nationality: String
    @State private var address: String
    @State private var gender: String        // MALE / FEMALE / OTHER
    @State private var education: String      // "" or DIPLOMA/DEGREE/MASTER/PHD
    @State private var dob: Date
    @State private var hasDOB: Bool
    @State private var saving = false
    @State private var error: String?

    init(employee: EmployeeProfile, onSaved: @escaping () -> Void) {
        self.employee = employee
        self.onSaved = onSaved
        _name = State(initialValue: employee.name)
        _email = State(initialValue: employee.email)
        _phone = State(initialValue: employee.phone ?? "")
        _nric = State(initialValue: "")
        _nationality = State(initialValue: employee.nationality)
        _address = State(initialValue: employee.address ?? "")
        _gender = State(initialValue: employee.gender.uppercased())
        _education = State(initialValue: "")
        let parsed = Fmt.dateObj(employee.dateOfBirth)
        _dob = State(initialValue: parsed ?? Date(timeIntervalSince1970: 631152000)) // 1990-01-01 fallback
        _hasDOB = State(initialValue: parsed != nil)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@")
            && !nationality.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private let genders = ["MALE", "FEMALE", "OTHER"]
    private let educations = ["DIPLOMA", "DEGREE", "MASTER", "PHD"]

    var body: some View {
        NavigationStack {
            GradientScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error { StatusBanner(kind: .error, text: error) }
                        Card {
                            VStack(spacing: 14) {
                                PremierField(title: "Full name", systemImage: "person.fill", text: $name)
                                PremierField(title: "Email", systemImage: "envelope.fill", text: $email,
                                             keyboard: .emailAddress, contentType: .emailAddress)
                                PremierField(title: "Phone", systemImage: "phone.fill", text: $phone, keyboard: .phonePad)
                                PremierField(title: "NRIC / FIN (optional)", systemImage: "creditcard.fill", text: $nric)
                                PremierField(title: "Nationality", systemImage: "globe", text: $nationality)
                                PremierField(title: "Address (optional)", systemImage: "house.fill", text: $address)
                                menuField("Gender", systemImage: "person.crop.circle",
                                          value: gender.capitalized, options: genders.map { ($0, $0.capitalized) }) { gender = $0 }
                                menuField("Education", systemImage: "graduationcap.fill",
                                          value: education.isEmpty ? "Not set" : education.capitalized,
                                          options: educations.map { ($0, $0.capitalized) }) { education = $0 }
                                dobField
                            }
                        }
                        PremierButton(title: "Save changes", systemImage: "checkmark",
                                      loading: saving, enabled: canSave, action: save)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.tint(Theme.sky) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("Done") { hideKeyboard() }.tint(Theme.sky).fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var dobField: some View {
        HStack {
            Label("Date of birth", systemImage: "calendar").foregroundStyle(.white.opacity(0.85))
            Spacer()
            DatePicker("", selection: $dob, in: ...Date(), displayedComponents: .date)
                .labelsHidden().colorScheme(.dark).tint(Theme.sky)
                .onChange(of: dob) { _ in hasDOB = true }
        }
        .padding(.horizontal, 16).frame(height: Theme.controlHeight)
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).stroke(Theme.fieldBorder, lineWidth: 1))
    }

    private func menuField(_ label: String, systemImage: String, value: String,
                           options: [(String, String)], onPick: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(options, id: \.0) { opt in Button(opt.1) { onPick(opt.0) } }
        } label: {
            HStack {
                Image(systemName: systemImage).foregroundStyle(.white.opacity(0.7)).frame(width: 22)
                Text(label).foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(value).foregroundStyle(.white)
                Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16).frame(height: Theme.controlHeight)
            .background(Theme.field)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).stroke(Theme.fieldBorder, lineWidth: 1))
        }
    }

    private func save() {
        error = nil; saving = true
        var info: [String: Any] = [
            "fullName": name.trimmingCharacters(in: .whitespaces),
            "email": email.trimmingCharacters(in: .whitespaces),
            "nationality": nationality.trimmingCharacters(in: .whitespaces),
            "gender": gender,
        ]
        let p = phone.trimmingCharacters(in: .whitespaces); if !p.isEmpty { info["phone"] = p }
        let n = nric.trimmingCharacters(in: .whitespaces); if !n.isEmpty { info["nric"] = n }
        let a = address.trimmingCharacters(in: .whitespaces); if !a.isEmpty { info["address"] = a }
        if !education.isEmpty { info["educationLevel"] = education }
        if hasDOB {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "UTC")
            info["dateOfBirth"] = f.string(from: dob)
        }
        Task {
            do {
                try await HRMSAPI.shared.updateProfile(employeeId: employee.id, personalInfo: info)
                saving = false
                onSaved()
                dismiss()
            } catch {
                saving = false
                self.error = (error as? LocalizedError)?.errorDescription ?? (error as NSError).localizedDescription
            }
        }
    }
}

/// Change-password sheet. PATCH /api/profile/password {currentPassword, newPassword}.
struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var newPass = ""
    @State private var confirm = ""
    @State private var saving = false
    @State private var error: String?
    @State private var done = false

    private var mismatch: Bool { !confirm.isEmpty && newPass != confirm }
    private var canSave: Bool {
        !current.isEmpty && newPass.count >= 6 && newPass == confirm
    }

    var body: some View {
        NavigationStack {
            GradientScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error { StatusBanner(kind: .error, text: error) }
                        if mismatch { StatusBanner(kind: .error, text: "New passwords don't match.") }
                        Card {
                            VStack(spacing: 14) {
                                PremierField(title: "Current password", systemImage: "lock.fill",
                                             text: $current, isSecure: true, contentType: .password)
                                PremierField(title: "New password (min 6 characters)", systemImage: "lock.rotation",
                                             text: $newPass, isSecure: true, contentType: .newPassword)
                                PremierField(title: "Confirm new password", systemImage: "lock.rotation",
                                             text: $confirm, isSecure: true, contentType: .newPassword)
                            }
                        }
                        PremierButton(title: "Update password", systemImage: "checkmark.shield.fill",
                                      loading: saving, enabled: canSave, action: save)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Change password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.tint(Theme.sky) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("Done") { hideKeyboard() }.tint(Theme.sky).fontWeight(.semibold)
                }
            }
            .alert("Password updated", isPresented: $done) {
                Button("Done") { dismiss() }
            } message: { Text("Your password has been changed.") }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        error = nil; saving = true
        Task {
            do {
                try await HRMSAPI.shared.changePassword(current: current, new: newPass)
                saving = false; done = true
            } catch {
                saving = false
                self.error = (error as? LocalizedError)?.errorDescription ?? (error as NSError).localizedDescription
            }
        }
    }
}
