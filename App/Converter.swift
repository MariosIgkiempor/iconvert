import Foundation

@discardableResult
func run(_ exe: String, _ args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: exe)
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    try? p.run()
    p.waitUntilExit()
    return p.terminationStatus
}

func notify(_ message: String) {
    guard UserDefaults.standard.bool(forKey: "notify") else { return }
    run("/usr/bin/osascript", ["-e", "display notification \"\(message)\" with title \"iConvert\""])
}

func findFFmpeg() -> String? {
    let custom = UserDefaults.standard.string(forKey: "ffmpegPath") ?? ""
    return ([custom] + ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/opt/local/bin/ffmpeg"])
        .first { !$0.isEmpty && FileManager.default.isExecutableFile(atPath: $0) }
}

func hasEncoder(_ name: String, ffmpeg: String) -> Bool {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: ffmpeg)
    p.arguments = ["-hide_banner", "-encoders"]
    p.standardOutput = pipe
    try? p.run()
    let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    p.waitUntilExit()
    return out.contains(" \(name) ")
}

private func uniqueURL(_ dir: URL, _ name: String, _ ext: String) -> URL {
    var out = dir.appendingPathComponent(name).appendingPathExtension(ext)
    var n = 1
    while FileManager.default.fileExists(atPath: out.path) {
        out = dir.appendingPathComponent("\(name) (\(n))").appendingPathExtension(ext)
        n += 1
    }
    return out
}

private struct Job {
    let ffmpeg: String
    let format: Format
    let audioToolbox: Bool
    var ok = 0, failed = 0

    /// Converts `src` into `dir`, named after `src` with the new extension.
    mutating func convert(_ src: URL, into dir: URL) -> Bool {
        let out = uniqueURL(dir, src.deletingPathExtension().lastPathComponent, format.ext)
        let status = run(ffmpeg, ["-nostdin", "-v", "error", "-i", src.path, "-map_metadata", "0"]
                         + format.args(audioToolbox: audioToolbox) + [out.path])
        if status == 0 { ok += 1; return true }
        failed += 1
        try? FileManager.default.removeItem(at: out)
        return false
    }

    /// Mirrors `dir` into `dest`, converting audio files and copying everything else.
    mutating func mirror(_ dir: URL, to dest: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: dest, withIntermediateDirectories: true)
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey]
        for item in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys)) ?? [] {
            if item.lastPathComponent == ".DS_Store" { continue }
            let v = try? item.resourceValues(forKeys: Set(keys))
            let plain = v?.isSymbolicLink != true && v?.isPackage != true
            if plain, v?.isDirectory == true {
                mirror(item, to: dest.appendingPathComponent(item.lastPathComponent))
            } else if plain, isAudioFile(item), format.applies(to: item) {
                // On failure, keep the original so the copy stays complete.
                if !convert(item, into: dest) { try? fm.copyItem(at: item, to: dest.appendingPathComponent(item.lastPathComponent)) }
            } else {
                try? fm.copyItem(at: item, to: dest.appendingPathComponent(item.lastPathComponent))
            }
        }
    }
}

/// Converts files next to the originals, and folders into a sibling copy named "<folder> (<FORMAT>)".
func convert(files: [String], folders: [String], to format: Format) {
    guard let ffmpeg = findFFmpeg() else {
        run("/usr/bin/osascript", ["-e", "display alert \"ffmpeg not found\" message \"Install it with: brew install ffmpeg, or set its path in iConvert Settings.\""])
        return
    }
    var job = Job(ffmpeg: ffmpeg, format: format, audioToolbox: hasEncoder("aac_at", ffmpeg: ffmpeg))
    for path in files {
        let src = URL(fileURLWithPath: path)
        guard isAudioFile(src), format.applies(to: src) else { continue }
        _ = job.convert(src, into: src.deletingLastPathComponent())
    }
    for path in folders {
        let src = URL(fileURLWithPath: path)
        let parent = src.deletingLastPathComponent()
        let name = "\(src.lastPathComponent) (\(format.label))"
        var dest = parent.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = parent.appendingPathComponent("\(name) \(n)")
            n += 1
        }
        job.mirror(src, to: dest)
    }
    notify("\(job.ok) converted, \(job.failed) failed")
}
