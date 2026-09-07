import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Google Sign-In for the app, built on Apple's own `ASWebAuthenticationSession` —
/// no third-party SDK, keeping the project on system frameworks only.
///
/// The flow is the standard OAuth 2.0 authorization-code grant with PKCE, which is
/// what Google requires for a native "iOS" OAuth client (such clients are public and
/// have no secret):
///   1. Open Google's consent screen in the system browser with a PKCE challenge.
///   2. Google redirects back to our custom URL scheme with an authorization code.
///   3. Exchange the code (+ verifier) at Google's token endpoint for an `id_token`.
///   4. POST that `id_token` to `/api/auth/google-mobile`, which verifies it with
///      Google and sets the same NextAuth session cookie the web app uses.
///
/// Step 4 is why this is safe to do client-side: the app never holds a secret and
/// never trusts its own view of who the user is — the backend independently verifies
/// the token with Google and checks the audience against its allow-list.
actor GoogleSignInService {
    static let shared = GoogleSignInService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    enum GoogleAuthError: LocalizedError {
        case notConfigured
        case cancelled
        case google(String)
        case server(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Google sign-in isn't configured in this build."
            case .cancelled:
                return nil          // user backed out — not worth an error banner
            case .google(let m): return m
            case .server(let m): return m
            }
        }
    }

    /// The iOS OAuth client id, read from `Info.plist` (`GIDClientID`).
    /// Not a secret: native OAuth clients are public by design, and the backend
    /// still verifies every token against its own allow-list.
    private static var clientID: String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }

    /// Whether this build can offer Google sign-in at all (drives the button's visibility).
    static var isConfigured: Bool { clientID != nil }

    /// Google's iOS convention: the redirect URI is the client id reversed as a scheme.
    private static func redirectURI(for clientID: String) -> String {
        let scheme = clientID.split(separator: ".").reversed().joined(separator: ".")
        return "\(scheme):/oauth2redirect"
    }

    // MARK: - Public API

    /// Run the full Google sign-in and return the HRMS session user.
    func signIn() async throws -> SessionUser {
        guard let clientID = Self.clientID else { throw GoogleAuthError.notConfigured }
        let redirect = Self.redirectURI(for: clientID)

        let verifier = Self.randomCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomCodeVerifier()

        let callback = try await authorize(clientID: clientID, redirect: redirect,
                                           challenge: challenge, state: state)
        let code = try Self.authorizationCode(from: callback, expectedState: state)
        let idToken = try await exchange(code: code, verifier: verifier,
                                         clientID: clientID, redirect: redirect)
        return try await establishSession(idToken: idToken)
    }

    // MARK: - 1. Consent screen

    private func authorize(clientID: String, redirect: String,
                           challenge: String, state: String) async throws -> URL {
        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            // Company workspace accounts first, but personal accounts still resolve
            // against the employee directory server-side.
            .init(name: "hd", value: "tertiaryinfotech.com"),
            .init(name: "prompt", value: "select_account"),
        ]
        guard let url = comps.url else { throw GoogleAuthError.notConfigured }

        let scheme = String(redirect.split(separator: ":").first ?? "")
        return try await WebAuthPresenter.start(url: url, callbackScheme: scheme)
    }

    /// Pull the `code` out of the redirect, rejecting a mismatched `state` (CSRF guard).
    private static func authorizationCode(from url: URL, expectedState: String) throws -> String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        if let error = value("error") {
            if error == "access_denied" { throw GoogleAuthError.cancelled }
            throw GoogleAuthError.google("Google sign-in failed (\(error)).")
        }
        guard value("state") == expectedState else {
            throw GoogleAuthError.google("Google sign-in could not be verified. Please try again.")
        }
        guard let code = value("code"), !code.isEmpty else {
            throw GoogleAuthError.google("Google did not return a sign-in code.")
        }
        return code
    }

    // MARK: - 2. Token exchange

    private func exchange(code: String, verifier: String,
                          clientID: String, redirect: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = Self.formBody([
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirect,
        ])

        let (data, resp) = try await sendRequest(req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard let idToken = json?["id_token"] as? String, !idToken.isEmpty else {
            let detail = json?["error_description"] as? String ?? json?["error"] as? String
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            throw GoogleAuthError.google(detail ?? "Google rejected the sign-in (HTTP \(status)).")
        }
        return idToken
    }

    // MARK: - 3. Trade the Google token for an HRMS session

    private func establishSession(idToken: String) async throws -> SessionUser {
        var req = URLRequest(url: AuthService.baseURL.appendingPathComponent("api/auth/google-mobile"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["idToken": idToken])

        let (data, resp) = try await sendRequest(req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status >= 400 {
            let msg = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["error"] as? String
            switch status {
            case 401: throw GoogleAuthError.server(msg ?? "That Google account isn't allowed to sign in.")
            case 403: throw GoogleAuthError.server(msg ?? "This account is inactive. Please contact HR.")
            default:  throw GoogleAuthError.server(msg ?? "Sign-in failed. Please try again.")
            }
        }

        // The endpoint sets the NextAuth cookie on this shared cookie store, so the
        // canonical session read is the same one every other sign-in path uses.
        guard let user = try await AuthService.shared.currentUser() else {
            throw GoogleAuthError.server("Signed in with Google, but the session did not start. Please try again.")
        }
        return user
    }

    // MARK: - Helpers

    private func sendRequest(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch {
            throw GoogleAuthError.google("Network error. Check your connection and try again.")
        }
    }

    private static func formBody(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let pairs = fields.map { key, value -> String in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }
        return pairs.joined(separator: "&").data(using: .utf8) ?? Data()
    }

    /// PKCE verifier: 32 random bytes, base64url-encoded (RFC 7636 §4.1).
    private static func randomCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    /// PKCE challenge: base64url(SHA256(verifier)).
    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(digest))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - ASWebAuthenticationSession bridge

/// Wraps `ASWebAuthenticationSession` (callback-based, main-actor bound) as an
/// `async` call, and anchors the sheet on the app's active window.
@MainActor
private final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {

    /// Kept alive for the duration of the flow — the system session is not retained for us.
    private static var active: (session: ASWebAuthenticationSession, presenter: WebAuthPresenter)?

    static func start(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let presenter = WebAuthPresenter()
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                active = nil
                if let error {
                    let code = (error as? ASWebAuthenticationSessionError)?.code
                    if code == .canceledLogin {
                        continuation.resume(throwing: GoogleSignInService.GoogleAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: GoogleSignInService.GoogleAuthError.google(
                            "Google sign-in could not be opened. Please try again."))
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: GoogleSignInService.GoogleAuthError.cancelled)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = presenter
            // A fresh browser session each time, so "select account" really does.
            session.prefersEphemeralWebBrowserSession = true
            active = (session, presenter)

            if !session.start() {
                active = nil
                continuation.resume(throwing: GoogleSignInService.GoogleAuthError.google(
                    "Google sign-in could not be started."))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .first { $0.activationState == .foregroundActive }?
            .keyWindow ?? scenes.first?.keyWindow
        return window ?? ASPresentationAnchor()
    }
}
