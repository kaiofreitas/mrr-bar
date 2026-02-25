import SwiftUI
import ServiceManagement

enum RefreshInterval: Int, CaseIterable {
    case fiveMin = 5
    case fifteenMin = 15
    case oneHour = 60

    var label: String {
        switch self {
        case .fiveMin: return "5 min"
        case .fifteenMin: return "15 min"
        case .oneHour: return "1 hour"
        }
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue * 60)
    }

    static func load() -> RefreshInterval {
        let stored = UserDefaults.standard.integer(forKey: "refreshInterval")
        return RefreshInterval(rawValue: stored) ?? .fifteenMin
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "refreshInterval")
    }
}

enum LoginItemHelper {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func enable() {
        try? SMAppService.mainApp.register()
    }

    static func disable() {
        try? SMAppService.mainApp.unregister()
    }

    // Register on first launch if not yet decided
    static func enableIfFirstLaunch() {
        let key = "loginItemConfigured"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        enable()
    }
}

struct SettingsView: View {
    let onSave: (String, RefreshInterval) -> Void

    @State private var apiKey: String = ""
    @State private var interval: RefreshInterval = RefreshInterval.load()
    @State private var startAtLogin: Bool = LoginItemHelper.isEnabled
    @State private var statusMessage: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MRR Bar Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Stripe API Key")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                SecureField("sk_live_...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Refresh interval")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $interval) {
                    ForEach(RefreshInterval.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            Toggle("Start at login", isOn: $startAtLogin)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            if let existing = KeychainHelper.load() {
                apiKey = existing
            }
        }
    }

    private func saveSettings() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            statusMessage = "Please enter a valid Stripe API key."
            return
        }
        interval.save()
        startAtLogin ? LoginItemHelper.enable() : LoginItemHelper.disable()
        onSave(trimmed, interval)
    }
}
