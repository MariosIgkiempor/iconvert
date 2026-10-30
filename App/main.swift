import Cocoa
import SwiftUI
import ServiceManagement
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let queue = DispatchQueue(label: "iconvert.convert")
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var launchedByURL = false
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ note: Notification) {
        UserDefaults.standard.register(defaults: ["showDock": true, "showMenuBar": true, "notify": true])
        buildMainMenu()
        applyPreferences()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applyPreferences()
        }

        // Daily update check (the app is long-running, so poll hourly for "due").
        Updater.shared.checkIfDue()
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in Updater.shared.checkIfDue() }
        Updater.shared.$available.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &cancellables)

        // First run from an installed location: start at login by default.
        let d = UserDefaults.standard
        if !d.bool(forKey: "didSetLoginDefault"), Bundle.main.bundlePath.contains("/Applications/") {
            try? SMAppService.mainApp.register()
            d.set(true, forKey: "didSetLoginDefault")
        }

        // Show settings on a normal launch, not when started at login or by the Finder menu.
        let event = NSAppleEventManager.shared().currentAppleEvent
        let atLogin = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            if !atLogin && !launchedByURL { showSettings() }
        }
    }

    func applyPreferences() {
        let d = UserDefaults.standard
        NSApp.setActivationPolicy(d.bool(forKey: "showDock") ? .regular : .accessory)
        if d.bool(forKey: "showMenuBar") {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                let menu = NSMenu()
                menu.delegate = self
                item.menu = menu
                statusItem = item
                updateStatusIcon()
            }
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func updateStatusIcon() {
        let symbol = Updater.shared.available == nil ? "waveform" : "arrow.down.circle"
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "iConvert")
    }

    // Rebuilt each time it opens so the update item reflects the latest check.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let updater = Updater.shared
        if let version = updater.available {
            let item = menu.addItem(withTitle: updater.updating ? "Updating…" : "Update to v\(version)",
                                    action: #selector(installUpdate), keyEquivalent: "")
            item.target = self
            item.isEnabled = !updater.updating
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit iConvert", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc func installUpdate() { Updater.shared.install() }

    func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let m = NSMenu()
        m.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        m.addItem(.separator())
        m.addItem(withTitle: "Hide iConvert", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        m.addItem(withTitle: "Quit iConvert", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = m
        NSApp.mainMenu = main
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let host = NSHostingView(rootView: SettingsView())
            let w = NSWindow(contentViewController: NSViewController())
            w.contentView = host
            w.title = "iConvert Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    // iconvert://convert?format=mp3&path=/a.flac&folder=/Album
    func application(_ app: NSApplication, open urls: [URL]) {
        launchedByURL = true
        for url in urls {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard let fmt = items.first(where: { $0.name == "format" })?.value.flatMap(Format.init) else { continue }
            let files = items.filter { $0.name == "path" }.compactMap(\.value)
            let folders = items.filter { $0.name == "folder" }.compactMap(\.value)
            queue.async { convert(files: files, folders: folders, to: fmt) }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
