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

func convert(_ paths: [String], to format: Format) {
    guard let ffmpeg = findFFmpeg() else {
        run("/usr/bin/osascript", ["-e", "display alert \"ffmpeg not found\" message \"Install it with: brew install ffmpeg, or set its path in iConvert Settings.\""])
        return
    }
    let audioToolbox = hasEncoder("aac_at", ffmpeg: ffmpeg)
    var ok = 0, failed = 0
    for path in paths {
        let src = URL(fileURLWithPath: path)
        guard isAudioFile(src), format.applies(to: src) else { continue }
        let base = src.deletingPathExtension()
        var out = base.appendingPathExtension(format.ext)
        var n = 1
        while FileManager.default.fileExists(atPath: out.path) {
            out = URL(fileURLWithPath: "\(base.path) (\(n))").appendingPathExtension(format.ext)
            n += 1
        }
        let status = run(ffmpeg, ["-nostdin", "-v", "error", "-i", path, "-map_metadata", "0"]
                         + format.args(audioToolbox: audioToolbox) + [out.path])
        if status == 0 { ok += 1 } else { failed += 1; try? FileManager.default.removeItem(at: out) }
    }
    notify("\(ok) converted, \(failed) failed")
}
