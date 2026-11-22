import SwiftUI

/// Standard Operating Procedures (web /sop), shown natively from `GET /api/mobile/sops`, so no
/// browser sign-in is needed (Alfred, 22 Nov 2026: opening /sop in Safari hit Google's 400 page).
/// The bottom-nav tab for everyone but admins, and More → Documents → SOP for all.
struct SopListView: View {
    @State private var state: LoadState<[Sop]> = .idle
    @State private var query = ""

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { all in
                let shown = all.filter { $0.matches(query) }
                let categories = orderedCategories(shown)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Standard Operating Procedures").font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                                .accessibilityAddTraits(.isHeader)
                            Text("\(all.count) procedures in \(Set(all.map(\.category)).count) areas. Follow each SOP as written; if anything is unclear, check with your supervisor first.")
                                .font(.footnote).foregroundStyle(Theme.mist)
                        }
                        if shown.isEmpty {
                            EmptyHint(icon: "magnifyingglass", text: "No SOP matches “\(query)”.")
                        }
                        ForEach(categories, id: \.self) { cat in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(cat).font(.headline).foregroundStyle(Theme.ink.opacity(0.9))
                                Card(padding: 0) {
                                    LazyVStack(spacing: 0) {
                                        let items = shown.filter { $0.category == cat }
                                        ForEach(Array(items.enumerated()), id: \.element.id) { i, sop in
                                            if i > 0 { Divider().padding(.leading, 14) }
                                            NavigationLink { SopDetailView(sop: sop) } label: { row(sop) }
                                                .buttonStyle(.plain)
                                                .accessibilityIdentifier("sop.row.\(sop.slug)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar(bell: true)
        .searchable(text: $query, prompt: "Search SOPs")
        .autocorrectionDisabled()
    }

    private func row(_ sop: Sop) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(sop.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(sop.summary).font(.caption).foregroundStyle(Theme.mist).lineLimit(2)
                Text("\(sop.steps.count) step\(sop.steps.count == 1 ? "" : "s")" + (sop.owner.map { " · \($0)" } ?? ""))
                    .font(.caption2).foregroundStyle(Theme.mist)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.mist.opacity(0.6))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    /// Categories in the order the server lists the SOPs (the web's sort order).
    private func orderedCategories(_ list: [Sop]) -> [String] {
        var seen: [String] = []
        for s in list where !seen.contains(s.category) { seen.append(s.category) }
        return seen
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do { state = .loaded(try await HRMSAPI.shared.sops()) }
        catch is CancellationError {}
        catch {
            if (error as? URLError)?.code == .cancelled { return }
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load the SOPs.")
        }
    }
}

/// One SOP: summary, purpose / scope / owner / when to use, the numbered steps (who, when, details,
/// cautions, links), then references and the source section of the manual.
struct SopDetailView: View {
    let sop: Sop

    var body: some View {
        GradientScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sop.category.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(Theme.sky)
                        Text(sop.title).font(.title2.weight(.bold)).foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("sop.detail.title")
                        if !sop.summary.isEmpty {
                            Text(sop.summary).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.8))
                        }
                    }
                    meta
                    Text("Steps").font(.headline).foregroundStyle(Theme.ink.opacity(0.9))
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(sop.steps.enumerated()), id: \.offset) { i, step in stepCard(i + 1, step) }
                    }
                    if let refs = sop.references, !refs.isEmpty {
                        Text("References").font(.headline).foregroundStyle(Theme.ink.opacity(0.9))
                        Card(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(refs.enumerated()), id: \.offset) { i, r in
                                    if i > 0 { Divider().padding(.leading, 14) }
                                    referenceRow(r)
                                }
                            }
                        }
                    }
                    if let source = sop.source, !source.isEmpty {
                        Label("Source: \(source)", systemImage: "doc.text").font(.caption).foregroundStyle(Theme.mist)
                    }
                }
                .padding(20)
            }
        }
        .brandBar()
    }

    @ViewBuilder private var meta: some View {
        let rows: [(String, String)] = [("Purpose", sop.purpose), ("Scope", sop.scope), ("Owner", sop.owner)]
            .compactMap { l, v in v.flatMap { $0.isEmpty ? nil : (l, $0) } }
        if !rows.isEmpty || !(sop.triggers ?? []).isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rows, id: \.0) { label, value in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Theme.mist)
                            Text(value).font(.subheadline).foregroundStyle(Theme.ink)
                        }
                    }
                    if let t = sop.triggers, !t.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("WHEN TO USE").font(.caption2.weight(.semibold)).foregroundStyle(Theme.mist)
                            ForEach(t, id: \.self) { bullet($0) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func stepCard(_ n: Int, _ step: SopStep) -> some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Text("\(n)").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 28, height: 28).background(Theme.royal600).clipShape(Circle())
                VStack(alignment: .leading, spacing: 6) {
                    Text(step.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    if step.owner != nil || step.timing != nil {
                        HStack(spacing: 12) {
                            if let o = step.owner { Label(o, systemImage: "person.fill") }
                            if let t = step.timing { Label(t, systemImage: "clock") }
                        }
                        .font(.caption).foregroundStyle(Theme.sky)
                    }
                    if !step.detail.isEmpty {
                        Text(step.detail).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let items = step.items, !items.isEmpty {
                        VStack(alignment: .leading, spacing: 4) { ForEach(items, id: \.self) { bullet($0) } }
                    }
                    if let note = step.note, !note.isEmpty {
                        Label(note, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Theme.warning)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.warning.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    if let links = step.links, !links.isEmpty {
                        ForEach(links, id: \.href) { l in
                            if let url = linkURL(l.href) {
                                Link(destination: url) { Label(l.label, systemImage: "arrow.up.right.square") }
                                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.sky)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private func referenceRow(_ r: SopReference) -> some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            Text(r.label).font(.caption).foregroundStyle(Theme.mist)
            Text(r.value).font(.subheadline).foregroundStyle(r.href == nil ? Theme.ink : Theme.sky)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 10)
        if let h = r.href, let url = linkURL(h) { Link(destination: url) { content } } else { content }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(Theme.sky).frame(width: 5, height: 5).offset(y: -2)
            Text(text).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Absolute links as given; a site path ("/leave") opens on the HRMS website.
    private func linkURL(_ href: String) -> URL? {
        if href.hasPrefix("/") { return AuthService.baseURL.appendingPathComponent(String(href.dropFirst())) }
        return URL(string: href)
    }
}
