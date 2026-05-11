MacRAR — Free, open-source RAR archiver for macOS
==================================================

INSTALL (1 step)
----------------
Drag MacRAR.app into the Applications folder.

That's it. MacRAR self-configures on first launch — file associations,
Finder right-click Services menu, and Gatekeeper quarantine cleanup all
happen automatically.

FIRST LAUNCH
------------
Because MacRAR uses ad-hoc code signing instead of a paid Apple Developer
ID, macOS shows ONE warning the first time you launch:

  "MacRAR.app can't be opened because Apple cannot check it for
   malicious software."

Workaround (one-time, only on the very first launch):
  Right-click MacRAR.app in Applications → Open → Open again.

After that single confirmation, you can launch normally from Spotlight,
the Dock, or by double-clicking archive files.

FINDER RIGHT-CLICK MENU
-----------------------
After first launch, right-click any file or folder in Finder → Services:
  • Compress with MacRAR…
  • Extract with MacRAR

If the Services entries don't appear immediately, log out + back in once,
or open MacRAR → Settings → RAR CLI → "Repair Finder Integration".

CREATING ARCHIVES
-----------------
MacRAR extracts every supported format out of the box. To CREATE new
.rar archives you also need the proprietary RAR CLI from RARLAB:

  brew install rar

or download from https://www.rarlab.com/download.htm

Or use the built-in installer: MacRAR → Settings → RAR CLI →
"Download & Install from RARLAB".

The RAR CLI is © RARLAB and licensed separately.

LICENSE
-------
MacRAR is MIT-licensed. See LICENSE.txt inside the app bundle's Resources.
Source: https://github.com/bechou0410/macrar
