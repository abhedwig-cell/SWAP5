# Andelst 481-day application review

This review attaches execution evidence to the hybrid application already
integrated in PR #1620. It changes only research evidence. The verified
production checkout is `a8275101d91f0ab5b413290e9b00bb5666b11917`.

## Execution and restart

The public `HYBRID_ANDELST_WATER` launcher completed 481 days on the
original Andelst inputs with the O2 donor and kernel. The daily ledger
matches the retained hybrid run byte for byte. All 482 dated CSV rows
also match, including the initial row. The raw CSV header records run
metadata and is excluded from that cross-run comparison.

| Verified result | Value |
| --- | ---: |
| Accepted days | 481 |
| Maximum absolute independent daily water residual | 9.998895939e-7 cm |
| Existing daily acceptance tolerance | 1e-6 cm |
| Signed sum of independent daily residuals | -3.098485702e-5 cm |
| Fresh year-boundary continuation | 365 to 457 |
| Fresh dry-window continuation from the chained package | 453 to 459 |

The two continuations reproduce all overlapping physical ledger fields
and dated CSV rows. The host starts a new local revision sequence on
resume. The schema-3 packages contain both donor payloads and bind the
same numerical build and original inputs. Their payload hashes match
the retained proof. The archive and receipt preserve the current build
and original-input hashes. Separate Windows link operations can produce
different executable bytes and are identified individually.

The unchanged Andelst application dependencies preserve the [O0/O2
prefix and day-20 restart checks](https://github.com/abhedwig-cell/SWAP5/blob/3f10d53d4a37dc7a57c538103299934cf1938aa1/research/hybrid-water01/CLOSURE01_INTEGRATION_RESULT_20261109.json).
Those checks cover days 1–22 with an O2 donor. A fresh public
application run on the current Andelst dependency surface
reproduced the first 22 complete receipts and published a day-19
checkpoint with the same build binding as the full run.
With that checkpoint, two distinct Cauchy trajectories matched
their separate controls for days 20–21. A cold column and a restored
column also matched all six separately accepted receipts on their
interleaved clocks. The day-15 refusal control preserved the
accepted day-14 clock and stocks, refused a second attempt at
the closed column, emitted no day-15 checkpoint and allowed the
other column to accept day 2 exactly. The
[control harness](https://github.com/abhedwig-cell/SWAP5/blob/5c01e7afaeaf5843d1dcd0d7baf9d27aa93db5f1/research/hybrid-water01/check_daily_host.py)
checks those assertions during execution.

## CI scope

The initial evidence head `d1629148` had nine successful workflows and
one failure among the pull-request runs returned for that commit.
The F-CI110 `ahl-application` job reached the inherited Linux shared
library load failure, before the model test. Its loader reports that
`libfgc49d_application.so` requires an executable stack. The same
failure appears on the Grassgrowth and Hupsel evidence heads.
This change modifies only the Andelst research evidence.
[Andelst AHL job](https://github.com/abhedwig-cell/SWAP5/actions/runs/42794242271/job/129755163198).

## Scientific scope

The route preserves the original project inputs and Cauchy boundary.
It uses the previously selected hybrid corrections and balance retry
profile. This evidence qualifies functional completion and the stated
restart/isolation windows. The comparison with unmodified SWAP 4.3.1
remains separate. The largest groundwater difference is 10.88535 cm
on day 457, and the signed drainage difference over the period is
-0.01233 cm. The run requested 86,521 balance retries. These remain
scientific and performance findings, with no tolerance change or
whole-trajectory equivalence claim. The external coupling contract
and MODFLOW scope are unchanged.

## Reproduce

Build with GNU Fortran and GCC. Use a copy of the original SWAP 4.3.1
distribution and fresh output directories.

```powershell
$ref = "./andelst-reference"
$base = "./andelst-481"
$common = @('--model','HYBRID_ANDELST_WATER','--reference-work',$ref)
python -B tools/solute/run_water.py @common --prepare-archive ./SWAP_4.3.1.zip
if ($LASTEXITCODE) { throw 'Reference preparation failed' }
python -B tools/solute/run_water.py @common --output $base --days 481 --checkpoint-at 365
if ($LASTEXITCODE) { throw 'Full run failed' }
python -B tools/solute/run_water.py @common --output "$base-year" --days 457 --restart "$base/accepted-column-1-day-365.zip" --restart-day 365 --checkpoint-at 453
if ($LASTEXITCODE) { throw 'Year restart failed' }
python -B tools/solute/run_water.py @common --output "$base-dry" --days 459 --restart "$base-year/accepted-column-1-day-453.zip" --restart-day 453
if ($LASTEXITCODE) { throw 'Dry restart failed' }
python -B research/hybrid-water01/audit_andelst_application_replay.py $base "$base-year" "$base-dry"
```

The [receipt](andelst-481-application-receipt.json) and [evidence
archive](andelst-481-application-evidence.zip) contain the logs,
dated output and published checkpoint packages. Archive SHA-256
`02570c194df9c712a61bbb2c678d4ed5cc216f2c4def9259885e48a5a3fe83f9`.
To check the archived results directly, extract into a new directory
and run the same auditor on its `full`, `year` and `dry` subdirectories.

```powershell
$x = "./andelst-evidence"
python -B -m zipfile -e research/hybrid-water01/andelst-481-application-evidence.zip $x
python -B research/hybrid-water01/audit_andelst_application_replay.py "$x/full" "$x/year" "$x/dry" --prefix "$x/controls/prefix" --isolation "$x/controls/isolation" --mixed "$x/controls/mixed" --refusal "$x/controls/refusal"
```
