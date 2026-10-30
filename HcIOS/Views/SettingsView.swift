import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var testResult: Result<String, Error>?
    @State private var testing = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Host") {
                        TextField("mac.tailnet.ts.net", text: $model.host)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                    LabeledContent("Port") {
                        TextField("22", text: $model.port)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    LabeledContent("User") {
                        TextField("you", text: $model.user)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    LabeledContent("hc path") {
                        TextField("~/.local/bin/herdr-core", text: $model.hcPath)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                    }
                } header: {
                    Text("Mac")
                } footer: {
                    Text("Use the Mac's Tailscale name. Remote Login must be on in System Settings → General → Sharing.")
                }

                Section {
                    Text(model.publicKey)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .truncationMode(.middle)
                    Button {
                        UIPasteboard.general.string = model.publicKey
                    } label: {
                        Label("Copy public key", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: model.publicKey) {
                        Label("Share public key", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("This iPhone's key")
                } footer: {
                    Text("Add it on the Mac: append it to ~/.ssh/authorized_keys. The private key never leaves this iPhone.")
                }

                Section {
                    Button {
                        Task { await runTest() }
                    } label: {
                        HStack {
                            Label("Test connection", systemImage: "bolt.horizontal")
                            Spacer()
                            if testing { ProgressView() }
                        }
                    }
                    .disabled(model.host.isEmpty || model.user.isEmpty || testing)
                    switch testResult {
                    case .success(let version):
                        Label("Connected · \(version)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let error):
                        Label(error.localizedDescription, systemImage: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                    case nil:
                        EmptyView()
                    }
                }

                Section("Security") {
                    LabeledContent("Host key", value: model.trustedFingerprint ?? "Not trusted yet")
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Forget host key", role: .destructive) { model.forgetHostKey() }
                        .disabled(model.trustedFingerprint == nil)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        if !model.isMock { Task { await model.connect() } }
                    }
                }
            }
            .task {
                if MockScenario.current == .settingsFailed { await runTest() }
            }
        }
    }

    private func runTest() async {
        testing = true
        defer { testing = false }
        do {
            testResult = .success(try await model.test())
        } catch {
            testResult = .failure(error)
        }
    }
}

#Preview("Settings") { SettingsView().environment(MockScenario.settings.makeModel()) }
#Preview("First launch") { SettingsView().environment(MockScenario.firstLaunch.makeModel()) }
