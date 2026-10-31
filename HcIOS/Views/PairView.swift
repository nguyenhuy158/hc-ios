import SwiftUI

struct PairView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    let request: PairRequest

    private var previous: String? { request.previousFingerprint }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: previous != nil ? "exclamationmark.shield.fill" : "qrcode.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(previous != nil ? Color.red : Color.accentColor)
                Text("Pair with this Mac?")
                    .font(.title2.bold())
                Text(previous != nil
                     ? "\(request.host) is already trusted with a different key. Only pair if you just ran hc-pair on that Mac and reinstalled it or changed its SSH key."
                     : "Only pair if you just ran hc-pair on your own Mac. This iPhone's public key will be added to it.")
                    .foregroundStyle(previous != nil ? .red : .secondary)
                VStack(alignment: .leading, spacing: 8) {
                    field("Host", request.port == "22" ? request.host : "\(request.host):\(request.port)")
                    field("User", request.user)
                    field("hc path", request.hcPath)
                    if let previous {
                        field("Saved key", previous, strike: true)
                    }
                    field(previous != nil ? "New key" : "Host key", request.fingerprint)
                }
                Spacer()
                VStack(spacing: 12) {
                    Button(role: previous != nil ? .destructive : nil) {
                        Task { await model.pair(request) }
                    } label: {
                        Text("Pair").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(previous != nil ? .red : .accentColor)
                    Button { dismiss() } label: {
                        Text("Cancel").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding(24)
        }
        .interactiveDismissDisabled()
    }

    private func field(_ title: String, _ value: String, strike: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .strikethrough(strike)
                .foregroundStyle(strike ? .secondary : .primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
