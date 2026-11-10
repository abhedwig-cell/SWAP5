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
Those checks cover days 1–22 with an O2 donor. The retained distinct
Cauchy isolation control was rechecked against both separate ledgers
for days 20–21. The retained refusal record confirms day 15 is refused
at revision 14, with no rejected-day package and an accepted day 2
from the other column. The [original rollback
control](https://github.com/abhedwig-cell/SWAP5/blob/3f10d53d4a37dc7a57c538103299934cf1938aa1/research/hybrid-water01/check_daily_host.py)
also verifies the refused column retains the accepted day-14 stocks.

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
`a6fc4294e9924d10df587e3c2181889d523c7119e739f24a2bf7a7b6dbb1db90`.
To check the archived results directly, extract into a new directory
and run the same auditor on its `full`, `year` and `dry` subdirectories.
