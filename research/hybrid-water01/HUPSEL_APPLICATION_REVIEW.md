# Hupsel 1096-day application review

This evidence-only change reviews the public Hupsel rotation route
on production source `a8275101d91f0ab5b413290e9b00bb5666b11917`.
It keeps the registered pressure/film numerical profile and existing
model tolerances.

## Functional evidence

A fresh GNU Fortran O2 run reached day 1096 with the original physical
inputs. All six published physical CSV files match the sealed Windows
O2 **pressure/film** run byte for byte. The older profile-schedule
capsule used a different numerical route. Its trajectory first differs
at day 524 and is a separate comparator. The current checkpoint envelope
has a different hash from the sealed pressure/film checkpoint. Exact
restart is checked within the current executable and input binding.

| Full-run check | Result |
| --- | ---: |
| Model days / accepted output intervals | 1096 / 1097 |
| Maximum independent water residual | 4.443668e-14 cm |
| Cumulative independent water residual | 8.526513e-14 cm |
| Maximum independent solute residual | 9.627043e-12 mg/cm² |
| Cumulative independent solute residual | -5.077539e-11 mg/cm² |
| Maximum reported heat residual | 1.304932e-12 J/cm² |

Fresh current-source O0 and O2 processes using their own day-2
checkpoints reproduced the continuous balance rows for days 3–4
and all five terminal files (checkpoint, restart, endpoint, nodal
state and temperature). The O0 cold control also reproduces the
O2 full-run physical budget through day 4. The current O2 year
restart from day 365 exactly matches the continuous physical
budget for days 366–367. Window counters are process-local.
The [sealed pressure/film qualification](../../integration/dataqual15_hupsel/PRESSURE_FILM_CANONICAL_RECEIPT_20261105.json)
also records full Windows and POSIX O0/O2 runs, nine own-build restart
windows per build, and the existing invalid-input and restart controls.

## Scientific decision

The matched pressure/film trajectory passed 36 of 37 frozen original
scientific criteria in the sealed evaluation. The remaining failure is
the day-584 oxygen reduction. The current run gives
`0.00334886148527 cm` versus `0.003593541147 cm` in SWAP 4.3.1.
The absolute difference is `0.000244679662 cm`, above the original
`5.37184e-7 cm` bound. The full application and restart evidence
support functional coverage. Scientific equivalence remains open.

### Day-584 reference qualification

The two reference families both fail to resolve day 584 at the
frozen `5.371840000016327e-7 cm` limit.

| Reference family | Two finest audited oxygen results (cm) | Absolute change (cm) | Multiple of limit |
| --- | --- | ---: | ---: |
| Original SWAP 4.3.1 with strict balance input controls | 0.003387732492 and 0.003362967866 | 2.4764626e-5 | 46.1 |
| Research-only implicit conductivity reference with strict balance input controls | 0.003338923548 and 0.003333997436 | 4.926112e-6 | 9.17 |

The original grid verifier reproduced its retained results. The
implicit-family verifier reproduced its source-bound screen from
its admission checkout `eef0c31e`. All 38 members of the implicit
archive were also checked against the manifest, and the largest
oxygen change across the two finest stored prefixes occurs on
2003-08-07, day 584. The source-bound verifier declines current-tree
reuse because inherited dependencies have changed. Its unchanged
historical checkout remains the verification authority.

The existing composed SWAP5 temporal controls at DTMAX 0.005
and 0.0025 days moved the day-584 integral by at most 6.551e-8 cm
relative to the 0.01-day parent. The existing same-state tests
also passed the original oxygen factor and final uptake partition
checks on their selected states. Together these findings leave
the original comparison failed and reference-limited. They do not
identify a specific native process defect.

The next scientific criterion requires independent reference
accuracy at the existing bound with original forcing and genuine
variant-owned histories. Neither reference family qualifies as
a replacement for the original comparison. A closer result or
a smaller successive change is insufficient to select a new oracle.
No native adjustment follows from the evidence.

- [Original grid receipt](../../integration/dataqual15_hupsel/ORIGINAL_OXYGEN_GRID_CANONICAL_RECEIPT_20261104.json)
- [Implicit reference receipt](../../integration/dataqual15_hupsel/IMPLICIT_REFERENCE_CANONICAL_RECEIPT_20261105.json)
- [Composed temporal controls](../../docs/science/HUPSEL_COMPOSED_TEMPORAL.md)
- [Composed same-state controls](../../docs/science/HUPSEL_COMPOSED_OXYGEN.md)

To reproduce the two reference audits from a full repository checkout:

```powershell
python -B tests/dataqual15_hupsel/original_oxygen_grid_evidence.py
if ($LASTEXITCODE) { throw 'Original grid audit failed' }
git worktree add --detach ./hupsel-implicit-reference-review eef0c31e22346324ff85e2bf7483d4527dd14878
if ($LASTEXITCODE) { throw 'Implicit reference checkout failed' }
Push-Location ./hupsel-implicit-reference-review
python -B tests/dataqual15_hupsel/implicit_reference_evidence.py
$implicitResult = $LASTEXITCODE
Pop-Location
if ($implicitResult) { throw 'Implicit reference audit failed' }
```

## Reproduce

Build with GNU Fortran on PATH. Use new directories for every run.

```powershell
$b = "./hupsel-build"
$fc = (Get-Command gfortran).Source
python -B tests/dataqual15_hupsel/build_and_run.py --compiler $fc --output $b --optimization O2
if ($LASTEXITCODE) { throw 'Build failed' }
$common = @('--model','NATIVE_HUPSEL_ROTATION','--hupsel-build',$b)
$s = "./hupsel-review-runs"
python -B tools/solute/run_water.py @common --output "$s/full" --days 1096
if ($LASTEXITCODE) { throw 'Full run failed' }
foreach ($n in 2,4) {
    python -B tools/solute/run_water.py @common --output "$s/control$n" --days $n
    if ($LASTEXITCODE) { throw "Control failed on day $n" }
}
python -B tools/solute/run_water.py @common --output "$s/resume4" --days 4 --restart "$s/control2/checkpoint.bin"
if ($LASTEXITCODE) { throw 'Restart failed' }
python -B tools/solute/run_water.py @common --output "$s/cut365" --days 365
if ($LASTEXITCODE) { throw 'Year cut failed' }
python -B tools/solute/run_water.py @common --output "$s/resume367" --days 367 --restart "$s/cut365/checkpoint.bin"
if ($LASTEXITCODE) { throw 'Year restart failed' }
python -B tests/dataqual15_hupsel/build_and_run.py --compiler $fc --output "$b-O0" --optimization O0
if ($LASTEXITCODE) { throw 'O0 build failed' }
$commonO0 = @('--model','NATIVE_HUPSEL_ROTATION','--hupsel-build',"$b-O0")
foreach ($n in 2,4) {
    python -B tools/solute/run_water.py @commonO0 --output "$s/O0-control$n" --days $n
    if ($LASTEXITCODE) { throw "O0 control failed on day $n" }
}
python -B tools/solute/run_water.py @commonO0 --output "$s/O0-resume4" --days 4 --restart "$s/O0-control2/checkpoint.bin"
if ($LASTEXITCODE) { throw 'O0 restart failed' }
$sealed = "integration/dataqual15_hupsel/PRESSURE_FILM_WINDOWS_O2_20261105.tar.xz"
python -B research/hybrid-water01/audit_hupsel_application_review.py $s $sealed --year --o0
```

The [receipt](hupsel-1096-application-receipt.json) and [archived
runs](hupsel-1096-application-evidence.zip) retain executable and input
identities, actual output and the exact native checkpoint payloads.
The archive includes the build manifest. Its SHA-256 is
`efead5ee838e54a276de8fbd774b288dbcc9c6044ae83905405cb3f48125b093`.
Extract the archive and pass its directory as `$s` to audit the
stored results directly.


## Revalidation on the AHL portability successor

The unchanged commands above were repeated on the production source of
PR #1626 at `a4da56a0c60105862fc3dc91b6101ff1c963cf84`. The new O2 run
completed all 1096 days. The six physical CSV files are byte-identical
to the earlier canonical application run. The independent maximum
water and solute interval residuals are 4.444e-14 cm and
9.627e-12 mg/cm2. The maximum reported heat residual is
1.305e-12 J/cm2.

Each optimization reproduces its own day-2 restart through day 4,
including the terminal checkpoint, restart, endpoint, state and
temperature files. The O2 day-365 checkpoint reproduces the full
run's physical budget for days 366-367. The
[successor receipt](hupsel-ahl-successor-receipt.json) binds both
builds, the original inputs and the current output hashes.

Day-584 oxygen reduction remains 0.0033488614852679407 cm, exactly
the previous current result. The failed frozen-reference comparison
and the independent reference-resolution blockers retain their
earlier classification.
