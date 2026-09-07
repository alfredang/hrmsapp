import SwiftUI

/// The login frontend — the app's primary surface. Mirrors the web login:
/// a progressive email → password / OTP flow, on the Premier Blue backdrop.
/// Authenticates real employees against the Coolify-hosted HRMS backend.
struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 24)
                BrandHeader()

                VStack(spacing: 16) {
                    if let info = auth.infoMessage { StatusBanner(kind: .info, text: info) }
                    if let err = auth.errorMessage { StatusBanner(kind: .error, text: err) }

                    switch auth.step {
                    case .email:    emailStep
                    case .password: passwordStep
                    case .otp:      otpStep
                    }
                }
                .padding(20)
                .background(.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 22)

                Text("Authorized employees only · Secured by Tertiary Infotech")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Steps

    private var emailStep: some View {
        VStack(spacing: 16) {
            sectionTitle("Sign in", "Enter your work email to continue.")
            PremierField(title: "Work email", systemImage: "envelope.fill",
                         text: $auth.email, keyboard: .emailAddress,
                         contentType: .username, submitLabel: .next,
                         onSubmit: auth.continueFromEmail)
            rememberRow
            PremierButton(title: "Continue", systemImage: "arrow.right",
                          enabled: !auth.email.isEmpty, action: auth.continueFromEmail)
            googleOption
        }
    }

    private var passwordStep: some View {
        VStack(spacing: 16) {
            sectionTitle("Welcome back", auth.email)
            PremierField(title: "Password", systemImage: "lock.fill",
                         text: $auth.password, isSecure: true,
                         contentType: .password, submitLabel: .go,
                         onSubmit: { Task { await auth.signInWithPassword() } })
            PremierButton(title: "Sign in", systemImage: "checkmark.circle.fill",
                          loading: auth.isWorking, enabled: !auth.password.isEmpty,
                          action: { Task { await auth.signInWithPassword() } })
            googleOption

            HStack {
                Button("Use a one-time code", action: auth.switchToOTP)
                Spacer()
                Button("Change email", action: auth.backToEmail)
            }
            .font(.footnote)
            .tint(Theme.sky)
        }
    }

    private var otpStep: some View {
        VStack(spacing: 16) {
            sectionTitle("Enter your code", "We sent a 6-digit code to \(auth.email).")
            PremierField(title: "6-digit code", systemImage: "number",
                         text: $auth.otp, keyboard: .numberPad,
                         contentType: .oneTimeCode, submitLabel: .go,
                         onSubmit: { Task { await auth.verifyOTP() } })
            PremierButton(title: "Verify & sign in", systemImage: "checkmark.circle.fill",
                          loading: auth.isWorking, enabled: auth.otp.count >= 4,
                          action: { Task { await auth.verifyOTP() } })

            HStack {
                Button("Resend code", action: { Task { await auth.sendOTP() } })
                Spacer()
                Button("Use password", action: auth.switchToPassword)
            }
            .font(.footnote)
            .tint(Theme.sky)
        }
    }

    // MARK: Bits

    /// Google sign-in, offered alongside password and OTP. Hidden entirely when the
    /// build carries no Google iOS client id, so it can never dead-end the user.
    @ViewBuilder
    private var googleOption: some View {
        if auth.googleSignInAvailable {
            OrDivider()
            GoogleSignInButton(loading: auth.isWorking, enabled: !auth.isWorking,
                               action: { Task { await auth.signInWithGoogle() } })
        }
    }

    private var rememberRow: some View {
        Toggle(isOn: $auth.rememberEmail) {
            Text("Remember my email").font(.footnote).foregroundStyle(.white.opacity(0.85))
        }
        .tint(Theme.azure)
    }

    private func sectionTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
