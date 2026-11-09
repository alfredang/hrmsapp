import SwiftUI

/// Trainer Admins: the read-only trainer directory (`GET /api/mobile/trainers`).
/// Search + accreditation / finance / IBF-fit filters run server-side; tap a trainer
/// for the full profile. Shown from the More menu only when the summary reports
/// `canManageTrainers`; the server enforces TRAINER_ADMIN (403 otherwise).
struct TrainersView: View {
    @State private var filter = TrainerFilter()
    @State private var state: LoadState<TrainersResponse> = .idle
    @State private var lastLoaded: TrainersResponse?

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    filters
                    results
                }
                .padding(20)
            }
            .refreshable { await load() }
        }
        .brandBar()
        .searchable(text: $filter.query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Name, cert, skill or course")
        .autocorrectionDisabled()
        // Debounced server-side search: re-runs whenever any filter changes.
        .task(id: filter) {
            if lastLoaded != nil { try? await Task.sleep(nanoseconds: 300_000_000) }
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    // MARK: Filters

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trainers").font(.title2.weight(.bold)).foregroundStyle(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TrainingCert.allCases) { cert in
                        FilterChip(title: cert.rawValue, isOn: filter.certs.contains(cert)) {
                            if filter.certs.contains(cert) { filter.certs.remove(cert) } else { filter.certs.insert(cert) }
                        }
                        .accessibilityHint(cert.fullName)
                    }
                    FilterChip(title: "Finance", systemImage: "banknote", isOn: filter.finance) { filter.finance.toggle() }
                    FilterChip(title: "IBF Fit", systemImage: "checkmark.shield", isOn: filter.ibfFit) { filter.ibfFit.toggle() }
                }
                .padding(.vertical, 2)
            }
            Picker("Show", selection: $filter.status) {
                ForEach(TrainerFilter.Status.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Results

    @ViewBuilder
    private var results: some View {
        switch state {
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.lock.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.8))
                Text(message).font(.subheadline).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                Button("Retry") { Task { await load() } }
                    .buttonStyle(.borderedProminent).tint(Theme.premier)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 32)
        default:
            if let data = currentData {
                HStack {
                    Text("\(data.count) \(data.count == 1 ? "trainer" : "trainers")")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.mist)
                    Spacer()
                    if case .loading = state { ProgressView().tint(.white).controlSize(.small) }
                }
                if data.trainers.isEmpty {
                    EmptyHint(icon: "person.crop.circle.badge.questionmark", text: "No trainers match these filters.")
                }
                LazyVStack(spacing: 12) {
                    ForEach(data.trainers) { t in
                        NavigationLink { TrainerProfileView(trainerId: t.id, name: t.name) } label: { TrainerRow(trainer: t) }
                            .buttonStyle(.plain)
                    }
                }
            } else {
                ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 40)
            }
        }
    }

    /// Keep the previous results on screen while a new search loads (no flicker).
    private var currentData: TrainersResponse? {
        if case .loaded(let d) = state { return d }
        return lastLoaded
    }

    private func load() async {
        state = .loading
        do {
            let data = try await HRMSAPI.shared.trainers(filter)
            lastLoaded = data
            state = .loaded(data)
        } catch is CancellationError {
            // Superseded by a newer search.
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load trainers.")
        }
    }
}

// MARK: - Row

private struct TrainerRow: View {
    let trainer: TrainerListItem

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(trainer.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        if let sub = subtitle {
                            Text(sub).font(.caption).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 4)
                }
                if !trainer.trainingCerts.isEmpty || trainer.financeBackground || trainer.ibfFitDeclaration {
                    FlowLayout(spacing: 6) {
                        ForEach(trainer.trainingCerts, id: \.self) { AccreditationBadge(text: $0) }
                        if trainer.financeBackground { TagPill(text: "Finance", systemImage: "banknote") }
                        if trainer.ibfFitDeclaration { TagPill(text: "IBF Fit", systemImage: "checkmark.shield") }
                    }
                }
                let tags = trainer.topTags()
                if !tags.isEmpty {
                    Text(tags.joined(separator: " · ")).font(.caption).foregroundStyle(Theme.mist)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Image(systemName: "calendar").font(.caption2)
                    Text(lastClass).font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.6))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String? {
        let parts = [trainer.nickname.map { "“\($0)”" }, trainer.trainerType,
                     trainer.status == "Active" ? nil : trainer.status].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var lastClass: String {
        guard let d = trainer.lastClassDate else { return trainer.classesCount > 0 ? "\(trainer.classesCount) classes" : "No classes on record" }
        return "Last class \(Fmt.date(d)) · \(trainer.classesCount) class\(trainer.classesCount == 1 ? "" : "es")"
    }
}

// MARK: - Profile

/// One trainer's full profile (`GET /api/mobile/trainers/{id}`), grouped into sections.
/// The NRIC is masked (S****567D) until the admin taps Show.
struct TrainerProfileView: View {
    let trainerId: String
    let name: String
    @State private var state: LoadState<TrainerDetail> = .idle
    @State private var showNric = false

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { t in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(t)
                        identity(t)
                        accreditation(t)
                        if !t.certifications.isEmpty {
                            section("Certifications", "rosette") { tags(t.certifications) }
                        }
                        if let edu = t.education {
                            section("Education", "graduationcap.fill") {
                                Text(edu).font(.subheadline).foregroundStyle(.white)
                            }
                        }
                        if !t.skills.isEmpty {
                            section("Skills", "wrench.and.screwdriver.fill") { tags(t.skills) }
                        }
                        if !t.experience.isEmpty {
                            section("Work experience", "briefcase.fill") {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(t.experience.enumerated()), id: \.offset) { _, line in
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Circle().fill(Theme.sky).frame(width: 5, height: 5)
                                            Text(line).font(.subheadline).foregroundStyle(.white)
                                        }
                                    }
                                }
                            }
                        }
                        coursesSection(t)
                        recentSection(t)
                        if let notes = t.adminNotes {
                            section("Admin notes", "note.text") {
                                Text(notes).font(.subheadline).foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
    }

    private func header(_ t: TrainerDetail) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(t.name).font(.title3.weight(.bold)).foregroundStyle(.white)
                let sub = [t.nickname.map { "“\($0)”" }, t.trainerType, t.status].compactMap { $0 }
                Text(sub.joined(separator: " · ")).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                HStack(spacing: 8) {
                    TagPill(text: t.inTms ? "In TMS" : "Not in TMS",
                            systemImage: t.inTms ? "checkmark.circle.fill" : "minus.circle")
                    TagPill(text: "\(t.classesCount) classes", systemImage: "person.3.sequence.fill")
                }
                if let last = t.lastClassDate {
                    Text("Last class \(Fmt.date(last))").font(.caption).foregroundStyle(Theme.mist)
                }
                if let summary = t.summary {
                    Text(summary).font(.footnote).foregroundStyle(.white.opacity(0.85)).padding(.top, 2)
                }
            }
        }
    }

    // MARK: Identity & contact

    private func identity(_ t: TrainerDetail) -> some View {
        section("Identity & contact", "person.text.rectangle.fill") {
            VStack(spacing: 0) {
                if t.nric != nil {
                    infoRow("NRIC", icon: "lock.fill") {
                        HStack {
                            Text(showNric ? (t.nric ?? "") : t.maskedNric)
                                .font(.subheadline.monospaced()).foregroundStyle(.white)
                                .textSelection(.enabled)
                            Spacer()
                            Button(showNric ? "Hide" : "Show") { showNric.toggle() }
                                .font(.subheadline.weight(.semibold)).tint(Theme.sky)
                                .accessibilityLabel(showNric ? "Hide NRIC" : "Show NRIC")
                        }
                    }
                }
                if let phone = t.phone {
                    linkRow("Phone", icon: "phone.fill", value: phone, url: Self.telURL(phone))
                }
                if let email = t.email {
                    linkRow("Email", icon: "envelope.fill", value: email, url: URL(string: "mailto:\(email)"))
                }
                if let email = t.secondaryEmail {
                    linkRow("Other email", icon: "envelope", value: email, url: URL(string: "mailto:\(email)"))
                }
                if let nat = t.nationality {
                    infoRow("Nationality", icon: "globe.asia.australia.fill") {
                        Text(nat).font(.subheadline).foregroundStyle(.white)
                    }
                }
                if let li = t.linkedinUrl, let url = URL(string: li.hasPrefix("http") ? li : "https://\(li)") {
                    linkRow("LinkedIn", icon: "link", value: "View profile", url: url)
                }
            }
        }
    }

    static func telURL(_ phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }

    // MARK: Accreditation

    private func accreditation(_ t: TrainerDetail) -> some View {
        let held = Set(t.trainingCerts.map { $0.uppercased() })
        let others = t.trainingCerts.filter { c in !TrainingCert.allCases.contains { $0.rawValue == c.uppercased() } }
        return section("Accreditation", "checkmark.seal.fill") {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                    ForEach(TrainingCert.allCases) { cert in
                        flag(cert.rawValue, on: held.contains(cert.rawValue))
                            .accessibilityHint(cert.fullName)
                    }
                    flag("Finance background", on: t.financeBackground)
                    flag("IBF Fit declaration", on: t.ibfFitDeclaration)
                }
                if !others.isEmpty {
                    FlowLayout(spacing: 6) { ForEach(others, id: \.self) { AccreditationBadge(text: $0) } }
                }
                if !t.financeEvidence.isEmpty {
                    detailList("Finance evidence", t.financeEvidence)
                }
                if !t.ibfFitFiles.isEmpty {
                    detailList("IBF Fit files", t.ibfFitFiles)
                }
            }
        }
    }

    private func flag(_ label: String, on: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: on ? "checkmark.seal.fill" : "xmark.circle")
                .foregroundStyle(on ? Theme.gold : .white.opacity(0.35))
            Text(label).font(.subheadline).foregroundStyle(on ? .white : .white.opacity(0.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(on ? "Yes" : "No")
    }

    private func detailList(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.mist)
            ForEach(items, id: \.self) { Text("• \($0)").font(.caption).foregroundStyle(.white.opacity(0.8)) }
        }
    }

    // MARK: Courses & classes

    @ViewBuilder
    private func coursesSection(_ t: TrainerDetail) -> some View {
        if !t.courses.isEmpty {
            section("Courses taught", "book.closed.fill") {
                VStack(spacing: 0) {
                    ForEach(Array(t.courses.enumerated()), id: \.offset) { i, c in
                        if i > 0 { Divider().overlay(.white.opacity(0.12)) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(c.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            let meta = [c.code, "\(c.classes) class\(c.classes == 1 ? "" : "es")",
                                        range(c.first, c.last)].compactMap { $0 }
                            Text(meta.joined(separator: " · ")).font(.caption).foregroundStyle(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recentSection(_ t: TrainerDetail) -> some View {
        if !t.recentClasses.isEmpty {
            section("Recent classes", "clock.arrow.circlepath") {
                VStack(spacing: 0) {
                    ForEach(Array(t.recentClasses.enumerated()), id: \.offset) { i, c in
                        if i > 0 { Divider().overlay(.white.opacity(0.12)) }
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(c.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Text([c.start.map { Fmt.date($0) }, c.run.map { "Run \($0)" }].compactMap { $0 }
                                    .joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.white.opacity(0.65))
                            }
                            Spacer()
                            if let status = c.status { StatusPill(status: status) }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    private func range(_ first: String?, _ last: String?) -> String? {
        switch (first, last) {
        case let (f?, l?): return "\(Fmt.date(f, style: .short)) – \(Fmt.date(l, style: .short))"
        case let (f?, nil): return "since \(Fmt.date(f, style: .short))"
        case let (nil, l?): return "last \(Fmt.date(l, style: .short))"
        default: return nil
        }
    }

    // MARK: Building blocks (inset-grouped sections on the brand surface)

    private func section<C: View>(_ title: String, _ icon: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline).foregroundStyle(.white.opacity(0.9))
                .accessibilityAddTraits(.isHeader)
            Card { content() }
        }
    }

    private func tags(_ items: [String]) -> some View {
        FlowLayout(spacing: 6) { ForEach(items, id: \.self) { TagPill(text: $0) } }
    }

    private func infoRow<C: View>(_ label: String, icon: String, @ViewBuilder _ value: () -> C) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.sky).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.white.opacity(0.6))
                value()
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func linkRow(_ label: String, icon: String, value: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                infoRow(label, icon: icon) {
                    HStack {
                        Text(value).font(.subheadline).foregroundStyle(Theme.sky).lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
        } else {
            infoRow(label, icon: icon) { Text(value).font(.subheadline).foregroundStyle(.white) }
        }
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.trainer(id: trainerId)) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load this trainer.") }
    }
}

// MARK: - Shared pieces

/// Toggleable filter chip (selected = royal-300 fill).
struct FilterChip: View {
    let title: String
    var systemImage: String? = nil
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isOn { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                else if let systemImage { Image(systemName: systemImage).font(.caption2) }
                Text(title).font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 14).frame(minHeight: 36)
            .foregroundStyle(isOn ? Theme.navy950 : .white)
            .background(isOn ? AnyShapeStyle(Theme.sky) : AnyShapeStyle(.white.opacity(0.1)))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(isOn ? 0 : 0.2), lineWidth: 1))
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Gold accreditation badge (ACLP / ACTA / …) — the brand's sparing warm accent.
struct AccreditationBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(Theme.navy950)
            .background(Theme.gold)
            .clipShape(Capsule())
    }
}

struct TagPill: View {
    let text: String
    var systemImage: String? = nil
    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10).padding(.vertical, 5)
        .foregroundStyle(.white)
        .background(.white.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// Wrapping row layout for tags/badges (iOS 16 `Layout`).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: proposal.width ?? width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX, x + s.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
