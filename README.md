# FitGirl RAM Limiter

by **2extrapickles**

Adds a 2 / 4 / 8 GB RAM limit to FitGirl repack installers. It's mainly for older repacks that don't have the
"Limit installer to 2 GB of RAM usage" checkbox, or whose setup fails while unpacking
(ISDone.dll / unarc.dll errors).

Tested with: Fallout: New Vegas (an older FitGirl repack without the checkbox) on a 64 GB PC, where the normal
setup failed and a limited run installed fine.

## Usage

1. Download the repo (**Code → Download ZIP**, or from Releases), then copy `fitgirl-ram-limiter.bat` and
   `fitgirl-ram-limiter.ps1` into the repack folder, next to `setup.exe`.
2. Double-click `fitgirl-ram-limiter.bat`.
3. Pick a limit (2, 4 or 8 GB, or 0 for no limit) and accept the admin prompt.
4. Install as usual. **Keep the limiter window open** until setup closes.

The window lists the compressors it found and what it changed. For example:

```
Compressor sections: Srep, Precomp, lolzi
  [Srep] Memory: 80%-1152m -> 512m
```

Command line options: `fitgirl-ram-limiter.bat -Limit 4 -Setup "D:\Some Repack\setup.exe"`

## How it works

FitGirl installers are Inno Setup installers that unpack with a chain of decompressors (srep, lolz, precomp,
xtool, etc.). These are run through the CLS plugin system. When setup starts, it extracts its tools to a temp folder,
`%TEMP%\is-XXXXX.tmp\`. One of those files is `CLS.ini`, which tells each decompressor how much memory it may use.

FitGirl's own "Limit to 2 GB" checkbox only rewrites a few values in that `CLS.ini` before unpacking
starts. This tool does the same thing from outside the installer:

1. Starts `setup.exe` (as admin, because the installer runs as admin).
2. Watches `%TEMP%` for the installer's new `is-*.tmp\CLS.ini`.
3. Lowers the memory settings it recognises, and keeps them lowered until setup exits.

| Setting in CLS.ini | 2 GB | 4 GB | 8 GB |
|---|---|---|---|
| `[Srep] Memory` | 512m | 2048m | 5120m |
| `[Precomp] Memory` (MB) | 128 | 256 | 512 |
| `MaxMemoryUsage` / `ldmfMaxMemoryUsage` in any section | 1024m | 2048m | 4096m |

Values that are already at or below the limit are left alone, and setup.exe itself is never modified. Srep
switches to a temp file on disk for whatever doesn't fit in RAM, so a lower limit means a slower install, not a
broken one.

The 2 GB values match what FitGirl's own 2 GB checkbox writes.

### Why limiting helps on PCs with lots of RAM

Defaults like `Memory=80%-1152m` scale with your RAM. On a 64 GB PC that tells srep to grab about 50 GB in one
allocation. With other programs open, or a small page file, that allocation can fail and the
install dies partway through.

## Does it work with every FitGirl setup?

It works with any setup that uses `CLS.ini`, which is nearly all FitGirl repacks. Whether it actually
*reduces* memory depends on the compressors that repack uses. The tool checks this at runtime and tells you:

- **Changes are listed:** the limit is active.
- **"No memory settings the limiter can change":** this repack's decompressors (for example older lolz
  builds) have no memory option in `CLS.ini`, so the limiter can't do anything for it.
- **"No CLS.ini was found":** the setup doesn't use the CLS system (not a FitGirl/ISDone-style installer),
  and nothing was changed.

Newer repacks already have the built-in checkbox. You can use either one. If both are used, the lower value
wins.

## Troubleshooting

- **Still fails at 2 GB:** the cause is probably not RAM. Run `Verify BIN files before installation.bat` to
  check for a corrupted download, and make sure there's plenty of free disk space on the install drive and on
  `C:` (for temp files).
- **"setup.exe not found":** the tool must be in the same folder as `setup.exe`, or pass `-Setup`.
- **Nothing happens after the admin prompt:** your antivirus may be blocking PowerShell. Allow
  `fitgirl-ram-limiter.ps1` or run it from an admin PowerShell:
  `powershell -ExecutionPolicy Bypass -File .\fitgirl-ram-limiter.ps1`

## Disclaimer

This is an unofficial community tool. It is not made by or affiliated with FitGirl Repacks. It only edits the
installer's temporary decompressor config and never modifies `setup.exe` or the game files. Use at your own
risk.

## License

[MIT](LICENSE) © 2026 2extrapickles
