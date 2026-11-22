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
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .shadow(color: Theme.navy950.opacity(0.06), radius: 14, y: 6)
                .padding(.horizontal, 22)

                Text("Authorized employees only · Secured by Tertiary Infotech")
                    .font(.caption2)
                    .foregroundStyle(Theme.ink.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Steps

    /// One screen, one tap (Alfred, 22 Nov 2026): a company email signs in with Google, any other
    /// email (interns, part-time staff) is sent a one-time code. Password is a link below.
    private var emailStep: some View {
        VStack(spacing: 16) {
            sectionTitle(auth.email.isEmpty ? "Sign in" : "Welcome back",
                         "Enter your email. Staff sign in with Google, interns and part-time staff with a code.")
            PremierField(title: "Email", systemImage: "envelope.fill",
                         text: $auth.email, keyboard: .emailAddress,
                         contentType: .username, submitLabel: .go,
                         onSubmit: auth.continueFromEmail)
            rememberRow
            if auth.usesGoogleByDefault {
                GoogleSignInButton(loading: auth.isWorking, enabled: !auth.isWorking,
                                   action: { Task { await auth.signInWithGoogle() } })
                    .accessibilityIdentifier("login.google")
                Text("Signs in with your company Google account.")
                    .font(.caption).foregroundStyle(Theme.mist).frame(maxWidth: .infinity)
            } else {
                PremierButton(title: "Email me a sign-in code", systemImage: "envelope.badge.fill",
                              loading: auth.isWorking, enabled: !auth.email.isEmpty,
                              action: { Task { await auth.sendOTP() } })
                    .accessibilityIdentifier("login.sendCode")
            }
            if auth.usesGoogleByDefault {
                // The code sign-in as a full-width button (Alfred, 22 Nov 2026: "make the OTP button
                // more visible, and indicate that interns can sign in using OTP").
                Button(action: { Task { await auth.sendOTP() } }) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.badge.fill")
                        Text("Email me a sign-in code").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.controlHeight)
                    .foregroundStyle(Theme.chipInk)
                    .background(Theme.chipFill.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .stroke(Theme.sky.opacity(0.35), lineWidth: 1))
                }
                .disabled(auth.isWorking)
                .accessibilityIdentifier("login.codeInstead")
            }
            Label("Interns and part-time staff: sign in with a code sent to your email.", systemImage: "graduationcap.fill")
                .font(.caption).foregroundStyle(Theme.mist)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("login.internHint")
            // Password is the last resort (Alfred, 22 Nov 2026): small and grey, at the bottom.
            Button("Sign in with a password", action: auth.usePassword)
                .font(.caption).tint(Theme.mist)
                .accessibilityIdentifier("login.usePassword")
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
            if auth.usesGoogleByDefault { googleOption }

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
            Text("Use your @tertiaryinfotech.com Google account.")
                .font(.caption).foregroundStyle(Theme.mist).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("login.googleHint")
        }
    }

    private var rememberRow: some View {
        Toggle(isOn: $auth.rememberEmail) {
            Text("Remember my email").font(.footnote).foregroundStyle(Theme.ink.opacity(0.85))
        }
        .tint(Theme.azure)
    }

    private func sectionTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.ink.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
