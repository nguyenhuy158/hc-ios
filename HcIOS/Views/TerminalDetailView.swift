import SwiftUI

struct TerminalDetailView: View {
    @Environment(AppModel.self) private var model
    let terminal: TerminalInfo
    @State private var draft = ""
    @State private var screen: String?
    @State private var readError: String?
    @State private var confirmInterrupt = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(screen ?? terminal.screen)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding()
                    Color.clear.frame(width: 1, height: 1).id("bottom")
                }
                .frame(minWidth: UIScreen.main.bounds.width, alignment: .leading)
            }
            .defaultScrollAnchor(.bottomLeading)
            .onAppear { proxy.scrollTo("bottom", anchor: .bottomLeading) }
        }
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .top) {
            if let readError {
                Text(readError)
                    .font(.footnote)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.15))
            }
        }
        .task(id: terminal.id) {
            guard !model.isMock else { return }
            while !Task.isCancelled {
                do {
                    screen = try await model.client.read(terminal.id)
                    readError = nil
                } catch {
                    readError = error.localizedDescription
                }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
        .navigationTitle(terminal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Label(terminal.status.title, systemImage: terminal.status.symbol)
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline)
                    .foregroundStyle(terminal.status.tint)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { controls }
        .confirmationDialog("Stop \(terminal.name)?", isPresented: $confirmInterrupt, titleVisibility: .visible) {
            Button("Send ctrl+c", role: .destructive) { press(["ctrl+c"]) }
        } message: {
            Text("The running program gets an interrupt. Unsaved agent work may be lost.")
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            if terminal.status == .blocked {
                HStack(spacing: 12) {
                    Button { press(["esc"]) } label: {
                        Label("Deny", systemImage: "xmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button { press(["1"]) } label: {
                        Label("Allow", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
            }
            QuickKeysBar(onKeys: press, onInterrupt: { confirmInterrupt = true })
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message \(terminal.program)…", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.separator)))
                Button {
                    let text = draft
                    draft = ""
                    Task {
                        do {
                            try await model.client.send(terminal.id, text: text)
                        } catch {
                            readError = error.localizedDescription
                            draft = text
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.connection != .connected)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func press(_ keys: [String]) {
        Task {
            do {
                try await model.client.keys(terminal.id, keys)
            } catch {
                readError = error.localizedDescription
            }
        }
    }
}

struct QuickKeysBar: View {
    let onKeys: ([String]) -> Void
    let onInterrupt: () -> Void

    private let keys: [(label: String, key: String)] = [
        ("1", "1"), ("2", "2"), ("3", "3"), ("y", "y"), ("n", "n"),
        ("⏎", "enter"), ("esc", "esc"), ("↑", "up"), ("↓", "down"), ("⇥", "tab"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(keys, id: \.key) { k in
                    Button(k.label) { onKeys([k.key]) }
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 44, minHeight: 36)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel(k.key)
                }
                Button("^C", action: onInterrupt)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.red)
                    .frame(minWidth: 44, minHeight: 36)
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("ctrl+c")
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Blocked") { NavigationStack { TerminalDetailView(terminal: MockData.terminals[0]) }.environment(MockScenario.detail.makeModel()) }
#Preview("Working") { NavigationStack { TerminalDetailView(terminal: MockData.terminals[2]) }.environment(MockScenario.detail.makeModel()) }
#Preview("Long") { NavigationStack { TerminalDetailView(terminal: MockData.terminals[3]) }.environment(MockScenario.detail.makeModel()) }
