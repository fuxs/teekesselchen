# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Teekesselchen is an Adobe Lightroom Classic plugin (Lua, Lightroom SDK) that finds duplicate photos by comparing metadata. There is no test suite or linter; verification means loading the plugin into Lightroom Classic (File > Plug-In Manager, add the built `.lrplugin` folder) and running Library > Plug-in Extras > Find Duplicates.

## Build commands

- `make build` — copies `src/` plus the bundled ExifTool from `3rd/exiftool/` into `teekesselchen.lrplugin/` (the folder you load into Lightroom).
- `make distribution` — runs build, then zips it to `dist/teekesselchen.zip` and writes a SHA-256 checksum.
- `make lint` — runs [selene](https://kampfkarren.github.io/selene/) on `src/` (config: `selene.toml` + `lightroom.yml`, which declares the Lightroom SDK globals `import`, `LOC`, `_PLUGIN`, `WIN_ENV`, `MAC_ENV`).
- `make fmt` / `make fmt-check` — formats `src/` with StyLua (config: `stylua.toml`; tabs, Lua 5.1 syntax).

Only `src/`, `Makefile`, `build.xml`, and `README.md` are tracked in git; `teekesselchen.lrplugin/`, `build/`, `dist/`, `3rd/`, `doc/`, `mac/`, and `creatives/` are gitignored. **Edit code in `src/`, never in `teekesselchen.lrplugin/`** — that folder is a build output. `build.xml` (Ant) is the legacy build; the Makefile replaced it and installers are no longer supported.

## Architecture

All source lives flat in `src/`. Lightroom SDK namespaces are loaded with `import` (e.g. `import "LrApplication"`); the plugin's own modules are plain global tables loaded with `require` (`Util`, `Configuration`, `Updater`, `Teekesselchen`).

Flow:
- `Info.lua` — plugin manifest: SDK versions, toolkit id, the menu item pointing at `TeekesselchenDialog.lua`, and the plugin `VERSION`.
- `PluginInit.lua` — runs at plugin load. Sets the globals used everywhere: `_G.configuration` (a `Configuration` instance), `_G.logger` (LrLogger "teekesselchen"), and `_G.CURRENT_VERSION`. Also kicks off the async update check (`Updater.lua` fetches version info over HTTP).
- `Configuration.lua` — wraps `LrPrefs.prefsForPlugin()`. `defaultSettings` there is the canonical list of every setting; new settings must be added to that table (missing keys fall back to defaults on load).
- `TeekesselchenDialog.lua` — the whole settings UI, built with `LrView` bindings against a property table populated from `configuration.settings` via `copyTo`/`copyFrom`.
- `Teekesselchen.lua` — the duplicate-finding engine (see below).
- `Util.lua` — string helpers plus `getExifToolCmd` (invokes the ExifTool binary bundled at the plugin root; `WIN_ENV` selects `exiftool.exe` vs `exiftool`).

### The duplicate-finding engine (Teekesselchen.lua)

`findDuplicates(settings)` builds a chain of comparator closures in reverse order, then runs each photo through the chain inside one `catalog:withWriteAccessDo`:

- Each enabled criterion (capture date, camera make/model/serial, lens, ISO, shutter speed, aperture, GPS, file name/size/type, optional ExifTool output) wraps the chain via `comperatorEnv(name, next, mandatory)`. Comparators partition photos into a nested tree keyed by the formatted metadata value; only photos identical on every enabled key reach the innermost function.
- The innermost function, from `markDuplicateEnv`, marks duplicates: adds the configured keyword (default "Duplicate"), optionally sets the reject flag (`pickStatus`) and color labels (`TK#_<n>_keep` / `TK#_<n>_x`), and orders each duplicate group so the "best" photo stays first.
- Ordering within a group is decided by the `prefer*` functions (RAW, DNG, HEIC, larger file, larger dimensions, higher rating, short/long name/path). Their priority comes from the `prefer*Pos` settings, assembled into `sortingArray`; each returns true once it has decided, so earlier rules win. Virtual copies are always preferred for rejection over originals.
- When `useExifTool` is on, `exifToolEnv` shells out to the bundled ExifTool once per photo in a group and uses its output as an extra tree key — this is the slow path.
- A duplicate group's tree node is `{labelNumber, photo1, photo2, ...}` — index 1 is the label counter, index 2 the current "keep" photo.

Results land in a "Duplicates" smart collection built on the keyword. Lightroom 3 lacks `pickStatus` support (`supportsFlag` guards all flag writes).

## Releasing a version

Version numbers live in three places that must stay in sync: `VERSION` in `src/Info.lua`, `_G.CURRENT_VERSION` in `src/PluginInit.lua`, and a new entry in `src/ReleaseNotes.txt`. The README links to the GitHub release tag.
