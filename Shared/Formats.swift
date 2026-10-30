import Foundation
import UniformTypeIdentifiers

// Destination formats, each at the highest quality its codec allows.
enum Format: String, CaseIterable {
    case mp3, wav, flac, aac, alac, aiff, opus

    var title: String {
        switch self {
        case .mp3: return "MP3"
        case .wav: return "WAV"
        case .flac: return "FLAC"
        case .aac: return "AAC (M4A)"
        case .alac: return "ALAC (M4A)"
        case .aiff: return "AIFF"
        case .opus: return "Opus"
        }
    }

    /// Short name used in converted folder names, e.g. "Album (WAV)".
    var label: String {
        switch self {
        case .aac: return "AAC"
        case .alac: return "ALAC"
        default: return title
        }
    }

    var ext: String {
        switch self {
        case .aac, .alac: return "m4a"
        default: return rawValue
        }
    }

    var quality: String {
        switch self {
        case .mp3: return "320 kbps CBR"
        case .wav, .aiff: return "24-bit PCM"
        case .flac: return "lossless, max compression"
        case .aac: return "320 kbps"
        case .alac: return "lossless"
        case .opus: return "256 kbps (max)"
        }
    }

    /// ffmpeg output arguments. Cover art is kept where the container supports it.
    func args(audioToolbox: Bool) -> [String] {
        let cover = ["-map", "0:v:disp:attached_pic?", "-c:v", "copy"]
        switch self {
        case .mp3: return ["-map", "0:a"] + cover + ["-c:a", "libmp3lame", "-b:a", "320k", "-id3v2_version", "3"]
        case .flac: return ["-map", "0:a"] + cover + ["-c:a", "flac", "-compression_level", "12"]
        case .aac: return ["-map", "0:a"] + cover + ["-c:a", audioToolbox ? "aac_at" : "aac", "-b:a", "320k"]
        case .alac: return ["-map", "0:a"] + cover + ["-c:a", "alac"]
        case .wav: return ["-map", "0:a", "-c:a", "pcm_s24le"]
        case .aiff: return ["-map", "0:a", "-c:a", "pcm_s24be"]
        case .opus: return ["-map", "0:a", "-c:a", "libopus", "-b:a", "256k"]
        }
    }

    /// Whether converting `url` to this format makes sense (not already that format).
    func applies(to url: URL) -> Bool {
        // AAC and ALAC share .m4a, so an .m4a source can still go to either.
        ext == "m4a" || url.pathExtension.lowercased() != ext
    }
}

private let extraAudioExtensions: Set<String> = [
    "mp3", "wav", "flac", "aac", "m4a", "ogg", "oga", "opus", "aif", "aiff", "aifc",
    "wma", "caf", "ac3", "amr", "ape", "wv", "mka", "m4b", "mp2", "au",
]

func isAudioFile(_ url: URL) -> Bool {
    let ext = url.pathExtension.lowercased()
    if extraAudioExtensions.contains(ext) { return true }
    return UTType(filenameExtension: ext)?.conforms(to: .audio) ?? false
}
