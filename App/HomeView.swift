import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthorizationManager
    @EnvironmentObject var controller: BlockController
    @EnvironmentObject var tunnel: TunnelController

    @State private var durationMinutes: Double = 60
    @State private var useTimer = false
    @State private var stopError: String?
    @State private var blocklists: [Blocklist] = BlocklistStore.all

    private var scheduledCount: Int { SharedState.scheduledActiveIDs.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    AuthBanner()
                    statusCard
                    if controller.isManualRunning {
                        stopControls
                    } else if blocklists.isEmpty {
                        emptyHint
                    } else {
                        startControls
                    }
                }
                .padding()
            }
            .focusLockScreen()
            .navigationTitle("FocusLock")
            .onAppear {
                controller.refresh()
                blocklists = BlocklistStore.all
            }
            .alert("Can't stop yet", isPresented: .constant(stopError != nil)) {
                Button("OK") { stopError = nil }
            } message: { Text(stopError ?? "") }
        }
    }

    private var statusCard: some View {
        VStack(spacing: 10) {
            Image(systemName: SharedState.anyActive ? "lock.fill" : "lock.open")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(SharedState.anyActive ? Theme.navy : Theme.silver)
            Text(SharedState.anyActive ? "Blocking active" : "Not blocking")
                .font(.title2.bold())
                .foregroundStyle(Theme.navyDeep)
            Text("\(SharedState.activeIDs.count) blocklist(s) active"
                 + (scheduledCount > 0 ? " · \(scheduledCount) by schedule" : ""))
                .font(.footnote).foregroundStyle(Theme.silver)
            if let until = controller.lockedUntil {
                Text("Manual session ends \(until.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote).foregroundStyle(Theme.silver)
            }
            Label(tunnel.isActive ? "Website filter on (all browsers)" : "Website filter off",
                  systemImage: tunnel.isActive ? "globe.badge.chevron.backward" : "globe")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tunnel.isActive ? Theme.navy : Theme.silver)
                .padding(.top, 2)
        }
        .card(22)
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Text("No blocklists yet.").font(.headline).foregroundStyle(Theme.navyDeep)
            Text("Create one in the Blocklists tab, then run it here or schedule it.")
                .font(.footnote).foregroundStyle(Theme.silver).multilineTextAlignment(.center)
        }
        .card()
    }

    private var startControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Run which blocklists?").font(.headline).foregroundStyle(Theme.navyDeep)
            ForEach(blocklists) { list in
                let on = controller.selectedBlocklistIDs.contains(list.id)
                Button {
                    if on { controller.selectedBlocklistIDs.remove(list.id) }
                    else { controller.selectedBlocklistIDs.insert(list.id) }
                } label: {
                    HStack {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(on ? Theme.navy : Theme.silver)
                        Text(list.name).foregroundStyle(Theme.navyDeep)
                        Spacer()
                    }
                }
            }

            Toggle("Timed session", isOn: $useTimer).tint(Theme.navy)
            if useTimer {
                VStack(alignment: .leading) {
                    Text("Duration: \(Int(durationMinutes)) min").foregroundStyle(Theme.navyDeep)
                    Slider(value: $durationMinutes, in: 5...480, step: 5).tint(Theme.navy)
                }
            }

            Button {
                controller.start(duration: useTimer ? durationMinutes * 60 : nil)
                Task { await tunnel.start() }
            } label: { Text("Start blocking") }
            .buttonStyle(FilledPill())
            .disabled(controller.selectedBlocklistIDs.isEmpty)
            .opacity(controller.selectedBlocklistIDs.isEmpty ? 0.5 : 1)
        }
        .card()
    }

    private var stopControls: some View {
        Button { attemptStop() } label: { Text("Stop blocking") }
            .buttonStyle(OutlinePill(tint: Theme.danger))
            .card()
    }

    private func attemptStop() {
        switch controller.requestStop(pin: nil) {
        case .stopped:
            if SharedState.scheduledActiveIDs.isEmpty { tunnel.stop() }
        case .needsPIN:
            stopError = "A PIN is required to stop this block."
        case .hardLocked:
            stopError = "This session is locked until the timer ends."
        }
    }
}
