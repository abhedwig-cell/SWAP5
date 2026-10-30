# Grassgrowth measured reference differences

The current canonical full-period authority is `GRASS_UNION_FULL_MANIFEST.json`
and `CANONICAL_FULL_MERGE_RECEIPT.json`: all1827 original days are source-bound
and complete. Current full-period actual harvest differs by+0.5633%; the maximum
daily actual-transpiration difference is0.01128904cm and leaf-biomass difference
is53.21609kg/ha. Whole scientific qualification remains open. The521-day
measurements below are retained as historical evidence.

The controlled follow-up is `tests/dataqual15/qualify_stress.py`. It observes
daily left h/theta/T, root fractions/density, respiration and potential demand
on days25,72,73 and127, and accepted durations/demand/uptake/deepest-root oxygen
factors. Both real oxygen routines receive identical observed states in O0/O2.
Separate checked day1 trajectories cap DTMAX at0.04,0.02 and0.01day through140;
physical input bytes remain original. The coarse output-only postimage must
exactly preserve the qualified daily budget/crop and native physical payload.
This diagnostic changes no production owner or persistent field. Its results
are pending; the inherited1e-4 oxygen-component SOLVE gate does not establish
a crop/yield tolerance. Daily left temperatures do not claim the full accepted
substep thermal trajectory, and the oxygen-component comparison does not yet
certify the entire original uptake composition.

Experimental comparison of the frozen contiguous original-input day1–521 history with the complete original SWAP4.3.1 scalar reference. This establishes measured differences, not whole-model scientific equivalence. Exact input, output and inspected-source hashes and day-level results are in `SCIENTIFIC_DIFFERENCES.json`.

| Quantity | Largest absolute difference through521 | Day |
|---|---:|---:|
| Water storage | 0.0844245 cm | 189 |
| Daily potential transpiration | 0.00698963 cm | 205 |
| Daily actual transpiration | 0.0113503 cm | 188 |
| Actual root biomass | 12.9860 kg/ha | 205 |
| Actual living leaves | 54.1542 kg/ha | 205 |
| Actual stems | 19.3608 kg/ha | 205 |
| Actual root depth | 0.0500419 cm | 439 |
| Potential root biomass | 5.12e-13 kg/ha | 115 |

The prescribed groundwater at retained checkpoints differs by at most4.73e-8 cm from the original printed output; this is not a full daily groundwater/profile comparison. Full daily soil-moisture and temperature profiles are not available in the retained source outputs.

After the first366-day year, SWAP5's actual harvested dry matter is10742.465086 kg/ha versus10653.182217 kg/ha in the source, a difference of89.282870 kg/ha or0.8381%. Potential harvest is12566.142742 kg/ha in both, within the source's printed precision. By521days the cumulative actual-harvest difference is104.781810 kg/ha; potential export remains within3.46e-9 kg/ha. Source annual harvest counters are summed over completed years before comparing with the native project-total continuation.

The observed entry point is oxygen-limited growth. First actual biomass and root-depth differences above1e-8 occur on day72. That day's actual/potential transpiration ratio is0.994608690 in SWAP5 and0.988890191 in the source; on day73 these are0.937459769 and0.916270251. Through521days, cumulative actual transpiration is0.202562895 cm higher, potential transpiration0.117895695 cm higher, oxygen reduction0.086261170 cm lower, and drought reduction0.001593970 cm higher. These quantities satisfy the transpiration attribution relation to source output precision. The differing actual canopy subsequently feeds back into potential transpiration, assimilation and harvest.

Code inspection finds the same clipped daily actual/potential water ratio in original WOFOST and SWAP5. Both integrate deepest-root oxygen factor times duration for daily root extension. The original calls root extraction before soil water and heat after water-flux integration; SWAP5 evaluates extraction/oxygen from each full, half and retry trial's left hydraulic/thermal state and uses only accepted fluxes in the daily crop update. The inspected node-top root-density and respiration formulas preserve the source arithmetic, constants and mowing-delay branch. This is structural source comparison, not a paired-state runtime proof of the complete oxygen chain.

The causal split between timestep/nonlinear policy, hydraulic/thermal trajectory and oxygen implementation is **not isolated**. The retained canonical SWAP5 acceptance policy differs from original SWAP4.3.1. A controlled paired-state or step-refinement comparison is still needed before attributing all observed differences to numerical discretization. This inspection has not demonstrated a process-order implementation defect. Small heat-accounting residuals do not establish temperature or full energy equivalence.

`crop.csv` requires careful time alignment: its `lai` column is the day-start `crop_view`, whereas its organ biomass, development and root-depth columns are committed day-end values. Comparing its LAI directly with source same-day end-of-day LAI produces a false2.2478 maximum at a mowing boundary. Comparing native day-start LAI with source previous-day LAI, excluding the annual initializations on days1 and367, gives a maximum0.115612 on day206. This is a reporting phase distinction, not evidence of an LAI process error.

A separate output-only donor diagnostic attempt requested113-node H/WC/T profiles. The unchanged donor executable rejected both bracketed and plain H variable requests in its CSV lookup. It produced no success marker or usable profile output and is excluded from successful reference evidence. The qualified scalar-reference folder and its inputs/output were left unchanged. No new model implementation, solver setting or physical input was changed for this comparison.
