import SwiftUI

/// More → Trainers: a read-only contact list every staff member and intern can open, so
/// anyone can reach a trainer. Search filters on the server (`?q=`) and locally as you type.
/// The full directory (filters, certificates, NRIC) stays in `TrainersView` for Trainer Admins.
struct TrainerContactsView: View {
    @State private var state: LoadState<TrainerContactsResponse> = .idle
    @State private var query = ""

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { data in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        let list = filtered(data.trainers)
                        Text("\(list.count) trainer\(list.count == 1 ? "" : "s")")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.mist)
                        ForEach(list) { t in
                            NavigationLink { TrainerContactDetailView(trainer: t) } label: { row(t) }
                                .buttonStyle(.plain)
                        }
                        if list.isEmpty {
                            EmptyHint(icon: "person.crop.rectangle.stack", text: "No trainers found.")
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
        .navigationTitle("Trainers")
        .searchable(text: $query, prompt: "Search name, course or skill")
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do { state = .loaded(try await HRMSAPI.shared.trainerContacts()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load trainers.") }
    }

    private func filtered(_ list: [TrainerContact]) -> [TrainerContact] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return list }
        return list.filter { t in
            ([t.name, t.email ?? ""] + t.courseTitles + t.skills + t.trainingCerts)
                .joined(separator: " ").lowercased().contains(q)
        }
    }

    private func row(_ t: TrainerContact) -> some View {
        Card {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent).frame(width: 40, height: 40)
                    Text(Self.initials(t.name)).font(.caption.weight(.bold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                    if !t.summaryLine.isEmpty {
                        Text(t.summaryLine).font(.caption).foregroundStyle(Theme.mist).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.ink.opacity(0.4))
            }
        }
    }

    static func initials(_ name: String) -> String {
        let words = name.replacingOccurrences(of: "(DR)", with: "").split(separator: " ").filter { $0.first?.isLetter == true }
        return String(words.prefix(2).compactMap(\.first)).uppercased()
    }
}

/// One trainer's contact card: tap to email, call or WhatsApp.
struct TrainerContactDetailView: View {
    let trainer: TrainerContact
    @Environment(\.openURL) private var openURL

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Theme.accent).frame(width: 76, height: 76)
                            Text(TrainerContactsView.initials(trainer.name))
                                .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        }
                        Text(trainer.name).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        if !trainer.trainingCerts.isEmpty {
                            Text(TrainingCert.shortCodes(trainer.trainingCerts).joined(separator: " · "))
                                .lineLimit(1).truncationMode(.tail)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Theme.gold).foregroundStyle(Theme.ink).clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Card {
                        VStack(spacing: 0) {
                            if let email = trainer.email, let url = trainer.mailURL {
                                contact("envelope.fill", "Email", email) { openURL(url) }
                            }
                            if let phone = trainer.phone, let url = trainer.telURL {
                                Divider()
                                contact("phone.fill", "Call", phone) { openURL(url) }
                            }
                            if let wa = trainer.whatsAppURL {
                                Divider()
                                contact("message.fill", "WhatsApp", trainer.phone ?? "") { openURL(wa) }
                            }
                            if trainer.mailURL == nil && trainer.telURL == nil {
                                Text("No contact details on file.").font(.subheadline).foregroundStyle(Theme.mist)
                                    .padding(.vertical, 12)
                            }
                        }
                    }

                    if !trainer.courseTitles.isEmpty { listCard("Courses", trainer.courseTitles) }
                    if !trainer.skills.isEmpty { listCard("Skills", trainer.skills) }
                    if let last = trainer.lastClassDate, let shown = Fmt.dateObj(last) {
                        Text("Last class: \(shown.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(Theme.mist)
                    }
                }
                .padding(20)
            }
        }
        .brandBar()
    }

    private func contact(_ icon: String, _ label: String, _ value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Theme.sky).frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.caption).foregroundStyle(Theme.mist)
                    Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.sky)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Theme.ink.opacity(0.4))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func listCard(_ title: String, _ items: [String]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption.weight(.bold)).foregroundStyle(Theme.mist)
                ForEach(items, id: \.self) { Text($0).font(.subheadline).foregroundStyle(Theme.ink) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
