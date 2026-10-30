import Cocoa
import FinderSync

@objc(IConvertFinderSync)
final class IConvertFinderSync: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    private func selectedAudio() -> [URL] {
        (FIFinderSyncController.default().selectedItemURLs() ?? []).filter(isAudioFile)
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else { return nil }
        let audio = selectedAudio()
        guard !audio.isEmpty else { return nil }

        let sub = NSMenu(title: "Convert to")
        sub.autoenablesItems = false
        for (tag, fmt) in Format.allCases.enumerated() {
            let item = NSMenuItem(title: fmt.title, action: #selector(convert(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            // Disabled when every selected file already has this format.
            item.isEnabled = audio.contains(where: fmt.applies)
            sub.addItem(item)
        }
        let top = NSMenuItem(title: "Convert to", action: nil, keyEquivalent: "")
        top.submenu = sub
        let menu = NSMenu(title: "")
        menu.addItem(top)
        return menu
    }

    @objc private func convert(_ sender: NSMenuItem) {
        var c = URLComponents()
        c.scheme = "iconvert"
        c.host = "convert"
        c.queryItems = [URLQueryItem(name: "format", value: Format.allCases[sender.tag].rawValue)]
            + selectedAudio().map { URLQueryItem(name: "path", value: $0.path) }
        if let url = c.url { NSWorkspace.shared.open(url) }
    }
}
