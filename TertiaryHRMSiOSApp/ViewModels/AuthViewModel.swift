import Foundation
import SwiftUI

/// View As (web view modes, 20–22 Nov 2026). Approvers (ADMIN / HR / MANAGER) can preview the
/// Staff, Intern and Accountant screens; Trainer Admins can switch to the Trainer Admin view.
/// "mine" is the person's own view (Admin for approvers). Only what is SHOWN changes: forms,
/// approvals and every API call still act as the signed-in person, and the server enforces RBAC.
/// Saved per device; a choice the person can no longer make falls back to "mine".
enum ViewAs: String, CaseIterable, Identifiable {
    case mine, staff, intern, accountant
    case trainerAdmin = "trainer"
    var id: String { rawValue }
    var title: String { title(isApprover: false) }
    func title(isApprover: Bool) -> String {
        switch self {
        case .mine: return isApprover ? "Admin" : "My view"
        case .staff: return "Staff"
        case .intern: return "Intern"
        case .accountant: return "Accountant"
        case .trainerAdmin: return "Trainer Admin"
        }
    }
    var icon: String {
        switch self {
        case .mine: return "person.badge.key.fill"
        case .staff: return "person.fill"
        case .intern: return "graduationcap.fill"
        case .accountant: return "dollarsign.circle.fill"
        case .trainerAdmin: return "person.text.rectangle.fill"
        }
    }
    static let storageKey = "hrms_view_as"
}

/// The single source of truth the views observe. Owns the auth flow state machine,
/// drives `AuthService`, and persists the optionally-remembered login email.
@MainActor
final class AuthViewModel: ObservableObject {

    /// Which credential step the login frontend is showing.
    enum Step: Equatable { case email, password, otp }

    /// Top-level routing for `RootView`.
    enum Phase: Equatable { case loading, signedOut, signedIn }

    @Published var phase: Phase = .loading
    @Published var step: Step = .email

    @Published var email = ""
    @Published var password = ""
    @Published var otp = ""

    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    @Published private(set) var user: SessionUser?

    /// From `/api/mobile/summary.canManageTrainers` (TRAINER_ADMIN) — shows the Trainers entry.
    /// UI gate only; the trainer endpoints enforce it server-side (403).
    @Published var canManageTrainers = false

    /// More → View As (Trainer Admins only). Persisted in UserDefaults `hrms_view_as`.
    @Published var viewAs: ViewAs = ViewAs(rawValue: UserDefaults.standard.string(forKey: ViewAs.storageKey) ?? "") ?? .mine {
        didSet { UserDefaults.standard.set(viewAs.rawValue, forKey: ViewAs.storageKey) }
    }

    /// The Trainer Admin view is on: chosen in View As and the user still holds TRAINER_ADMIN.
    var isTrainerView: Bool { canManageTrainers && viewAs == .trainerAdmin }

    /// Previewing other roles (Staff / Intern / Accountant) is Alfred's only (22 Nov 2026; web
    /// src/lib/view-as-policy.ts). Trainer Admins (Deepa, Tan Soik Ching) switch My view / Trainer Admin.
    static let viewAsEmails = ["angch@tertiaryinfotech.com"]
    var canViewAs: Bool { Self.viewAsEmails.contains((user?.email ?? "").trimmingCharacters(in: .whitespaces).lowercased()) }

    /// The views this person may pick: their own, the role previews for approvers, Trainer Admin
    /// for TRAINER_ADMIN holders.
    var availableViews: [ViewAs] {
        var v: [ViewAs] = [.mine]
        if canViewAs, isApprover { v += [.staff, .intern, .accountant] }
        if canManageTrainers { v.append(.trainerAdmin) }
        return v
    }

    /// An approver previewing another role's screens (Staff / Intern / Accountant).
    var isRolePreview: Bool { canViewAs && isApprover && [.staff, .intern, .accountant].contains(viewAs) }

    /// What the screens show (View As aware). Business rules and forms keep the real roles
    /// (`isIntern`, `mustClockIn`, `isApprover`).
    var showsAdmin: Bool { isApprover && !isRolePreview && !isTrainerView }
    var showsIntern: Bool { isRolePreview ? viewAs == .intern : isIntern }
    var showsMustClockIn: Bool { isRolePreview ? (viewAs == .intern || viewAs == .accountant) : mustClockIn }
    /// Accountant screens: no leave, MC or time off (no Leave tab, no balances, no Apply).
    var showsAccountant: Bool { isRolePreview ? viewAs == .accountant : LeaveRules.isAccountant(roles: user?.roles) }

    /// Apply the server's `canManageTrainers`; a view that is no longer allowed falls back to "mine".
    func applyTrainerCapability(_ can: Bool) {
        canManageTrainers = can
        if !availableViews.contains(viewAs) { viewAs = .mine }
    }

    /// Interns (roles exactly ["INTERN"]) have no paid MC — sick leave goes in as No Pay Leave.
    var isIntern: Bool { LeaveRules.isIntern(roles: user?.roles) }

    /// Interns and accountants (without an approver role) clock in and out and keep a Timesheet.
    var mustClockIn: Bool { LeaveRules.mustClockIn(roles: user?.roles) }

    /// Refresh the summary-driven capabilities (cheap; called when the More menu appears).
    func refreshCapabilities() async {
        guard phase == .signedIn, let s = try? await HRMSAPI.shared.summary() else { return }
        applyTrainerCapability(s.showsTrainers)
    }

    @Published var rememberEmail: Bool = UserDefaults.standard.bool(forKey: Keys.rememberFlag) {
        didSet { UserDefaults.standard.set(rememberEmail, forKey: Keys.rememberFlag) }
    }

    private enum Keys {
        static let rememberFlag = "hrms_remember_email"
        static let rememberedEmail = "hrms_remembered_email"
        /// The company address last signed in with Google on this device (the one-tap hint).
        static let googleCompanyEmail = "hrms_google_company_email"
    }

    init() {
        if rememberEmail, let saved = UserDefaults.standard.string(forKey: Keys.rememberedEmail) {
            email = saved
        }
    }

    // MARK: - Lifecycle

    /// Restore an existing session on launch (employee stays logged in).
    func bootstrap() async {
        // Screenshot/demo seed: only when launched with `-uiPreview` (App Store capture &
        // UI checks). Never triggered in a normal install — no fake data ships to users.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiPreview"), !args.contains("-uiPreviewLogin") {
            if args.contains("-uiPreviewIntern") {
                user = SessionUser(id: "preview-intern", email: "intern@tertiaryinfotech.com",
                                   name: "Jamie Koh", role: "INTERN",
                                   roles: ["INTERN"], employeeId: "I0007")
            } else if args.contains("-uiPreviewStaff") {
                user = SessionUser(id: "preview-staff", email: "staff@tertiaryinfotech.com",
                                   name: "Sarah Lim", role: "STAFF",
                                   roles: ["STAFF"], employeeId: "E0002")
            } else {
                user = SessionUser(id: "preview", email: "angch@tertiaryinfotech.com",
                                   name: "Alfred Ang", role: "ADMIN",
                                   roles: ["ADMIN", "HR", "TRAINER_ADMIN"], employeeId: "E0001")
            }
            canManageTrainers = !args.contains("-uiPreviewIntern") && !args.contains("-uiPreviewStaff")
            // `-uiPreviewViewAs trainer` opens the Trainer Admin view; otherwise always My view.
            if let i = args.firstIndex(of: "-uiPreviewViewAs"), i + 1 < args.count,
               let v = ViewAs(rawValue: args[i + 1]) { viewAs = v } else { viewAs = .mine }
            phase = .signedIn
            return
        }
        if let i = args.firstIndex(of: "-uiPreviewLogin"), i + 1 < args.count {
            // `-uiPreviewLogin intern` shows the first screen for a personal email (code sign-in).
            email = args[i + 1] == "intern" ? "jamie.koh@gmail.com" : "angch@tertiaryinfotech.com"
            switch args[i + 1] {
            case "password": step = .password
            case "otp":
                step = .otp
                infoMessage = "We emailed a 6-digit code to \(email)."
            default: step = .email
            }
            phase = .signedOut
            return
        }
        if let existing = try? await AuthService.shared.currentUser() {
            user = existing
            AppearanceStore.shared.applyAccountDefault(email: existing.email)
            phase = .signedIn
            PushManager.shared.onSignedIn()
            CalendarAutoSync.shared.onSignedIn(isAdmin: isApprover)
        } else {
            phase = .signedOut
        }
    }

    // MARK: - Step transitions

    /// The default sign-in for this email (Alfred, 22 Nov 2026): a company address signs in with
    /// Google, any other address (interns, part-time staff) gets a one-time code. Password is a link.
    /// No email yet also shows Continue with Google (Alfred, 23 Nov 2026: "the Google login button should appear
    /// even without the email keyed in"); Google's account chooser then picks the account.
    var usesGoogleByDefault: Bool {
        googleSignInAvailable
            && (email.trimmingCharacters(in: .whitespaces).isEmpty || GoogleSignInService.isCompanyEmail(email))
    }

    func continueFromEmail() {
        errorMessage = nil; infoMessage = nil
        if email.trimmingCharacters(in: .whitespaces).isEmpty && usesGoogleByDefault {
            Task { await signInWithGoogle() }; return
        }
        guard isValidEmail(email) else { errorMessage = "Enter a valid email address."; return }
        persistRememberedEmail()
        if usesGoogleByDefault { Task { await signInWithGoogle() } } else { Task { await sendOTP() } }
    }

    /// "Use password" from the first screen.
    func usePassword() {
        errorMessage = nil; infoMessage = nil
        guard isValidEmail(email) else { errorMessage = "Enter a valid email address."; return }
        persistRememberedEmail()
        step = .password
    }

    func backToEmail() {
        errorMessage = nil; infoMessage = nil
        password = ""; otp = ""
        step = .email
    }

    func switchToOTP() {
        errorMessage = nil
        Task { await sendOTP() }
    }

    func switchToPassword() {
        errorMessage = nil; infoMessage = nil
        otp = ""
        step = .password
    }

    // MARK: - Actions

    func signInWithPassword() async {
        guard !isWorking else { return }
        errorMessage = nil; infoMessage = nil
        guard !password.isEmpty else { errorMessage = "Enter your password."; return }
        isWorking = true; defer { isWorking = false }
        do {
            let u = try await AuthService.shared.signIn(email: normalizedEmail, password: password)
            finishSignIn(u)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Sign-in failed."
        }
    }

    func sendOTP() async {
        guard !isWorking else { return }
        errorMessage = nil; infoMessage = nil
        guard isValidEmail(email) else { errorMessage = "Enter a valid email address."; return }
        isWorking = true; defer { isWorking = false }
        do {
            try await AuthService.shared.requestOTP(email: normalizedEmail)
            persistRememberedEmail()
            step = .otp
            infoMessage = "We emailed a 6-digit code to \(normalizedEmail)."
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not send the code."
        }
    }

    func verifyOTP() async {
        guard !isWorking else { return }
        errorMessage = nil
        guard otp.count >= 4 else { errorMessage = "Enter the code from your email."; return }
        isWorking = true; defer { isWorking = false }
        do {
            let u = try await AuthService.shared.verifyOTP(email: normalizedEmail, otp: otp)
            finishSignIn(u)
        } catch {
            errorMessage = "That code is incorrect or expired. Request a new one."
        }
    }

    /// Prefill for Google's account chooser: the typed company email, else the one last used with
    /// Google here. Google always shows the chooser (`prompt=select_account`).
    private var googleHint: String? {
        let typed = email.trimmingCharacters(in: .whitespaces).lowercased()
        if GoogleSignInService.isCompanyEmail(typed) { return typed }
        return UserDefaults.standard.string(forKey: Keys.googleCompanyEmail)
    }

    /// Sign in with Google (native consent sheet → backend-verified NextAuth session).
    func signInWithGoogle() async {
        guard !isWorking else { return }
        errorMessage = nil; infoMessage = nil
        isWorking = true; defer { isWorking = false }
        do {
            let u = try await GoogleSignInService.shared.signIn(hint: googleHint)
            if let e = u.email, GoogleSignInService.isCompanyEmail(e) {
                UserDefaults.standard.set(e.lowercased(), forKey: Keys.googleCompanyEmail)
            }
            // Carry the Google account forward so "remember my email" and a later
            // password/OTP sign-in both land on the right address.
            if let signedInEmail = u.email, !signedInEmail.isEmpty { email = signedInEmail }
            persistRememberedEmail()
            finishSignIn(u)
        } catch GoogleSignInService.GoogleAuthError.cancelled {
            // Someone simply backed out of the consent sheet — no error banner.
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Google sign-in failed."
        }
    }

    func signOut() async {
        await PushManager.shared.onSignedOut()   // while the session cookie is still valid
        CalendarAutoSync.shared.onSignedOut()
        await AuthService.shared.signOut()
        user = nil
        canManageTrainers = false
        viewAs = .mine
        password = ""; otp = ""
        step = .email
        phase = .signedOut
    }

    // MARK: - Helpers

    /// Whether this build ships a Google iOS client id (hides the button otherwise).
    var googleSignInAvailable: Bool { GoogleSignInService.isConfigured }

    private func finishSignIn(_ u: SessionUser) {
        user = u
        AppearanceStore.shared.applyAccountDefault(email: u.email)
        password = ""; otp = ""
        infoMessage = nil; errorMessage = nil
        phase = .signedIn
        PushManager.shared.onSignedIn()
        CalendarAutoSync.shared.onSignedIn(isAdmin: isApprover)
    }

    /// Approver roles (mirrors the web's `hasAdminAccess`).
    var isApprover: Bool { ["ADMIN", "HR", "MANAGER"].contains(user?.primaryRole.uppercased() ?? "") }

    private var normalizedEmail: String {
        email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func persistRememberedEmail() {
        if rememberEmail {
            UserDefaults.standard.set(normalizedEmail, forKey: Keys.rememberedEmail)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.rememberedEmail)
        }
    }

    private func isValidEmail(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.contains("@") && t.contains(".") && t.count >= 5
    }
}
