import AppKit
import SwiftUI
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    private var updaterController: SPUStandardUpdaterController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LoginItemHelper.enableIfFirstLaunch()
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        setupStatusItem()

        let apiKey = KeychainHelper.load()
        if let key = apiKey, !key.isEmpty {
            startMonitoring(apiKey: key, interval: RefreshInterval.load())
        } else {
            openSettingsWindow()
        }
    }

    // MARK: - Status Item

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateTitle("MRR: --")
        setupMenu()
    }

    func updateTitle(_ title: String) {
        DispatchQueue.main.async {
            self.statusItem?.button?.title = title
        }
    }

    func setupMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit MRR Bar", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc func openSettings() {
        openSettingsWindow()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Settings Window

    func openSettingsWindow() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        NSApp.setActivationPolicy(.regular)

        let view = SettingsView(onSave: { [weak self] apiKey, interval in
            self?.settingsWindow?.close()
            self?.startMonitoring(apiKey: apiKey, interval: interval)
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MRR Bar Settings"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    // MARK: - Monitoring

    private var refreshTimer: Timer?
    private var stripeService: StripeService?

    func startMonitoring(apiKey: String, interval: RefreshInterval) {
        KeychainHelper.save(apiKey)
        stripeService = StripeService(apiKey: apiKey)

        refreshMRR()

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval.seconds, repeats: true) { [weak self] _ in
            self?.refreshMRR()
        }
    }

    func refreshMRR() {
        guard let service = stripeService else { return }

        Task {
            do {
                let result = try await service.fetchMRR()
                let amount = Double(result.cents) / 100.0
                let formatted = formatMRR(amount, currency: result.currency)
                self.updateTitle(formatted)
            } catch StripeError.unauthorized {
                self.updateTitle("MRR --")
                await MainActor.run {
                    self.openSettingsWindow()
                }
            } catch {
                self.updateTitle("MRR --")
            }
        }
    }

    private func formatMRR(_ amount: Double, currency: String) -> String {
        let code = currency.uppercased()
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        // Use a locale that natively uses this currency so the symbol is correct
        // (e.g. BRL → pt_BR gives "R$", USD → en_US gives "$", EUR → de_DE gives "€")
        if let locale = Locale.availableIdentifiers
            .lazy
            .map({ Locale(identifier: $0) })
            .first(where: { $0.currency?.identifier == code }) {
            formatter.locale = locale
        }
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(code) \(Int(amount))"
        return "MRR: \(formatted)"
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
