import SwiftUI
import UIKit

// Neat, structured building blocks (Alfred, 10 Nov 2026): collapsible sections, one-line
// record tables whose long text opens in a sheet, and contact actions. Shared by the
// admin lists (Approvals, Time Off, Leave & MC), the Timesheet and the Trainer directory.

// MARK: - Collapsible section

/// A titled section that collapses to its header. The header shows a count badge.
struct CollapsibleSection<Content: View>: View {
    let title: String
    var icon: String? = nil
    var count: Int? = nil
    /// Highlight the count (e.g. items waiting for approval).
    var countIsAttention = false
    @State var expanded: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    if let icon { Image(systemName: icon).foregroundStyle(Theme.sky) }
                    Text(title).font(.headline).foregroundStyle(Theme.ink)
                    if let count {
                        Text("\(count)")
                            .font(.caption.weight(.bold)).monospacedDigit()
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .foregroundStyle(countIsAttention && count > 0 ? Theme.warning : Theme.sky)
                            .background((countIsAttention && count > 0 ? Theme.warning : Theme.sky).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.mist)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue("\(count.map { "\($0), " } ?? "")\(expanded ? "expanded" : "collapsed")")
            .accessibilityAddTraits([.isHeader, .isButton])

            if expanded { content }
        }
    }
}

// MARK: - One-line table

/// One column of a `OneLineTable` (the name column is separate and frozen).
struct OneLineColumn: Identifiable {
    let id: String
    let width: CGFloat
    var alignment: Alignment = .leading
    var title: String { id }
}

/// A compact table with ONE line per record: the name column stays put on the left and
/// the remaining columns scroll sideways together. Long text is truncated — tapping a
/// row calls `onTap`, which opens the full record in a sheet.
struct OneLineTable<Row: Identifiable, Cell: View>: View {
    let rows: [Row]
    var nameTitle = "Name"
    var nameWidth: CGFloat = 118
    let columns: [OneLineColumn]
    let name: (Row) -> String
    @ViewBuilder let cell: (Row, OneLineColumn) -> Cell
    let onTap: (Row) -> Void

    private var rowHeight: CGFloat { 44 }
    private var headerHeight: CGFloat { 30 }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Frozen name column.
            VStack(spacing: 0) {
                header(nameTitle).padding(.leading, 12)
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                    Button { onTap(r) } label: {
                        Text(name(r))
                            .font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink)
                            .lineLimit(1).truncationMode(.tail)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .padding(.leading, 12).padding(.trailing, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(height: rowHeight)
                    .background(stripe(i))
                }
            }
            .frame(width: nameWidth)

            Rectangle().fill(Theme.cardBorder).frame(width: 1)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(columns) { c in
                            header(c.title).frame(width: c.width, alignment: c.alignment).padding(.horizontal, 6)
                        }
                    }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                        Button { onTap(r) } label: {
                            HStack(spacing: 0) {
                                ForEach(columns) { c in
                                    cell(r, c)
                                        .lineLimit(1).truncationMode(.tail)
                                        .frame(width: c.width, alignment: c.alignment)
                                        .padding(.horizontal, 6)
                                }
                            }
                            .frame(height: rowHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(stripe(i))
                    }
                }
                .padding(.trailing, 8)
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
        .shadow(color: Theme.navy950.opacity(0.05), radius: 8, y: 3)
    }

    private func header(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.caption2.weight(.bold)).foregroundStyle(Theme.mist)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: headerHeight)
            .background(Theme.surface.opacity(0.001))
    }

    private func stripe(_ i: Int) -> Color {
        i % 2 == 0 ? Color(hex: 0xF5F8FF) : Theme.card
    }
}

/// Plain, secondary or emphasised text for a `OneLineTable` cell.
struct TableText: View {
    let text: String
    var secondary = false
    var bold = false
    var body: some View {
        Text(text)
            .font(bold ? .footnote.weight(.semibold) : .footnote)
            .monospacedDigit()
            .foregroundStyle(secondary ? Theme.mist : Theme.ink)
    }
}

// MARK: - Record detail sheet

/// A label / value pair shown in `RecordSheet`.
struct RecordField: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

/// The popup that opens when a one-line row is tapped: every field, the full reason,
/// and optional approve / reject actions.
struct RecordSheet: View {
    let title: String
    var status: String? = nil
    let fields: [RecordField]
    var longTextTitle = "Reason"
    var longText: String? = nil
    var onApprove: (() async -> Void)? = nil
    var onReject: ((String) async -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var rejectReason = ""
    @State private var askingReject = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                        Spacer()
                        if let status { StatusPill(status: status) }
                    }
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(fields.enumerated()), id: \.element.id) { i, f in
                                if i > 0 { Divider().padding(.leading, 14) }
                                HStack(alignment: .firstTextBaseline) {
                                    Text(f.label).font(.subheadline).foregroundStyle(Theme.mist)
                                    Spacer(minLength: 12)
                                    Text(f.value).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                                        .multilineTextAlignment(.trailing)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                            }
                        }
                    }
                    if let longText, !longText.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(longTextTitle).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.mist)
                            Card {
                                Text(longText).font(.body).foregroundStyle(Theme.ink)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    if onApprove != nil || onReject != nil {
                        HStack(spacing: 12) {
                            if let onReject {
                                Button { askingReject = true } label: {
                                    Label("Reject", systemImage: "xmark.circle.fill").fontWeight(.semibold)
                                        .frame(maxWidth: .infinity).frame(height: 48)
                                }
                                .buttonStyle(.bordered).tint(Theme.danger)
                                .alert("Reject request", isPresented: $askingReject) {
                                    TextField("Reason (optional)", text: $rejectReason)
                                    Button("Reject", role: .destructive) {
                                        let reason = rejectReason
                                        Task { busy = true; await onReject(reason); busy = false; dismiss() }
                                    }
                                    Button("Cancel", role: .cancel) {}
                                }
                            }
                            if let onApprove {
                                Button {
                                    Task { busy = true; await onApprove(); busy = false; dismiss() }
                                } label: {
                                    Label("Approve", systemImage: "checkmark.circle.fill").fontWeight(.semibold)
                                        .frame(maxWidth: .infinity).frame(height: 48)
                                }
                                .buttonStyle(.borderedProminent).tint(Theme.success)
                            }
                        }
                        .disabled(busy)
                    }
                }
                .padding(20)
            }
            .background(Theme.backdrop.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Contact actions

/// Phone / email / WhatsApp links shared by the trainer rows and profile.
enum ContactLinks {
    /// `tel:` with digits (and a leading +) only.
    static func tel(_ phone: String?) -> URL? {
        guard let phone else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }

    /// `https://wa.me/<number>` — Singapore numbers are stored without the country code,
    /// so an 8-digit number gets `65` in front (same rule as the web directory).
    static func whatsApp(_ phone: String?) -> URL? {
        guard let phone else { return nil }
        let digits = phone.filter(\.isNumber)
        guard digits.count >= 8 else { return nil }
        let number = digits.count == 8 ? "65\(digits)" : digits
        return URL(string: "https://wa.me/\(number)")
    }

    static func mail(_ email: String?) -> URL? {
        guard let email = email?.trimmingCharacters(in: .whitespaces), email.contains("@") else { return nil }
        return URL(string: "mailto:\(email)")
    }

    static func copy(_ text: String) { UIPasteboard.general.string = text }
}

/// Menu items for calling, emailing, WhatsApp-ing or copying a contact.
struct ContactMenuItems: View {
    let phone: String?
    let email: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let url = ContactLinks.tel(phone) {
            Button { openURL(url) } label: {
                Label { Text("Call"); Text(phone ?? "") } icon: { Image(systemName: "phone.fill") }
            }
        }
        if let url = ContactLinks.whatsApp(phone) {
            Button { openURL(url) } label: { Label("WhatsApp", systemImage: "message.fill") }
        }
        if let url = ContactLinks.mail(email) {
            Button { openURL(url) } label: {
                Label { Text("Email"); Text(email ?? "") } icon: { Image(systemName: "envelope.fill") }
            }
        }
        if phone != nil || email != nil {
            Divider()
            if let phone { Button { ContactLinks.copy(phone) } label: { Label("Copy phone", systemImage: "doc.on.doc") } }
            if let email { Button { ContactLinks.copy(email) } label: { Label("Copy email", systemImage: "doc.on.doc") } }
        }
    }
}

/// A row of round contact buttons (profile header).
struct ContactButtonsRow: View {
    let phone: String?
    let email: String?
    @Environment(\.openURL) private var openURL
    @State private var copied = false

    var body: some View {
        HStack(spacing: 10) {
            button("Call", "phone.fill", ContactLinks.tel(phone))
            button("WhatsApp", "message.fill", ContactLinks.whatsApp(phone))
            button("Email", "envelope.fill", ContactLinks.mail(email))
            Menu {
                if let phone { Button { ContactLinks.copy(phone); flash() } label: { Label("Copy phone", systemImage: "phone") } }
                if let email { Button { ContactLinks.copy(email); flash() } label: { Label("Copy email", systemImage: "envelope") } }
            } label: {
                pill("Copy", copied ? "checkmark" : "doc.on.doc", enabled: phone != nil || email != nil)
            }
            .disabled(phone == nil && email == nil)
        }
    }

    private func flash() {
        copied = true
        Task { try? await Task.sleep(nanoseconds: 1_200_000_000); copied = false }
    }

    @ViewBuilder
    private func button(_ title: String, _ icon: String, _ url: URL?) -> some View {
        Button { if let url { openURL(url) } } label: { pill(title, icon, enabled: url != nil) }
            .disabled(url == nil)
    }

    private func pill(_ title: String, _ icon: String, enabled: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.body.weight(.semibold))
            Text(title).font(.caption2.weight(.semibold))
        }
        .frame(maxWidth: .infinity).frame(height: 56)
        .foregroundStyle(enabled ? Theme.sky : Theme.mist.opacity(0.5))
        .background(Theme.sky.opacity(enabled ? 0.09 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
