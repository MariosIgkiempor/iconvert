import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("showDock") private var showDock = true
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("notify") private var notifyDone = true
    @AppStorage("ffmpegPath") private var ffmpegPath = ""
    @ObservedObject private var updater = Updater.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var loginBinding: Binding<Bool> {
        Binding(get: { launchAtLogin }, set: { on in
            do {
                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch { NSSound.beep() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        })
    }

    var body: some View {
        let ffmpeg = findFFmpeg()
        Form {
            Section {
                if let version = updater.available {
                    LabeledContent("Version \(version) is available") {
                        Button(updater.updating ? "Updating…" : "Download & Install") { updater.install() }
                            .disabled(updater.updating)
                    }
                } else {
                    LabeledContent("iConvert \(Updater.current) · \(updater.checking ? "Checking…" : "Up to date")") {
                        Button("Check Now") { updater.check() }.disabled(updater.checking)
                    }
                }
            }
            Section {
                Toggle("Launch at login", isOn: loginBinding)
                Toggle("Show in Dock", isOn: $showDock).disabled(showDock && !showMenuBar)
                Toggle("Show in menu bar", isOn: $showMenuBar).disabled(showMenuBar && !showDock)
                Toggle("Notify when conversions finish", isOn: $notifyDone)
            }
            Section("ffmpeg") {
                HStack {
                    Text(ffmpeg ?? "Not found")
                        .foregroundStyle(ffmpeg == nil ? Color.red : Color.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    if !ffmpegPath.isEmpty { Button("Auto-detect") { ffmpegPath = "" } }
                    Button("Choose…") { chooseFFmpeg() }
                }
            }
            Section("Quality") {
                ForEach(Format.allCases, id: \.self) { LabeledContent($0.title, value: $0.quality) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func chooseFFmpeg() {
        let panel = NSOpenPanel()
        panel.message = "Choose the ffmpeg executable"
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/opt/homebrew/bin")
        if panel.runModal() == .OK, let url = panel.url { ffmpegPath = url.path }
    }
}
