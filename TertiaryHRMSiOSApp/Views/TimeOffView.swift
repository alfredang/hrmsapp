import SwiftUI

/// Time Off — hourly time-off requests (exams / emergencies), mirroring the
/// web app's /time-off page. Lists the employee's own requests and lets them
/// raise a new one or cancel a pending one.
struct TimeOffView: View {
    @State private var state: LoadState<[TimeOffRequest]> = .idle
    @State private var requestSheet: RequestSheet?
    @State private var cancelTarget: TimeOffRequest?
    @State private var showCancelConfirm = false
    @State private var cancelling = false
    @State private var error: String?

    /// Sheet payload (Identifiable, house pattern — see LeaveView.ApplySheet).
    private struct RequestSheet: Identifiable { let id = UUID() }

    var body: some View {
        GradientScreen {
            AsyncContent(state: $state, load: load) { requests in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PremierButton(title: "Request Time Off", systemImage: "plus.circle.fill") {
                            requestSheet = RequestSheet()
                        }

                        if let error { StatusBanner(kind: .error, text: error) }

                        Text("My requests").font(.headline).foregroundStyle(.white.opacity(0.9))
                        if requests.isEmpty {
                            EmptyHint(icon: "hourglass", text: "No time-off requests yet.")
                        } else {
                            ForEach(requests) { r in requestRow(r) }
                        }
                    }
                    .padding(20)
                }
                .refreshable { await load() }
            }
        }
        .brandBar()
        .sheet(item: $requestSheet, onDismiss: { Task { await load() } }) { _ in
            RequestTimeOffView()
                .preferredColorScheme(.dark)
        }
        .alert("Cancel time off?", isPresented: $showCancelConfirm, presenting: cancelTarget) { r in
            Button("Cancel request", role: .destructive) { cancel(r) }
            Button("Keep request", role: .cancel) {}
        } message: { r in
            Text("Cancel your time off on \(Fmt.date(r.date)) (\(TimeOffView.time12(r.startTime)) – \(TimeOffView.time12(r.endTime)))?")
        }
    }

    private func requestRow(_ r: TimeOffRequest) -> some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Fmt.date(r.date)).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text("\(TimeOffView.time12(r.startTime)) – \(TimeOffView.time12(r.endTime))")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    Text(reasonText(r))
                        .font(.caption2).foregroundStyle(.white.opacity(0.55)).lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    StatusPill(status: r.status)
                    Text(hoursText(r.hours)).font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
            }
            if let reason = r.rejectionReason, !reason.isEmpty {
                Text("Rejected: \(reason)")
                    .font(.caption).foregroundStyle(.red.opacity(0.9))
                    .padding(.top, 6)
            }
            if let comment = r.approvalComment, !comment.isEmpty {
                Text(comment)
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 6)
            }
            if r.status.uppercased() == "PENDING" {
                Button(role: .destructive) {
                    cancelTarget = r
                    showCancelConfirm = true
                } label: {
                    Label("Cancel request", systemImage: "xmark.circle")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(.white.opacity(0.1))
                        .foregroundStyle(.red.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(cancelling)
                .padding(.top, 8)
            }
        }
    }

    private func reasonText(_ r: TimeOffRequest) -> String {
        if let detail = r.reasonDetail, !detail.isEmpty { return "\(r.reasonLabel) — \(detail)" }
        return r.reasonLabel
    }

    private func hoursText(_ h: Double) -> String {
        let s = h.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", h) : String(format: "%.1f", h)
        return "\(s) hr\(h == 1 ? "" : "s")"
    }

    /// Converts an API "HH:mm" 24-hour time to a "2:00 PM" style display string.
    static func time12(_ s: String) -> String {
        hm24.date(from: s).map(hm12.string) ?? s
    }
    private static let hm24: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()
    private static let hm12: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f
    }()

    private func cancel(_ r: TimeOffRequest) {
        error = nil; cancelling = true
        Task {
            do {
                try await HRMSAPI.shared.cancelTimeOff(id: r.id)
                cancelling = false
                await load()
            } catch {
                cancelling = false
                self.error = (error as NSError).localizedDescription
            }
        }
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await HRMSAPI.shared.timeOff()) }
        catch { state = .failed((error as? LocalizedError)?.errorDescription ?? "Could not load.") }
    }
}
