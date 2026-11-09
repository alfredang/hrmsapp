import SwiftUI

/// Trainer Admins: the trainer directory (`GET /api/mobile/trainers`), built to find a
/// trainer by skill or certification fast and reach them in one tap.
/// - `.searchable` with suggestions of skills / certifications (with trainer counts); a
///   picked suggestion becomes a removable filter token.
/// - Accreditation (ACLP / ACTA / DACE / DDDLP / Finance / IBF Fit) and Trainers /
///   Applicants live in one filter menu, not a wall of chips.
/// - Compact rows: name, accreditation badges, the matching skill first; call / WhatsApp /
///   email / copy from the row's contact menu.
/// The whole list is loaded once and filtered on the device (same rules as the web).
/// Shown from the More menu only when the summary reports `canManageTrainers`; the server
/// enforces TRAINER_ADMIN (403 otherwise). The list never carries NRIC.
struct TrainersView: View {
    @State private var state: LoadState<[TrainerListItem]> = .idle
    @State private var query = PreviewData.query ?? ""
    @State private var tokens: [TrainerTag] = []
    @State private var accreditations: Set<TrainerAccreditation> = []
    @State private var status: TrainerFilter.Status = .trainers

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { all in
                let shown = filtered(all)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        summaryBar(shown: shown.count, total: all.count)
                        if shown.isEmpty {
                            EmptyHint(icon: "person.crop.circle.badge.questionmark",
                                      text: "No trainers match. Remove a filter or try another skill.")
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(shown.enumerated()), id: \.element.id) { i, t in
                                    if i > 0 { Divider().padding(.leading, 16) }
                                    TrainerRow(trainer: t, needles: needles)
                                }
                            }
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
                            .shadow(color: Theme.navy950.opacity(0.05), radius: 8, y: 3)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
        .searchable(text: $query, tokens: $tokens, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Skill, certification or name") { token in
            Label(token.tag, systemImage: token.kind == .skill ? "wrench.and.screwdriver" : "rosette")
        }
        .searchSuggestions { suggestionList }
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }

    // MARK: Search suggestions

    @ViewBuilder
    private var suggestionList: some View {
        if case .loaded(let all) = state {
            let vocab = TrainerDirectory.vocabulary(all)
            let picks = TrainerDirectory.suggestions(vocab, text: query, excluding: tokens.map(\.tag))
            if !picks.isEmpty {
                Section(query.isEmpty ? "Popular skills & certifications" : "Skills & certifications") {
                    ForEach(picks) { s in
                        HStack {
                            Label(s.tag, systemImage: s.kind == .skill ? "wrench.and.screwdriver" : "rosette")
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(s.count)").font(.footnote.weight(.semibold)).monospacedDigit()
                                .foregroundStyle(Theme.mist)
                        }
                        .searchCompletion(s)
                    }
                }
            }
        }
    }

    // MARK: Filter menu

    private var activeFilterCount: Int { accreditations.count + (status == .trainers ? 0 : 1) }

    private var filterMenu: some View {
        Menu {
            Section("Accreditation") {
                ForEach(TrainerAccreditation.allCases) { a in
                    Toggle(isOn: Binding(
                        get: { accreditations.contains(a) },
                        set: { on in if on { accreditations.insert(a) } else { accreditations.remove(a) } }
                    )) { Label(a.title, systemImage: a.systemImage) }
                }
            }
            Section("Show") {
                Picker("Show", selection: $status) {
                    Text("Trainers").tag(TrainerFilter.Status.trainers)
                    Text("Applicants").tag(TrainerFilter.Status.applicants)
                    Text("Everyone").tag(TrainerFilter.Status.all)
                }
            }
            if activeFilterCount > 0 || !tokens.isEmpty {
                Button(role: .destructive) { clearAll() } label: { Label("Clear all filters", systemImage: "xmark.circle") }
            }
        } label: {
            Label(activeFilterCount > 0 ? "Filters (\(activeFilterCount))" : "Filters",
                  systemImage: activeFilterCount > 0
                  ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.sky)
                .padding(.horizontal, 10).frame(minHeight: 34)
                .background(Theme.sky.opacity(0.09))
                .clipShape(Capsule())
        }
        .accessibilityLabel("Filters")
        .accessibilityValue(activeFilterCount > 0 ? "\(activeFilterCount) on" : "none")
    }

    // MARK: Summary bar (count + removable accreditation filters)

    private func summaryBar(shown: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Trainers").font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(shown) of \(total)").font(.footnote.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(Theme.mist)
                // In the content (not the nav bar) so it stays reachable while searching.
                filterMenu
            }
            let chips = activeChips
            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(chips, id: \.title) { chip in
                            Button(action: chip.remove) {
                                HStack(spacing: 4) {
                                    Text(chip.title)
                                    Image(systemName: "xmark").font(.caption2.weight(.bold))
                                }
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 10).frame(minHeight: 32)
                                .foregroundStyle(Theme.sky)
                                .background(Theme.mist100.opacity(0.55))
                                .clipShape(Capsule())
                            }
                            .accessibilityLabel("Remove filter \(chip.title)")
                        }
                    }
                }
            }
        }
    }

    private struct Chip { let title: String; let remove: () -> Void }

    private var activeChips: [Chip] {
        var out = TrainerAccreditation.allCases.filter { accreditations.contains($0) }.map { a in
            Chip(title: a.title) { accreditations.remove(a) }
        }
        if status != .trainers {
            out.append(Chip(title: status == .applicants ? "Applicants" : "Everyone") { status = .trainers })
        }
        return out
    }

    private func clearAll() {
        tokens = []; accreditations = []; status = .trainers; query = ""
    }

    // MARK: Data

    /// The search words and picked tags — used to put the matching skill first in each row.
    private var needles: [String] { tokens.map(\.tag) + [query] }

    private func filtered(_ all: [TrainerListItem]) -> [TrainerListItem] {
        TrainerDirectory.filter(all, query: query, tags: tokens.map(\.tag),
                                accreditations: accreditations, status: status)
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            state = .loaded(try await HRMSAPI.shared.trainers(TrainerFilter(status: .all)).trainers)
        } catch is CancellationError {
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load trainers.")
        }
    }
}

// MARK: - Row

/// One compact trainer row: name + accreditation badges, then the matching skill first.
/// Tap opens the profile; the round button (or a long press) offers call / WhatsApp / email / copy.
private struct TrainerRow: View {
    let trainer: TrainerListItem
    let needles: [String]

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink { TrainerProfileView(trainerId: trainer.id, name: trainer.name) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trainer.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        .lineLimit(1).truncationMode(.tail)
                    HStack(spacing: 6) {
                        badges
                        Text(expertise)
                            .font(.caption).foregroundStyle(Theme.mist)
                            .lineLimit(1).truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if trainer.phone != nil || trainer.email != nil {
                Menu {
                    ContactMenuItems(phone: trainer.phone, email: trainer.email)
                } label: {
                    Image(systemName: "phone.circle.fill")
                        .font(.title2).foregroundStyle(Theme.sky)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Contact \(trainer.name)")
            }
        }
        .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 8)
        .contextMenu { ContactMenuItems(phone: trainer.phone, email: trainer.email) }
    }

    private var badges: some View {
        HStack(spacing: 3) {
            ForEach(trainer.trainingCerts.prefix(4), id: \.self) { AccreditationBadge(text: $0, compact: true) }
            if trainer.financeBackground {
                Image(systemName: "banknote").font(.caption2).foregroundStyle(Theme.success)
                    .accessibilityLabel("Finance background")
            }
            if trainer.ibfFitDeclaration {
                Image(systemName: "checkmark.shield.fill").font(.caption2).foregroundStyle(Theme.sky)
                    .accessibilityLabel("IBF Fit")
            }
            if TrainerDirectory.isApplicant(trainer) {
                Text(trainer.status).font(.caption2.weight(.semibold)).foregroundStyle(Theme.warning)
            }
        }
        .fixedSize()
    }

    private var expertise: String {
        let items = TrainerDirectory.orderByMatch(trainer.skills + trainer.certifications, needles: needles)
        if items.isEmpty {
            return trainer.lastClassDate.map { "Last class \(Fmt.date($0))" } ?? (trainer.trainerType ?? "—")
        }
        return items.prefix(6).joined(separator: " · ")
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
                                Text(edu).font(.subheadline).foregroundStyle(Theme.ink)
                            }
                        }
                        if !t.skills.isEmpty {
                            section("Skills", "wrench.and.screwdriver.fill") { tags(t.skills) }
                        }
                        if !t.experience.isEmpty {
                            section("Work experience", "briefcase.fill", expanded: false) {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(t.experience.enumerated()), id: \.offset) { _, line in
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Circle().fill(Theme.sky).frame(width: 5, height: 5)
                                            Text(line).font(.subheadline).foregroundStyle(Theme.ink)
                                        }
                                    }
                                }
                            }
                        }
                        coursesSection(t)
                        recentSection(t)
                        if let notes = t.adminNotes {
                            section("Admin notes", "note.text") {
                                Text(notes).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.9))
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
                Text(t.name).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                let sub = [t.nickname.map { "“\($0)”" }, t.trainerType, t.status].compactMap { $0 }
                Text(sub.joined(separator: " · ")).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.75))
                HStack(spacing: 8) {
                    TagPill(text: t.inTms ? "In TMS" : "Not in TMS",
                            systemImage: t.inTms ? "checkmark.circle.fill" : "minus.circle")
                    TagPill(text: "\(t.classesCount) classes", systemImage: "person.3.sequence.fill")
                }
                if let last = t.lastClassDate {
                    Text("Last class \(Fmt.date(last))").font(.caption).foregroundStyle(Theme.mist)
                }
                if let summary = t.summary {
                    Text(summary).font(.footnote).foregroundStyle(Theme.ink.opacity(0.85)).padding(.top, 2)
                }
                if t.phone != nil || t.email != nil {
                    ContactButtonsRow(phone: t.phone, email: t.email).padding(.top, 6)
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
                                .font(.subheadline.monospaced()).foregroundStyle(Theme.ink)
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
                        Text(nat).font(.subheadline).foregroundStyle(Theme.ink)
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
                .foregroundStyle(on ? Theme.gold : Theme.ink.opacity(0.35))
            Text(label).font(.subheadline).foregroundStyle(on ? .white : Theme.ink.opacity(0.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(on ? "Yes" : "No")
    }

    private func detailList(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.mist)
            ForEach(items, id: \.self) { Text("• \($0)").font(.caption).foregroundStyle(Theme.ink.opacity(0.8)) }
        }
    }

    // MARK: Courses & classes

    @ViewBuilder
    private func coursesSection(_ t: TrainerDetail) -> some View {
        if !t.courses.isEmpty {
            section("Courses taught (\(t.courses.count))", "book.closed.fill", expanded: false) {
                VStack(spacing: 0) {
                    ForEach(Array(t.courses.enumerated()), id: \.offset) { i, c in
                        if i > 0 { Divider().overlay(Theme.ink.opacity(0.12)) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(c.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            let meta = [c.code, "\(c.classes) class\(c.classes == 1 ? "" : "es")",
                                        range(c.first, c.last)].compactMap { $0 }
                            Text(meta.joined(separator: " · ")).font(.caption).foregroundStyle(Theme.ink.opacity(0.65))
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
            section("Recent classes", "clock.arrow.circlepath", expanded: false) {
                VStack(spacing: 0) {
                    ForEach(Array(t.recentClasses.enumerated()), id: \.offset) { i, c in
                        if i > 0 { Divider().overlay(Theme.ink.opacity(0.12)) }
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(c.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                Text([c.start.map { Fmt.date($0) }, c.run.map { "Run \($0)" }].compactMap { $0 }
                                    .joined(separator: " · "))
                                    .font(.caption).foregroundStyle(Theme.ink.opacity(0.65))
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

    /// A collapsible section (secondary detail starts collapsed to keep the profile short).
    private func section<C: View>(_ title: String, _ icon: String, expanded: Bool = true,
                                  @ViewBuilder _ content: () -> C) -> some View {
        CollapsibleSection(title: title, icon: icon, expanded: expanded) {
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
                Text(label).font(.caption).foregroundStyle(Theme.ink.opacity(0.6))
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
                        Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Theme.ink.opacity(0.4))
                    }
                }
            }
        } else {
            infoRow(label, icon: icon) { Text(value).font(.subheadline).foregroundStyle(Theme.ink) }
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
            .foregroundStyle(isOn ? .white : Theme.ink)
            .background(isOn ? AnyShapeStyle(Theme.sky) : AnyShapeStyle(Theme.card))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.fieldBorder.opacity(isOn ? 0 : 1), lineWidth: 1))
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Gold accreditation badge (ACLP / ACTA / …) — the brand's sparing warm accent.
struct AccreditationBadge: View {
    let text: String
    var compact = false
    var body: some View {
        Text(text)
            .font(compact ? .system(size: 10, weight: .bold) : .caption2.weight(.bold))
            .padding(.horizontal, compact ? 5 : 8).padding(.vertical, compact ? 1.5 : 3)
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
        .foregroundStyle(Theme.navy800)
        .background(Theme.mist100.opacity(0.45))
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
