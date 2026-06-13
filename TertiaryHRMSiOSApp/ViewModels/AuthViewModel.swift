import Foundation
import SwiftUI

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

    @Published var rememberEmail: Bool = UserDefaults.standard.bool(forKey: Keys.rememberFlag) {
        didSet { UserDefaults.standard.set(rememberEmail, forKey: Keys.rememberFlag) }
    }

    private enum Keys {
        static let rememberFlag = "hrms_remember_email"
        static let rememberedEmail = "hrms_remembered_email"
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
        if args.contains("-uiPreview") {
            user = SessionUser(id: "preview", email: "alfred.ang@tertiaryinfotech.com",
                               name: "Alfred Ang", role: "ADMIN",
                               roles: ["ADMIN", "HR"], employeeId: "E0001")
            phase = .signedIn
            return
        }
        if let i = args.firstIndex(of: "-uiPreviewLogin"), i + 1 < args.count {
            email = "alfred.ang@tertiaryinfotech.com"
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
            phase = .signedIn
        } else {
            phase = .signedOut
        }
    }

    // MARK: - Step transitions

    func continueFromEmail() {
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

    func signOut() async {
        await AuthService.shared.signOut()
        user = nil
        password = ""; otp = ""
        step = .email
        phase = .signedOut
    }

    // MARK: - Helpers

    private func finishSignIn(_ u: SessionUser) {
        user = u
        password = ""; otp = ""
        infoMessage = nil; errorMessage = nil
        phase = .signedIn
    }

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
