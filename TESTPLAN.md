# Lightroom Smoke Test Plan

Manual verification of the changes on branch `cleanup-tooling-and-bugfixes`,
to be run in a Lightroom Classic trial before releasing 1.9.1. Estimated
time: 1–2 hours.

## Preparation (no Lightroom needed)

- [ ] `./test/make_testset.sh` — generates `testset/` (16 synthetic photos;
      all pairs share camera EXIF, capture date separates the groups)
- [ ] `make test && make lint && make build` — all green, plugin folder fresh

## Setup

- [ ] Install Lightroom **Classic** (via Creative Cloud; not the cloud "Lightroom")
- [ ] Create a throwaway catalog: File > New Catalog
- [ ] Import all of `testset/` (Add, don't copy)
- [ ] File > Plug-In Manager > Add > select `teekesselchen.lrplugin/` — loads
      without errors

## 1. Menu entries (issue #16 fix — new, untested)

- [ ] Entry appears under **Library > Plug-in Extras > Find Duplicates**
- [ ] Entry ALSO appears under **File > Plug-in Extras > Find Duplicates**
- [ ] Both open the same dialog

## 2. Dialog sanity

- [ ] All four tabs render (Summary, Marks, Rules, About)
- [ ] Rules tab shows the new **"Ignore picked photos"** checkbox (Ignore box)
- [ ] Change a setting, click Save, reopen — setting persisted
- [ ] Position field validation: entering `-1` in a prefer-rule position
      shows an error (new: negatives rejected)
- [ ] About tab shows v1.9.0 and the license text

## 3. Default-rules scan

Select all photos, run Find Duplicates with default settings.

- [ ] Groups found: 0101+0102, 0201.jpg+0201.heic, 0301+0302, 0401+0402,
      0501+0502+0503 (burst — expected false positive, see step 8),
      0601+0602, 0701+0702
- [ ] `IMG_0801.jpg` (control) is NOT marked
- [ ] Keeper of 0201 pair is the **HEIC** (prefer HEIC rule)
- [ ] Keeper of 0601 pair is the **1200px** version (prefer dimension)
- [ ] Keepers are unflagged, losers flagged rejected; "Duplicates" smart
      collection contains all group members
- [ ] Result dialog shows a plausible elapsed time and duplicate count

## 4. File name rule — HEIC/JPG twins (review finding #1 fix)

Enable "File name" in the Rules tab, rerun.

- [ ] 0201.jpg + 0201.heic **still group** (extension stripped correctly;
      before the fix, 4-char extensions broke the match)

## 5. File size rule — raw bytes (PR #18 fix)

Disable "File name" again; enable "File size", rerun.

- [ ] 0301 + 0302 do **NOT** group anymore (114676 vs 114719 bytes — both
      display as "112 KB", the old formatted compare falsely matched them)
- [ ] 0101 + 0102 (byte-identical) still group

## 6. Format tie falls through to rating (PR #2 fix)

Disable "File size". In Lightroom, rate `IMG_0402.heic` ★★★★★, rerun.

- [ ] Keeper of the 0401/0402 pair is the **rated** `IMG_0402.heic`
      (both are HEIC; before the fix the format rule swallowed the tie and
      scan order decided)

## 7. Picked flag protection (issues #7/#8 fixes)

In Lightroom, flag `IMG_0701.jpg` as **picked** (P key). Rerun.

- [ ] The pair still groups; `IMG_0701.jpg` is the keeper and **keeps its
      picked flag** (before the fix it was silently unflagged)
- [ ] Now enable "Ignore picked photos", rerun:
- [ ] `IMG_0701.jpg` is skipped (skip counter +1); `IMG_0702.jpg` alone
      forms no group and is not marked

## 8. ExifTool option — burst photos (issue #6 documentation)

Enable "Use ExifTool" (default parameters `-SequenceNumber -SubSecTime
-SpecialMode`), enable Logging in the About tab, rerun.

- [ ] Burst photos 0501/0502/0503 are **no longer grouped** (subseconds and
      sequence numbers differ)
- [ ] Scan completes without errors; log file exists
      (`~/Documents/teekesselchen.log` or as documented)

## 9. Update check (bug fixes: version compare, response parsing)

- [ ] About tab > "Check now for updates" → "You are using the latest
      version." (server says 1.9 = local 1.9.0)
- [ ] Edit `teekesselchen.lrplugin/PluginInit.lua` (the BUILD folder, not
      src/): set `_G.CURRENT_VERSION = "1.8"`, reload plugin (Plug-In
      Manager > Reload) → update prompt appears, "Update" opens the browser
- [ ] Optional end-to-end proof of the old float bug: stage
      `currentVersion = 1.10` in update.php on bungenstock.de → prompt must
      still appear (old code failed here: 1.10 < 1.9 as floats)
- [ ] Restore `CURRENT_VERSION = "1.9.0"` (or run `make build`)

## 10. Regression sweep (optional)

- [ ] Cancel a running scan mid-way — no errors, partial marks consistent
- [ ] "Clean up before start" + "Reset rejected flag": rerun clears previous
      flags/keyword from the smart collection first
- [ ] Labels mode ("Abuse color labels"): keep/x labels assigned per group

## After all boxes are checked

1. `make distribution`, tag `1.9.1`, create the GitHub release with
   `dist/teekesselchen.zip` + checksum
2. Verify the **released** zip installs cleanly in Lightroom
3. Update `update.php` (`currentVersion = 1.9.1`) and the website download
   links; verify the in-app update prompt fires for a 1.9.0 install
4. Post the held issue comments and close #1, #6, #7, #8, #9, #16 and
   PRs #2, #18
