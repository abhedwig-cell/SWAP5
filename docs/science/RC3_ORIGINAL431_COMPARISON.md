# RC3 versus original SWAP4.3.1 on the same laptop

**Complete descriptive comparison; no new model executions.** The three fixed
[RC3](RC3_QUALIFICATION.md) O2 full runs reuse validated original431 full results
and timings. All25 executed input files are byte-identical within their model
pairs. Original selected source bytes, archives, GNU16.2 compiler/FP profile,
actual executable and original link objects/library are revalidated. Each
provider retains its own object identity; different compilation paths are not
represented as identical binaries. Preparation and compilation are excluded
from the timing comparison.

## Observed complete-run times

| Project | Days | Original process,s | RC3 public route,s | RC3 model/controller,s | Public/original |
| --- | ---: | ---: | ---: | ---: | ---: |
| Grassgrowth |1827 |11.365 |12.304 |11.553 |1.083x |
| Hupsel |1096 |4.714 |5.368 |4.746 |1.139x |
| SaltFarm |1461 |5.837 |12.996 |12.195 |2.227x |

These are actual observations on the same laptop at different measurement
times, especially the older valid SaltFarm original timing. They are not a
randomized paired benchmark, accuracy-matched speed comparison or portable speed
guarantee. RC3 public time includes invocation, validation, controller/kernel,
output and requested checkpoint; model/controller is not donor-only time. The
original process includes its own output. RC3 times come from its actual17Nov
clean public cohort, not relabelled RC2 measurements. Model/controller ratios
are about1.02x/1.01x/2.09x; SaltFarm remains the material measured runtime gap.
No new performance investigation or code repair is selected here.

## Complete printed daily result differences

All RC3 printed data records are exactly equal to their RC2 counterparts, so
the existing original comparison remains numerically unchanged. The comparison
is also recalculated from the actual original/RC3 CSVs. Maximum absolute daily
differences are below; initial records are preserved separately. These are
printed quantities, not unrounded internal-state equality. Grassgrowth retains
five output decimals; Hupsel/SaltFarm twelve. Units follow the original CSV.

| Quantity | Grassgrowth | Hupsel | SaltFarm | Unit |
| --- | ---: | ---: | ---: | --- |
| Groundwater level |0 |0.1663390568 |0.01815326003 |cm |
| Water stock |0.01095 |0.008302570612 |0.003840862509 |cm |
| Soil evaporation |0.00251 |0.004401386092 |0.00000076405 |cm |
| Transpiration |0.00393 |0.000239957029 |0.000052504298 |cm |
| Drainage |0.00001 |0.008275532236 |0.003333123029 |cm |
| Dry matter |12.7549 |0.27836837 |0.12116569 |kg/ha |
| Harvested dry matter |14.3867 |0.00437079 |0 |kg/ha |
| Solute stock |inactive |0.012653410926 |0.006152710494 |mg/cm2 |
| Drainage solute |inactive |0.001582559469 |0.004373384426 |mg/cm2 |

The Hupsel GWL maximum is day368 (2003-01-03), SaltFarm day277 (2012-10-03).
COMPARISON.json contains every printed field's maximum/mean, actual values,
day/date, sentinel disposition and selected signed daily-flux period sums.
No explanation for every difference or new scientific acceptance threshold is
inferred from this descriptive comparison.

## Retained contracts and scientific limits

All RC3 committed daily records retain the existing independent water/kernel
and active-solute1e-10 guards. Their exact own restarts, rollback and instance
proof remain valid and are not rerun. Those mass guards are not between-model
equivalence tolerances. Original printed BALDEV/S_BALDEV are not independently
closed unrounded daily budgets.

Both executed decks share the existing output preparation (INLIST_CSV,
NUM_DECIMALS/SWENDTYPE where applicable). Literal historical S_CONC success is
not claimed; the failed first SaltFarm attempt remains in the archived prior
events. Only its subsequent successful exit100 full run is selected. Original
oxygen failures, underqualified Hupsel584 reference families and the separate
experimental local-wetting GWL failure remain visible. Whole scientific
equivalence and complete physical energy remain unqualified. No physics,
tolerance, registered policy, fixed RC3 source branch or ZIP changes.

## Evidence and reproduction

`integration/f-ci/rc3-original431-20261117/SELECTION.json` owns the reuse/cost
decision. AUDIT, COMPARISON and sealed raw CSV/input/build/provider/measurement
receipts bind the actual data. The verifier checks raw differences and parent
RC3 full-output hashes without requiring a compiler or running models:

```text
python -B integration/f-ci/rc3-original431-20261117/verify.py
```

The local Dutch report is `C:/SWAP5-RC3/VERGELIJKING_RC3_SWAP431.md` and is
also delivered in `C:/Users/Veldh012/SWAP5-RC3-20261117`. Raw comparison is at
`C:/SWAP5-RC3/comparison431`. All reuse checks and analysis take13.43s; no
additional full run, build, original reference ladder or broad CI is selected.
