# Observed original Hupsel comparison through566

This is an O2 diagnostic comparison of actual original project receipts against the completed1096-day SWAP4.3.1 high-precision reference. It does **not** establish full-project execution or scientific equivalence. No model law, tolerance or physical input was changed for this comparison.

The sourcei application (`fac0d3d`, corrected original RSIGNI binding) executed from day1 through537. Development continuationl resumed537 and reached a preserved checkpoint548; continuationm resumed548 and reached566. This crosses numerical corrections and is not same-build restart qualification. The native daily water/solute budgets contain561 complete observed days,1–543 and549–566; buffered budget rows544–548 were lost when the superseded l process was censored. The crop receipts are complete for all43 active potato days524–566. Missing water/solute rows are neither interpolated nor silently included in cumulative ET.

The comparison uses accepted end-of-day clocks: native clock566 is July20,2003. Subdaily irrigation intervals are aggregated before daily comparison (562 accepted budget intervals become561 complete daily observations). Original stock `WTOT` is soil only; the correct comparison is native soil+pond+canopy versus original `WTOT+PD_VOL+IC_VOL`. Solute `S_STOT` includes original soil+surface mass. Native total ET includes simple maize interception outside the water carrier and Rutter canopy evaporation inside it. The former is restored using identical original gross rain/manual gifts minus carrier inputs; the latter is derived from measured total water outputs after drainage/runoff. SWBOTB6 supplies no bottom flux, DECPOT0 supplies no decay, TSCF0 supplies no solute uptake. These definitions prevent false timing or compartment discrepancies.

| Quantity | Largest absolute observed difference | Day | Difference at566 |
| --- | ---: | ---: | ---: |
| Combined water stock |−0.0193011254cm|36|+0.0005919912cm|
| Soil+surface solute stock |+0.0249752081mg/cm²|349|+0.0058329830mg/cm²|
| Daily actual soil evaporation |−0.0047271690cm|543|+0.0000061039cm|
| Daily potential transpiration |−0.0000569931cm|543|−0.0000214951cm|
| Daily actual transpiration |−0.0012454971cm|566|−0.0012454971cm|
| Daily total ET |−0.0047874200cm|543|−0.0012393933cm|
| Daily drainage |+0.0206930153cm|36|0cm|
| LAI |−0.0009515581|551|−0.0006421325|
| Living root biomass |−0.2918905219kg/ha|566|−0.2918905219kg/ha|
| Living leaf biomass |−0.4176969391kg/ha|549|−0.2540267974kg/ha|
| Stem biomass |−0.2471534594kg/ha|566|−0.2471534594kg/ha|
| Storage-organ biomass |−1.0197694968kg/ha|566|−1.0197694968kg/ha|

Potential organ biomasses differ by at most5.12e−13kg/ha; DVS by4.87e−13; crop TSUM by1.14e−13°Cd; actual/potential root depths by2.85e−14cm. At566 actual RD20.32cm and potential RD50cm match the original. Native storage-organ biomass3767.04842658 versus original3768.06819608kg/ha is−0.0271%; actual root biomass is−0.0238%. Native solute stock24.10939061 versus original24.10355763mg/cm² is+0.0242%. Small actual biomass and uptake differences accompany measured hydraulic differences; potential growth, phenology and root-depth progression agree to printed precision. This observation does not establish tolerance acceptance or causality for every residual difference.

| Observed source period | Maximum water-stock difference | Maximum solute-stock difference | Sum of daily ET differences |
| --- | ---: | ---: | ---: |
| i,1–537|0.0193011254cm|0.0249752081mg/cm²|+0.0350193910cm|
| i, potato495–537|0.0147709328cm|0.0105777030mg/cm²|+0.0106178500cm|
| l,538–543|0.0067782079cm|0.0058463203mg/cm²|−0.0021853338cm|
| m,549–566|0.0015421822cm|0.0058329830mg/cm²|−0.0021659869cm|

The largest water and solute stock discrepancies already occur before the potato numerical correction seams. The available later receipts show no large growing stock error across those seams; this is not a controlled before/after replay proving invariance. The remaining small actual biomass gap grows during the dry uptake period. Original/native solute stocks are effectively constant after drainage ceases near543; the remaining approximately0.00583mg/cm² stock offset was already present upstream. Native accepted balance residuals across these receipts remain at most5.71e−14cm water and9.80e−12mg/cm² solute.

The original PONDMX/RSRO omission was subsequently repaired in source34976ba. **That correction is not present in these i/l/m receipts**. Native m fails during the following wet day567; its raw crash and source-bound metadata are retained. This comparison cannot qualify the corrected surface route or its future continuation. Groundwater-head, soil-profile moisture and energy-profile equivalence are not assessed because these native daily receipts do not contain the corresponding observations.

`PHYSICAL_COMPARISON566.json` records every metric, period, original/executed input hash, compiler/flags, source hash map and SHA-verified executable for each segment. `tests/dataqual15_hupsel/compare_original_trajectory.py` reproduces the tables directly from the archived receipts. The evidence archive includes original output, native raw budget/crop files, source/build manifests, input files and failure/censor records.
