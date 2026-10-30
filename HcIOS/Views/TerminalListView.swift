import SwiftUI

struct TerminalListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        content
            .navigationTitle("Terminals")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ConnectionBadge() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .refreshable { await model.refresh() }
            .badge(model.blockedCount)
    }

    @ViewBuilder
    private var content: some View {
        switch model.connection {
        case .disconnected(let reason):
            ContentUnavailableView {
                Label("Not connected", systemImage: "wifi.exclamationmark")
            } description: {
                Text(reason)
            } actions: {
                Button("Try again") { Task { await model.connect() } }
                    .buttonStyle(.borderedProminent)
                Button("Settings") { model.showSettings = true }
            }
        case .connecting where model.terminals.isEmpty:
            List {
                ForEach(0..<6, id: \.self) { _ in TerminalRow(terminal: MockData.terminals[2]) }
            }
            .redacted(reason: .placeholder)
        case _ where model.terminals.isEmpty:
            ContentUnavailableView("No terminals", systemImage: "terminal",
                                   description: Text("Start an agent on your Mac with hc run claude, then pull to refresh."))
        default:
            List {
                ForEach(TerminalInfo.sections(model.terminals), id: \.status) { section in
                    Section {
                        ForEach(section.items) { t in
                            NavigationLink(value: t) { TerminalRow(terminal: t) }
                        }
                    } header: {
                        Label("\(section.status.title) · \(section.items.count)", systemImage: section.status.symbol)
                            .foregroundStyle(section.status.tint)
                    }
                }
            }
        }
    }
}

struct TerminalRow: View {
    let terminal: TerminalInfo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: terminal.status.symbol)
                .font(.title3)
                .foregroundStyle(terminal.status.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(terminal.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text(statusTime)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(terminal.status == .blocked ? Color.orange : .secondary)
                        .fixedSize()
                }
                Text("\(terminal.program) · \(terminal.shortFolder)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusTime: String {
        let t = terminal.since.elapsedShort()
        return terminal.status == .blocked ? "waiting \(t)" : t
    }
}

struct ConnectionBadge: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(model.host.isEmpty ? "No Mac" : model.host.components(separatedBy: ".").first ?? model.host)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch model.connection {
        case .connected: .green
        case .connecting: .yellow
        case .disconnected: .red
        }
    }
}

#Preview("List") { NavigationStack { TerminalListView() }.environment(MockScenario.list.makeModel()) }
#Preview("Many") { NavigationStack { TerminalListView() }.environment(MockScenario.many.makeModel()) }
#Preview("Loading") { NavigationStack { TerminalListView() }.environment(MockScenario.loading.makeModel()) }
#Preview("Empty") { NavigationStack { TerminalListView() }.environment(MockScenario.empty.makeModel()) }
#Preview("Disconnected") { NavigationStack { TerminalListView() }.environment(MockScenario.disconnected.makeModel()) }
