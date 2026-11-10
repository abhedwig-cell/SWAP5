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

A fresh O2 process using its own day-2 checkpoint reproduced the
continuous balance rows for days 3–4 and all five terminal files
(checkpoint, restart, endpoint, nodal state and temperature). The
[sealed pressure/film qualification](../../integration/dataqual15_hupsel/PRESSURE_FILM_CANONICAL_RECEIPT_20261105.json)
also records full Windows and POSIX O0/O2 runs, nine own-build restart
windows per build, and the existing invalid-input and restart controls.
Current-source O0 and year-boundary replay refreshes are separate
in-progress controls.

## Scientific decision

The matched pressure/film trajectory passed 36 of 37 frozen original
scientific criteria in the sealed evaluation. The remaining failure is
the day-584 oxygen reduction. The current run gives
`0.00334886148527 cm` versus `0.003593541147 cm` in SWAP 4.3.1.
The absolute difference is `0.000244679662 cm`, above the original
`5.37184e-7 cm` bound. The full application and restart evidence
support functional coverage. Scientific equivalence remains open.

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
$sealed = "integration/dataqual15_hupsel/PRESSURE_FILM_WINDOWS_O2_20261105.tar.xz"
python -B research/hybrid-water01/audit_hupsel_application_review.py $s $sealed
```

The [receipt](hupsel-1096-application-receipt.json) and [archived
runs](hupsel-1096-application-evidence.zip) retain executable and input
identities, actual output and the exact native checkpoint payloads.
The archive includes the build manifest. Its SHA-256 is
`372e7e4a2ace7ad66dee1971ee1b6bb43b4a90591a78a8c7ec0fd7051120b05f`.
Extract the archive and pass its directory as `$s` to audit the
stored results directly.
