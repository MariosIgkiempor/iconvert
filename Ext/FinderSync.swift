import Cocoa
import FinderSync

@objc(IConvertFinderSync)
final class IConvertFinderSync: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    private func selection() -> (audio: [URL], folders: [URL]) {
        let urls = FIFinderSyncController.default().selectedItemURLs() ?? []
        let folders = urls.filter {
            let v = try? $0.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            return v?.isDirectory == true && v?.isPackage != true
        }
        return (urls.filter(isAudioFile), folders)
    }

    private func submenu(_ title: String, action: Selector, enabled: (Format) -> Bool) -> NSMenuItem {
        let sub = NSMenu(title: title)
        sub.autoenablesItems = false
        for (tag, fmt) in Format.allCases.enumerated() {
            let item = NSMenuItem(title: fmt.title, action: action, keyEquivalent: "")
            item.target = self
            item.tag = tag
            item.isEnabled = enabled(fmt)
            sub.addItem(item)
        }
        let top = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        top.submenu = sub
        return top
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else { return nil }
        let (audio, folders) = selection()
        guard !audio.isEmpty || !folders.isEmpty else { return nil }

        let menu = NSMenu(title: "")
        if !audio.isEmpty {
            // Disabled when every selected file already has that format.
            menu.addItem(submenu("Convert to", action: #selector(convertFiles(_:))) { fmt in
                audio.contains(where: fmt.applies)
            })
        }
        if !folders.isEmpty {
            menu.addItem(submenu("Convert Folder to", action: #selector(convertFolders(_:))) { _ in true })
        }
        return menu
    }

    private func send(_ sender: NSMenuItem, key: String, urls: [URL]) {
        var c = URLComponents()
        c.scheme = "iconvert"
        c.host = "convert"
        c.queryItems = [URLQueryItem(name: "format", value: Format.allCases[sender.tag].rawValue)]
            + urls.map { URLQueryItem(name: key, value: $0.path) }
        if let url = c.url { NSWorkspace.shared.open(url) }
    }

    @objc private func convertFiles(_ sender: NSMenuItem) { send(sender, key: "path", urls: selection().audio) }
    @objc private func convertFolders(_ sender: NSMenuItem) { send(sender, key: "folder", urls: selection().folders) }
}
