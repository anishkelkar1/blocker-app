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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AuthBanner()

                    statusCard

                    if controller.isBlocking {
                        stopControls
                    } else {
                        startControls
                    }
                }
                .padding()
            }
            .navigationTitle("FocusLock")
            .onAppear { controller.refresh() }
            .alert("Enter PIN to stop", isPresented: $showPINPrompt) {
                SecureField("PIN", text: $pinEntry)
                    .keyboardType(.numberPad)
                Button("Stop", role: .destructive) { attemptStop(pin: pinEntry) }
                Button("Cancel", role: .cancel) { pinEntry = "" }
            }
            .alert("Can't stop yet",
                   isPresented: .constant(stopError != nil)) {
                Button("OK") { stopError = nil }
            } message: {
                Text(stopError ?? "")
            }
        }
    }

    // MARK: Status

    private var statusCard: some View {
        VStack(spacing: 8) {
            Image(systemName: controller.isBlocking ? "lock.fill" : "lock.open")
                .font(.system(size: 44))
                .foregroundStyle(controller.isBlocking ? .green : .secondary)
            Text(controller.isBlocking ? "Blocking active" : "Not blocking")
                .font(.title2.bold())
            if let until = controller.lockedUntil {
                Text("Ends \(until.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
            Text(controller.strictLevel.title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Label(tunnel.isActive ? "Website filter on (all browsers)" : "Website filter off",
                  systemImage: tunnel.isActive ? "globe.badge.chevron.backward" : "globe")
                .font(.caption)
                .foregroundStyle(tunnel.isActive ? .green : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Start

    private var startControls: some View {
        VStack(spacing: 16) {
            Toggle("Timed session", isOn: $useTimer)
            if useTimer {
                VStack(alignment: .leading) {
                    Text("Duration: \(Int(durationMinutes)) min")
                    Slider(value: $durationMinutes, in: 5...480, step: 5)
                }
            }
            Button {
                controller.start(duration: useTimer ? durationMinutes * 60 : nil)
                Task { await tunnel.start() } // cross-browser website filter
            } label: {
                Text(controller.hasSelection ? "Start blocking" : "Pick a blocklist first")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!controller.hasSelection)
        }
    }

    // MARK: Stop

    private var stopControls: some View {
        Button(role: .destructive) {
            attemptStop(pin: nil)
        } label: {
            Text("Stop blocking").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func attemptStop(pin: String?) {
        switch controller.requestStop(pin: pin) {
        case .stopped:
            tunnel.stop()
            pinEntry = ""
        case .needsPIN:
            if pin == nil {
                showPINPrompt = true
            } else {
                stopError = "Wrong PIN."
                pinEntry = ""
            }
        case .hardLocked:
            stopError = "This session is locked until the timer ends. The PIN can't override a hard timer."
        }
    }
}
