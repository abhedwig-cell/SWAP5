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

The current O2 cut after day 188 reproduces all three ledgers
of the continuous run for days 1–188. A fresh process using that
checkpoint reproduces the water, crop and conductive ledgers for
days 189–190 exactly.

### Current 1827-day result

The uninterrupted O2 registered thermal-profile run completed
all 1827 days with 1,819,203 accepted steps. A fresh process from
the day-1791 checkpoint captured during that run reproduced the
three ledgers for days 1792–1827 and the terminal checkpoint,
nodal state and endpoint byte for byte. The builds retain the
same production source and five original input files. All 202
repository source inputs per build were checked against
`a8275101`. The generated input helper is recorded separately
in the build manifests.

| Current full run | Value |
| --- | ---: |
| Maximum daily water residual | 4.594e-14 cm |
| Cumulative water stock–flux residual | -6.661e-15 cm |
| Maximum uptake attribution residual | 8.539e-16 cm |
| Maximum daily conductive residual | 2.179e-10 J/cm² |
| Maximum conductive substep residual | 3.616e-12 J/cm² |
| Signed sum of daily conductive residuals | -8.759e-9 J/cm² |

The [raw evidence archive](grass-1827-current-evidence.zip) includes
the build manifests, original inputs, accepted ledgers and checkpoints.
Its SHA-256 is `e79711fdac866bd1fe4c68b6daf2588b41353e7c3b4e85405559c35f06f6636c`. Re-auditing the extracted data produces
the published JSON receipt exactly. To repeat the late restart
without the retained day-1791 file, run the same build from day 1
to 1791 in a separate directory, use its checkpoint as the origin,
and record its day and SHA-256 in `ORIGIN.json`.

```powershell
$b = "$env:TEMP/s5-grass-review-build-O2"
$s = "integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz"
python -B tools/solute/run_water.py --model NATIVE_GRASSGROWTH_WATER --grass-build $b --output "$b-late-resume" --days 1827 --restart "$b-late-origin/checkpoint.bin"
if ($LASTEXITCODE) { throw 'Terminal restart failed' }
python -B research/hybrid-water01/audit_grass_current.py "$env:TEMP" --full --late --sealed $s

# To verify the packaged results, use a fresh extraction directory.
python -B -m zipfile -e research/hybrid-water01/grass-1827-current-evidence.zip ./grass-review-evidence
python -B research/hybrid-water01/audit_grass_current.py ./grass-review-evidence --archived --full --late --sealed $s
```

## Day 188, 6 July 1980

Literal SWAP 4.3.1 B0 remains the historical reference. B1 is a distinct corrected reference and agrees with B0 oxygen loss for this day to approximately 4e-12 cm. The diagnostic water-only O2 comparison to B0 gives +0.011289036 cm uptake, combining +0.000712215 cm potential demand and 0.010576821 cm less oxygen loss. The registered thermal-profile full run gives +0.011301596 cm uptake and 0.010586032 cm less oxygen loss on day 188. Drought reduction is zero in both comparisons. Over the current full period, the largest absolute daily uptake difference is on day 188, while the largest oxygen difference is 0.010648529 cm on day 905.

| Accepted route | First oxygen reduction after midnight | Daily oxygen loss |
| --- | ---: | ---: |
| Literal B0 | 38.4 min | 0.016571046610 cm |
| B0 with 30-second step cap applied only on day 188 | 67.5 min | 0.006220881579 cm |
| Diagnostic SWAP5 O2, water-only numerical profile | 68.3 min | 0.005994225669 cm |
| Current SWAP5 O2, registered thermal profile | not sampled | 0.005985014698 cm |

On identical accepted soil profiles and B0 root and atmospheric forcing, exchanging the oxygen kernels changes the integrated loss by about 3e-9 cm. Both control routes apply 1.06 cm gross rainfall over 144 minutes. The two B0 cases begin with identical 113-node head, water content and temperature, and their cumulative downward top flux during the wet window agrees within 4e-9 cm. The diagnostic B0 cap removes 97.86% of the oxygen gap against the observed water-only profile with the original solver tolerances. Its same-state test and onset timings belong to that profile.

Classify the main gap as numerical sensitivity to the time grid. The remaining 0.000226656 cm relative to capped B0 in the water-only comparison is unresolved, and the historical daily mismatch stays visible. The evidence supports functional execution and restart for the stated scopes. Whole-trajectory scientific equivalence remains open, and the diagnosis does not warrant a production physics change.

The [accepted root trace](grass-oxygen188-evidence.json), [same-state comparison](grass-oxygen188-paired-evidence.json) and [hydraulic cap evidence](grass-wetting188-evidence.json) include source, binary and input hashes. Their recovery commands and retained bundle locations are pinned in the [research workpoint](https://github.com/abhedwig-cell/SWAP5/blob/1938d37db59bbf7257071cadb32837f404e8670a/research/hybrid-water01/README.md#swap5-functional-closure01-workpoint).


## Revalidation on the AHL portability successor

The public O2 launcher completed the original 1827-day project on
production candidate `a4da56a0c60105862fc3dc91b6101ff1c963cf84`
from PR #1626 using the registered thermal profile. The water, crop
and conductive ledgers, endpoint and state files are byte-identical
to the earlier canonical run. Both executions accepted 1,819,203
steps. All 202 repository build inputs were verified against the
candidate source. The generated input helper and original input
hashes are listed separately.

A fresh process from the atomic day-245 checkpoint reproduces
days 246-247. A separate fresh process from the live day-1792
checkpoint reproduces every ledger row for days 1793-1827 and
the terminal checkpoint, state and endpoint bytes. The same
water, uptake and conductive-balance assertions pass. The
maximum absolute daily water and conductive residuals are
4.594e-14 cm and 2.179e-10 J/cm2.

Use the existing O2 build and full-launch commands above with a
new output directory. Copy the published checkpoint at the selected
day and pass it as `--restart` to the same verified build. The
[successor receipt](grass-ahl-successor-receipt.json) contains the
exact captured day, build and data identities. The prior raw
archive remains tied to its original build. Recomputing the
comparison with the sealed B0 evidence reproduces the day-188
finding and all reported period maxima exactly.

The approximately 100-minute launcher observation is a performance
finding. The short waterfilm-reuse candidate is separate from these
functional results and comparable full-project runtime remains open.
