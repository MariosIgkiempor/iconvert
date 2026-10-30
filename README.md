# iConvert

Right-click audio files in Finder and choose **Convert to** → MP3, WAV, FLAC, AAC, ALAC, AIFF or Opus. Always the highest quality, using ffmpeg on your Mac.

## Install

1. Open **Terminal** (press `⌘ Space`, type "Terminal", press Enter).
2. Paste this and press Enter:

   ```sh
   curl -fsSL https://github.com/MariosIgkiempor/iconvert/releases/latest/download/install.sh | bash
   ```

3. Right-click any audio file in Finder → **Convert to**.

Requires macOS 13 or later and [ffmpeg](https://ffmpeg.org). The installer installs ffmpeg for you if you have [Homebrew](https://brew.sh); otherwise install Homebrew first, then run `brew install ffmpeg`.

The installer is [one short script](install.sh). It isn't notarized by Apple, which is why it's installed from Terminal instead of downloaded in a browser. That way macOS doesn't show a "can't be opened" warning.

## Use

- Select one or more audio files, right-click → **Convert to** → pick a format.
- The converted file is saved next to the original (existing files are never overwritten).
- Formats the file already has are greyed out.

| Format | Quality | Cover art kept |
|---|---|---|
| MP3 | 320 kbps CBR | yes |
| WAV | 24-bit PCM | no |
| FLAC | lossless, max compression | yes |
| AAC (M4A) | 320 kbps | yes |
| ALAC (M4A) | lossless | yes |
| AIFF | 24-bit PCM | no |
| Opus | 256 kbps (max) | no |

Open iConvert from `~/Applications` or its menu bar icon for settings (launch at login, Dock/menu bar icons, notifications, ffmpeg path).

## Troubleshooting

- **No "Convert to" in the right-click menu:** open System Settings → Login Items & Extensions → Finder (under Added Extensions) and turn on **iConvert**. Then run `killall Finder`.
- **"ffmpeg not found":** run `brew install ffmpeg`, or set the path in iConvert's settings.

## Uninstall

```sh
curl -fsSL https://github.com/MariosIgkiempor/iconvert/releases/latest/download/uninstall.sh | bash
```

## Build from source

Needs Xcode command line tools. `./dev-install.sh` builds and installs; `./build.sh` only builds `build/iConvert.app`.

## Release (maintainers)

```sh
git tag v1.0.0 && git push origin v1.0.0
```

GitHub Actions builds a universal (Apple silicon + Intel) app and publishes `iConvert.zip`, `install.sh` and `uninstall.sh` to the release.
