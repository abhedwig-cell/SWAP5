# Grassgrowth 1827-day execution and day-188 assessment

This review starts from research workpoint `1938d37db59bbf7257071cadb32837f404e8670a` and targets canonical `a8275101d91f0ab5b413290e9b00bb5666b11917` (the committed-LAI reporting fix in PR #1622). It adds verification and a scientific assessment. The canonical model, restart format and numerical tolerances are unchanged.

## Full original execution and restart evidence

The sealed [union capsule](../../integration/dataqual15/GRASS_UNION_FULL_MANIFEST.json) was verified at its admission commit `7faeaf1ef`. It binds the actual scientific sources, native executable, reference executables and original inputs. On that source, O2 completed days 1–1827 and O0 matched O2 exactly over days 1–367. Independent fresh-process restarts were exact at O2 126→140, 365→367, 918→922, 1786→1827 and 1800→1827, and at O0 365→367. Eleven invalid restart controls per optimization passed.

| Sealed O2 evidence | Value |
| --- | ---: |
| Maximum absolute daily water residual | 4.711e-14 cm |
| Cumulative stock–flux residual | 8.124e-15 cm |
| Maximum heat accounting residual | 3.169e-12 J/cm² |

Use the capsule verifier at the admission commit. It checks the source trees and deliberately rejects a later production tree.

```powershell
git worktree add --detach ./grass-capsule-review 7faeaf1ef
Push-Location ./grass-capsule-review
python -B tests/dataqual15/verify_grass_full_evidence.py --spec integration/dataqual15/GRASS_UNION_FULL_SPEC.json
Pop-Location
```

The separate reproduction on current canonical uses the original 113-node project and the registered `thermal-control-1e-5C` profile. The water and root uptake attribution gates remain `1e-10 cm`. The conductive ledger covers soil conduction. Full surface energy and cross-build binary checkpoint compatibility are outside this evidence.

```powershell
foreach ($opt in 'O0','O2') {
    $b = "$env:TEMP/s5-grass-review-build-$opt"
    python -B tools/solute/build_grass_startup.py --output $b --optimization $opt --policy retained --numerical-profile thermal-control-1e-5C
    if ($LASTEXITCODE) { throw "Build failed for $opt" }
    $common = @('--model','NATIVE_GRASSGROWTH_WATER','--grass-build',$b)
    if ($opt -eq 'O2') {
        python -B tools/solute/run_water.py @common --output "$b-full" --days 1827
        if ($LASTEXITCODE) { throw 'Full run failed' }
        python -B tools/solute/run_water.py @common --output "$b-cut188" --days 188
        if ($LASTEXITCODE) { throw 'Cut failed' }
        python -B tools/solute/run_water.py @common --output "$b-resume190" --days 190 --restart "$b-cut188/checkpoint.bin"
    } else {
        foreach ($day in 1,3) {
            python -B tools/solute/run_water.py @common --output "$b-control$day" --days $day
            if ($LASTEXITCODE) { throw "Control failed for day $day" }
        }
        python -B tools/solute/run_water.py @common --output "$b-resume3" --days 3 --restart "$b-control1/checkpoint.bin"
    }
    if ($LASTEXITCODE) { throw "Restart failed for $opt" }
}
```

### Current canonical regression

Cold Windows GNU Fortran O0 and O2 builds on `a8275101` produce
byte-identical water, crop and conductive ledgers for days 1–3.
The physical endpoint and nodal state files also match. For each
optimization, a separate process resumed from its own day-1 file
and reproduced days 2–3 and the day-3 checkpoint, endpoint and
state exactly. The maximum daily water residual is 2.257e-14 cm
and the maximum daily conductive residual is 1.316e-10 J/cm².
The [current receipt](grass-current-review-evidence.json) pins
the source baseline, build, inputs and output files.

The current-source 1827-day O2 replay and the separate day-188
cut/continuation were started. They are follow-up validation and
are not counted in this receipt. The completed full-period and
long-restart evidence above applies to the sealed predecessor.

```powershell
python -B research/hybrid-water01/audit_grass_current.py "$env:TEMP"
# Add --full after the current O2 full run and day-188 continuation finish.
```

## Day 188, 6 July 1980

Literal SWAP 4.3.1 B0 remains the historical reference. B1 is a distinct corrected reference and agrees with B0 oxygen loss for this day to approximately 4e-12 cm. The original daily SWAP5 minus B0 difference is +0.011289036 cm uptake, combining +0.000712215 cm potential demand and 0.010576821 cm less oxygen loss. Drought reduction is zero in both runs.

| Accepted route | First oxygen reduction after midnight | Daily oxygen loss |
| --- | ---: | ---: |
| Literal B0 | 38.4 min | 0.016571046610 cm |
| B0 with 30-second step cap applied only on day 188 | 67.5 min | 0.006220881579 cm |
| Registered SWAP5 O2 | 68.3 min | 0.005994225669 cm |

On identical accepted soil profiles and B0 root and atmospheric forcing, exchanging the oxygen kernels changes the integrated loss by about 3e-9 cm. Both control routes apply 1.06 cm gross rainfall over 144 minutes. The two B0 cases begin with identical 113-node head, water content and temperature, and their cumulative downward top flux during the wet window agrees within 4e-9 cm. The diagnostic B0 cap removes 97.86% of the original daily oxygen gap with the original solver tolerances.

Classify the main gap as numerical sensitivity to the time grid. The remaining 0.000226656 cm relative to capped B0 is unresolved, and the historical daily mismatch stays visible. The evidence supports functional execution and restart for the stated scopes. Whole-trajectory scientific equivalence remains open, and the diagnosis does not warrant a production physics change.

The [accepted root trace](grass-oxygen188-evidence.json), [same-state comparison](grass-oxygen188-paired-evidence.json) and [hydraulic cap evidence](grass-wetting188-evidence.json) include source, binary and input hashes. Their recovery commands and retained bundle locations are pinned in the [research workpoint](https://github.com/abhedwig-cell/SWAP5/blob/1938d37db59bbf7257071cadb32837f404e8670a/research/hybrid-water01/README.md#swap5-functional-closure01-workpoint).
