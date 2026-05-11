# MacRAR

Free, open-source native macOS archive manager with Liquid Glass UI for macOS 15 Sequoia + macOS 26 Tahoe.

> **Developed with [Claude](https://www.anthropic.com/claude) (Anthropic AI).** Independent project — not affiliated with RARLAB, win.rar GmbH, or any other party.

- **License**: MIT (this app). RAR/UnRAR engine: © RARLAB / Alexander Roshal, distributed under their own license.
- **Bundle ID**: `com.bechou.winrar`
- **Min macOS**: 15.0 (Sequoia)

## Features

- Extract RAR / ZIP / 7z / TAR / GZ / BZ2 / ISO archives (via bundled `unrar` + system tools)
- Create RAR archives (requires user-installed `rar` CLI; built-in auto-installer fetches it from RARLAB on opt-in)
- Finder right-click Services: **Compress with MacRAR…** / **Extract with MacRAR**
- Quick Look preview for archive contents
- Liquid Glass UI on macOS 26 Tahoe; graceful material fallback on macOS 15 Sequoia
- Universal binary (Apple Silicon + Intel)
- Drag-and-drop both directions, multi-volume archives, password / header encryption, SFX, recovery records, comments, repair, lock, rename / delete entries

## Install

Download the latest DMG from [Releases](https://github.com/bechou0410/macrar/releases/latest). Drag **MacRAR.app** → **Applications**.

**First launch only**: right-click MacRAR.app → **Open** → **Open** (one-time Gatekeeper bypass — MacRAR uses ad-hoc signing, no paid Apple Developer ID).

After first launch the app self-configures: file associations, right-click Services menu, quarantine cleanup.

For archive **creation** (extract works out-of-the-box), install the RAR CLI:

```bash
brew install rar
```

Or use the built-in installer: **MacRAR → Settings → RAR CLI → Download & Install from RARLAB**. Or download manually from [rarlab.com/download.htm](https://www.rarlab.com/download.htm).

## Build from source

```bash
brew install xcodegen create-dmg
make project          # generate Xcode project from project.yml
make build            # build Release
make sign             # ad-hoc sign + auto-install /Applications + register Services
make dmg              # package signed .app into DMG
```

## Disclaimer & third-party notices

**MacRAR is an independent open-source project** developed with the assistance of Claude (Anthropic AI). It is **NOT affiliated with, endorsed by, or sponsored by** RARLAB, win.rar GmbH, Alexander Roshal, Anthropic, or any other party.

"RAR", "WinRAR", and related marks are trademarks of **win.rar GmbH**. The RAR compression algorithm and the `rar` / `unrar` binaries are proprietary software © RARLAB / Alexander Roshal — distributed under their own license. MacRAR merely provides a graphical user interface that invokes those tools.

The bundled `unrar` binary is redistributed under the UnRAR component exception of RARLAB's EULA. The `rar` binary is **NOT bundled**; users obtain it directly from RARLAB at their own discretion (manual download or via the in-app installer that fetches the unmodified package from rarlab.com).

**THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.** The authors and contributors of MacRAR shall not be liable for any data loss, archive corruption, license-key misuse, or any other damages arising from the use of this software, the bundled UnRAR, or any third-party RAR CLI invoked by it.

You are solely responsible for complying with the licensing terms of any third-party software you use through MacRAR — including the RAR/UnRAR license agreement with RARLAB. Source code is available on GitHub for full transparency.

## Acknowledgments

- **Claude** (Anthropic) — pair-programming partner for the entire stack
- **RAR / UnRAR** by RARLAB (Alexander Roshal) — the underlying engine
- **Sparkle 2** — macOS auto-update framework (MIT)
- **swift-subprocess** (Apple) — async process spawning

## Why no Apple Developer ID?

This is a hobby/community project. Users see a one-time Gatekeeper prompt on first launch. Source is on GitHub for full transparency.
