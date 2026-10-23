import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthorizationManager
    @EnvironmentObject var controller: BlockController
    @EnvironmentObject var tunnel: TunnelController

    @State private var durationMinutes: Double = 60
    @State private var useTimer = false
    @State private var showPINPrompt = false
    @State private var pinEntry = ""
    @State private var stopError: String?
    @State private var blocklists: [Blocklist] = BlocklistStore.all

    private var scheduledCount: Int { SharedState.scheduledActiveIDs.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
            .navigationTitle("FocusLock")
            .onAppear {
                controller.refresh()
                blocklists = BlocklistStore.all
            }
            .alert("Enter PIN to stop", isPresented: $showPINPrompt) {
                SecureField("PIN", text: $pinEntry).keyboardType(.numberPad)
                Button("Stop", role: .destructive) { attemptStop(pin: pinEntry) }
                Button("Cancel", role: .cancel) { pinEntry = "" }
            }
            .alert("Can't stop yet", isPresented: .constant(stopError != nil)) {
                Button("OK") { stopError = nil }
            } message: { Text(stopError ?? "") }
        }
    }

    private var statusCard: some View {
        VStack(spacing: 8) {
            Image(systemName: SharedState.anyActive ? "lock.fill" : "lock.open")
                .font(.system(size: 44))
                .foregroundStyle(SharedState.anyActive ? .green : .secondary)
            Text(SharedState.anyActive ? "Blocking active" : "Not blocking")
                .font(.title2.bold())
            Text("\(SharedState.activeIDs.count) blocklist(s) active"
                 + (scheduledCount > 0 ? " · \(scheduledCount) by schedule" : ""))
                .font(.footnote).foregroundStyle(.secondary)
            if let until = controller.lockedUntil {
                Text("Manual session ends \(until.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Label(tunnel.isActive ? "Website filter on (all browsers)" : "Website filter off",
                  systemImage: tunnel.isActive ? "globe.badge.chevron.backward" : "globe")
                .font(.caption)
                .foregroundStyle(tunnel.isActive ? .green : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Text("No blocklists yet.").font(.headline)
            Text("Create one in the Blocklists tab, then run it here or schedule it.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var startControls: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Run which blocklists?").font(.headline)
                ForEach(blocklists) { list in
                    let on = controller.selectedBlocklistIDs.contains(list.id)
                    Button {
                        if on { controller.selectedBlocklistIDs.remove(list.id) }
                        else { controller.selectedBlocklistIDs.insert(list.id) }
                    } label: {
                        HStack {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? Color.accentColor : .secondary)
                            Text(list.name)
                            Spacer()
                        }
                    }
                    .tint(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("Timed session", isOn: $useTimer)
            if useTimer {
                VStack(alignment: .leading) {
                    Text("Duration: \(Int(durationMinutes)) min")
                    Slider(value: $durationMinutes, in: 5...480, step: 5)
                }
            }

            Button {
                controller.start(duration: useTimer ? durationMinutes * 60 : nil)
                Task { await tunnel.start() }
            } label: {
                Text("Start blocking").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(controller.selectedBlocklistIDs.isEmpty)
        }
    }

    private var stopControls: some View {
        Button(role: .destructive) {
            attemptStop(pin: nil)
        } label: {
            Text("Stop manual block").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func attemptStop(pin: String?) {
        switch controller.requestStop(pin: pin) {
        case .stopped:
            if SharedState.scheduledActiveIDs.isEmpty { tunnel.stop() }
            pinEntry = ""
        case .needsPIN:
            if pin == nil { showPINPrompt = true }
            else { stopError = "Wrong PIN."; pinEntry = "" }
        case .hardLocked:
            stopError = "This session is locked until the timer ends. The PIN can't override a hard timer."
        }
    }
}
