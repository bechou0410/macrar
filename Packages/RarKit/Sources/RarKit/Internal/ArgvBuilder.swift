import Foundation

/// Translates a `RarCommand` into an argv array for `Process`.
/// Argv passing avoids shell parsing — passwords with spaces/special chars are safe.
enum ArgvBuilder {
    static func build(_ command: RarCommand) -> [String] {
        var argv: [String] = []

        // Action token (rar's first positional arg)
        switch command.action {
        case .extract(let keepPaths): argv.append(keepPaths ? "x" : "e")
        case .create:                 argv.append("a")
        case .test:                   argv.append("t")
        case .list(let technical):    argv.append(technical ? "lt" : "l")
        case .repair:                 argv.append("r")
        case .lock:                   argv.append("k")
        case .readComment:            argv.append("cw")
        case .writeComment(let f):    argv.append("c"); argv.append("-z\(f)")
        case .rename(let from, let to): argv.append("rn"); argv.append(from); argv.append(to)
        case .delete:                 argv.append("d")
        case .convertToSFX:           argv.append("s")
        case .removeSFX:              argv.append("s-")
        case .addRecoveryRecord(let p): argv.append("rr\(p)p")
        case .version:                break  // rar with no args prints banner
        }

        // Switches
        for sw in command.switches {
            argv.append(contentsOf: render(sw))
        }

        // Archive (skip for .version)
        if case .version = command.action {
            // none
        } else {
            argv.append(command.archive.path)
        }

        // Files / entries
        if case .delete(let entries) = command.action {
            argv.append(contentsOf: entries)
        } else {
            argv.append(contentsOf: command.files)
        }

        // For extract: append destination directory as last positional
        if case .extract = command.action, let cwd = command.workingDirectory {
            let p = cwd.path
            argv.append(p.hasSuffix("/") ? p : p + "/")
        }

        return argv
    }

    private static func render(_ sw: RarCommand.Switch) -> [String] {
        switch sw {
        case .assumeYes:                ["-y"]
        case .overwriteAll:             ["-o+"]
        case .overwriteNone:            ["-o-"]
        case .renameOld:                ["-or"]
        case .renameNew:                ["-oR"]
        case .password(let p):          ["-p\(p)"]
        case .passwordHeader(let p):    ["-hp\(p)"]
        case .include(let m):           ["-n\(m)"]
        case .exclude(let m):           ["-x\(m)"]
        case .recurse:                  ["-r"]
        case .noPaths:                  ["-ep"]
        case .stripBasePath:            ["-ep1"]
        case .recoveryRecord(let p):    ["-rr\(p)p"]
        case .volumeBytes(let b):       ["-v\(b)b"]
        case .sfxModule:                ["-sfx"]
        case .compression(let l):       ["-m\(max(0, min(5, l)))"]
        case .dictionarySize(let mb):   ["-md\(mb)m"]
        case .solid:                    ["-s"]
        case .threads(let n):           ["-mt\(max(1, min(32, n)))"]
        case .silent:                   ["-inul"]
        case .suppressCopyrightBanner:  ["-idq"]
        case .raw(let s):               [s]
        }
    }
}
