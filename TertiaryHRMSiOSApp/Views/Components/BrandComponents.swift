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

/// Inline status banner (error / info) on the dark surface.
struct StatusBanner: View {
    enum Kind { case error, info }
    let kind: Kind
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: kind == .error ? "exclamationmark.triangle.fill" : "envelope.badge.fill")
            Text(text).font(.footnote)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(12)
        .background((kind == .error ? Color.red : Theme.premier).opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke((kind == .error ? Color.red : Theme.sky).opacity(0.5), lineWidth: 1)
        )
    }
}
