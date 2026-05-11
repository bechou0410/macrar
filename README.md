# MacRAR

Free, open-source native macOS archive manager with Liquid Glass UI for macOS 15 Sequoia + macOS 26 Tahoe. Wraps the RAR/UnRAR CLI tools by RARLAB.

- **Status**: Phase 1–2 scaffolding (in progress)
- **License**: MIT (this app). RAR engine: © RARLAB, distributed separately under its own license.
- **Bundle ID**: `com.bechou.winrar`
- **Min macOS**: 15.0 (Sequoia)

## Features (planned)

- Extract any RAR/ZIP/7z/TAR/GZ/BZ2/ISO archive (via bundled `unrar`)
- Create RAR archives (requires user-installed `rar` CLI from RARLAB)
- Drag-and-drop, Quick Look preview, Finder file associations
- Multi-volume, password-protected, recovery-record support
- macOS 26 Tahoe Liquid Glass UI with graceful Sequoia fallback

## Install

Download the latest DMG from [Releases](https://github.com/bechou0410/macrar/releases/latest). Drag MacRAR.app to /Applications and run `Install.command` once (clears Gatekeeper quarantine).

Without `Install.command`: right-click MacRAR.app → Open → Open. One-time prompt.

For archive **creation** (extract works out-of-the-box), install the RAR CLI:

```bash
brew install rar
```

Or download from rarlab.com/download.htm.

## Build from source

```bash
brew install xcodegen create-dmg
make project          # generate Xcode project from project.yml
make build            # build Release
make sign             # ad-hoc sign
make dmg              # package DMG
```

## Why no Apple Developer ID?

This is a hobby/community project. Users see a one-time Gatekeeper prompt on first launch. Source is on GitHub for full transparency.

## Acknowledgments

- RAR/UnRAR by RARLAB (Alexander Roshal)
- Sparkle 2 for auto-update
- swift-subprocess (Apple)
