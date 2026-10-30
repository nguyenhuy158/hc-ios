import SwiftUI

struct HostKeyView: View {
    @Environment(\.dismiss) private var dismiss
    let prompt: HostKeyPrompt

    private var changed: Bool { prompt.previous != nil }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: changed ? "exclamationmark.shield.fill" : "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(changed ? Color.red : Color.accentColor)
                Text(changed ? "Host key changed" : "Trust this Mac?")
                    .font(.title2.bold())
                Text(changed
                     ? "\(prompt.host) now presents a different key. This happens after reinstalling macOS, or when someone is intercepting the connection. Check the fingerprint on the Mac before trusting it."
                     : "First connection to \(prompt.host). Compare this fingerprint with the one on the Mac: ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    if let previous = prompt.previous {
                        fingerprint("Saved", previous, strike: true)
                    }
                    fingerprint(changed ? "New" : "Fingerprint", prompt.fingerprint, strike: false)
                }
                Spacer()
                VStack(spacing: 12) {
                    Button(role: changed ? .destructive : nil) { dismiss() } label: {
                        Text(changed ? "Trust new key" : "Trust").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(changed ? .red : .accentColor)
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

    private func fingerprint(_ title: String, _ value: String, strike: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .strikethrough(strike)
                .foregroundStyle(strike ? .secondary : .primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview("First") { HostKeyView(prompt: MockScenario.hostKey.makeModel().hostKeyPrompt!) }
#Preview("Changed") { HostKeyView(prompt: MockScenario.hostKeyChanged.makeModel().hostKeyPrompt!) }
