import SwiftUI

/// The Premier Blue brand mark: a rounded badge with people + a check, plus the wordmark.
struct BrandHeader: View {
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 10 : 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.14))
                    .frame(width: compact ? 76 : 92, height: compact ? 76 : 92)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    )
                Image(systemName: "person.2.fill")
                    .font(.system(size: compact ? 34 : 42, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)

            VStack(spacing: 4) {
                Text("Tertiary HRMS")
                    .font(.system(size: compact ? 24 : 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Human Resource Management")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }
}

/// The company lockup (logo + name) shown as the inline nav-bar title on
/// every screen, so no screen has an empty large-title deadspace and the
/// brand is present everywhere.
struct BrandBarTitle: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("CompanyLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            Text("Tertiary Infotech Academy")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
    }
}

extension View {
    /// Give a screen the shared inline brand nav bar (logo + company name).
    /// Collapses the empty large-title area so there is no top deadspace.
    /// `bell: true` adds the notifications bell (with unread badge) on the trailing edge.
    func brandBar(bell: Bool = false) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { BrandBarTitle() }
                if bell {
                    ToolbarItem(placement: .topBarTrailing) { NotificationBell() }
                }
            }
    }
}

/// A large, branded primary button (≥56pt) with a working spinner.
struct PremierButton: View {
    let title: String
    var systemImage: String? = nil
    var loading = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if loading {
                    ProgressView().tint(.white)
                } else {
                    if let systemImage { Image(systemName: systemImage) }
                    Text(title).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Theme.controlHeight)
            .foregroundStyle(.white)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .opacity(enabled && !loading ? 1 : 0.55)
            .shadow(color: Theme.premier.opacity(0.5), radius: 14, y: 8)
        }
        .disabled(!enabled || loading)
    }
}

/// A glassy text field styled for the dark Premier Blue surface.
struct PremierField: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var isSecure = false
    var contentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .next
    var onSubmit: (() -> Void)? = nil

    @State private var revealed = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 22)
            Group {
                if isSecure && !revealed {
                    SecureField("", text: $text, prompt: prompt)
                } else {
                    TextField("", text: $text, prompt: prompt)
                }
            }
            .focused($focused)
            .foregroundStyle(.white)
            .tint(Theme.sky)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(contentType)
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }

            if isSecure {
                Button { revealed.toggle() } label: {
                    Image(systemName: revealed ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: Theme.controlHeight)
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .stroke(focused ? Theme.sky.opacity(0.8) : Theme.fieldBorder, lineWidth: 1)
        )
    }

    private var prompt: Text {
        Text(title).foregroundColor(.white.opacity(0.55))
    }
}

extension View {
    /// Resign whatever text field is first responder — used by the
    /// keyboard-toolbar "Done" buttons on forms whose keyboards (e.g. the
    /// decimal pad) have no return key.
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Inline status banner (error / info / success) on the dark surface.
struct StatusBanner: View {
    enum Kind { case error, info, success }
    let kind: Kind
    let text: String

    private var icon: String {
        switch kind {
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "envelope.badge.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
    private var fill: Color {
        switch kind {
        case .error: return .red
        case .info: return Theme.premier
        case .success: return .green
        }
    }
    private var stroke: Color {
        switch kind {
        case .error: return .red
        case .info: return Theme.sky
        case .success: return .green
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text).font(.footnote)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(fill.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(stroke.opacity(0.5), lineWidth: 1)
        )
    }
}

/// "Continue with Google" — Google's white button treatment (their branding
/// guidelines require the unmodified multi-colour mark on white or their blue),
/// so it deliberately breaks from the Premier Blue fill of `PremierButton`.
struct GoogleSignInButton: View {
    var loading = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if loading {
                    ProgressView().tint(Color(red: 0.26, green: 0.26, blue: 0.26))
                } else {
                    GoogleGlyph().frame(width: 20, height: 20)
                    Text("Continue with Google")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.11))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Theme.controlHeight)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .opacity(enabled && !loading ? 1 : 0.55)
            .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
        }
        .disabled(!enabled || loading)
        .accessibilityLabel("Continue with Google")
    }
}

/// The Google "G" — the official four-colour mark, drawn from Google's own SVG
/// path data (scaled from its 48×48 viewBox) so the logo is reproduced exactly
/// rather than approximated, as their branding guidelines require.
private struct GoogleGlyph: View {
    /// Each stroke of the mark: Google's published path data, one colour each.
    private static let paths: [(String, Color)] = [
        // Blue
        ("M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z",
         Color(red: 0.259, green: 0.522, blue: 0.957)),
        // Green
        ("M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 15.4 46 24 46z",
         Color(red: 0.204, green: 0.659, blue: 0.325)),
        // Yellow
        ("M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 17.09 2 20.45 2 24s.85 6.91 2.34 9.88l7.35-5.7z",
         Color(red: 0.984, green: 0.737, blue: 0.020)),
        // Red
        ("M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z",
         Color(red: 0.918, green: 0.263, blue: 0.208)),
    ]

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / 48   // Google ships the mark on a 48×48 canvas.
            ZStack {
                ForEach(Array(Self.paths.enumerated()), id: \.offset) { _, entry in
                    GoogleMarkShape(command: entry.0)
                        .fill(entry.1)
                        .frame(width: 48, height: 48)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: side, height: side, alignment: .topLeading)
                }
            }
            .frame(width: side, height: side)
        }
    }
}

/// Minimal SVG-path renderer — supports just the M/C/L/H/V/Z (and relative)
/// commands Google's mark actually uses.
private struct GoogleMarkShape: Shape {
    let command: String

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var numbers: [CGFloat] = []
        var op: Character = "M"

        func flush() {
            guard !numbers.isEmpty || op == "Z" || op == "z" else { return }
            var i = 0
            switch op {
            case "M", "m":
                while i + 1 < numbers.count {
                    let p = point(numbers[i], numbers[i + 1], relative: op == "m", from: current)
                    if i == 0 { path.move(to: p); start = p } else { path.addLine(to: p) }
                    current = p
                    i += 2
                }
            case "L", "l":
                while i + 1 < numbers.count {
                    let p = point(numbers[i], numbers[i + 1], relative: op == "l", from: current)
                    path.addLine(to: p); current = p
                    i += 2
                }
            case "H", "h":
                while i < numbers.count {
                    let x = op == "h" ? current.x + numbers[i] : numbers[i]
                    let p = CGPoint(x: x, y: current.y)
                    path.addLine(to: p); current = p
                    i += 1
                }
            case "V", "v":
                while i < numbers.count {
                    let y = op == "v" ? current.y + numbers[i] : numbers[i]
                    let p = CGPoint(x: current.x, y: y)
                    path.addLine(to: p); current = p
                    i += 1
                }
            case "C", "c":
                while i + 5 < numbers.count {
                    let rel = op == "c"
                    let c1 = point(numbers[i], numbers[i + 1], relative: rel, from: current)
                    let c2 = point(numbers[i + 2], numbers[i + 3], relative: rel, from: current)
                    let end = point(numbers[i + 4], numbers[i + 5], relative: rel, from: current)
                    path.addCurve(to: end, control1: c1, control2: c2)
                    current = end
                    i += 6
                }
            case "Z", "z":
                path.closeSubpath(); current = start
            default:
                break
            }
            numbers.removeAll()
        }

        var buffer = ""
        func takeNumber() {
            let trimmed = buffer.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, let value = Double(trimmed) { numbers.append(CGFloat(value)) }
            buffer = ""
        }

        for ch in command {
            if ch.isLetter {
                takeNumber(); flush()
                op = ch
            } else if ch == "," || ch == " " {
                takeNumber()
            } else if ch == "-" && !buffer.isEmpty && buffer.last != "e" {
                takeNumber(); buffer = "-"
            } else {
                buffer.append(ch)
            }
        }
        takeNumber(); flush()
        return path
    }

    private func point(_ x: CGFloat, _ y: CGFloat, relative: Bool, from: CGPoint) -> CGPoint {
        relative ? CGPoint(x: from.x + x, y: from.y + y) : CGPoint(x: x, y: y)
    }
}

/// A labelled hairline divider ("or") between two sign-in options.
struct OrDivider: View {
    var label = "or"

    var body: some View {
        HStack(spacing: 12) {
            line
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            line
        }
        .accessibilityHidden(true)
    }

    private var line: some View {
        Rectangle()
            .fill(.white.opacity(0.18))
            .frame(height: 1)
    }
}
