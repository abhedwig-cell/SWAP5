# MC-NUT01 actual original full-caller negative-source qualification

**Decision: QUALIFICATION_ONLY evidence; negative-carrier production admission
remains blocked by a demonstrated original conservation defect.** This does
not reverse the admitted nonnegative/gross/dry/Gash source paths or any
admitted mineral, organic, crop, calendar, retained-stock or restart facet.
The owner is `original_full_caller_qualification_20261020` in the existing
MC-NUT01 status. The existing master remains the single capability register.

## Exact original authority and actual model execution

The original SWAP4.3.1 archive has decoded SHA256
`18396ecb9ec297e360d9ef720b8f5359522bca05070c6305c5d9608324247f4c`;
the original TTUTIL archive has SHA256
`ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193`.
All63 original source providers, including the original `swap_main`, are
compiled and linked at GNU Fortran13.3 O0 and O2. The existing qualified Linux
DEC selection disables external SSS/ANIMO options; no physics stub, substituted
crop/soil procedure, replacement time loop or prescribed dynamic top-node
state is linked. The helper also builds its separate historical kernel driver,
but that driver object is explicitly absent from the actual main link.
Original O0 has bounds checks/FPE traps; original O2 uses the established GNU
compatibility flags. No historical process equation is edited.

Ten complete original model processes execute: a frozen Andelst10-day control
prefix and four10-day configured-crop fallow N scenarios at each optimization.
The control changes only TEND to1998-01-10. Its initial plus10 daily DATE/RAIN/
DRN/GWL records exactly match the frozen full-case output prefix, at both
optimizations. This is not a freshly completed multiyear control or an original
active crop-N equivalence comparison. A longer O0 control was interrupted after
exceeding the selected local budget; its partial output is retained and is not
a scientific failure or numerical PASS.

All four N cases use the frozen soil/weather input structure with declared
controlled forcing: 200mm rain on day1, no rain afterward, warm weather,
PONDMX0.1cm, RSRO1day, initial GWLI-1cm, and the original hydraulic/heat
calculations. Macropores and lateral drainage are disabled. The original
lower-boundary data remain in use. This is a stress scenario, not field
calibration. Every case finishes normally with return100, the original success
marker and no error file. The native80 daily Soil-N steps and all original
water/N CSV data are identical at O0/O2 after removing generated metadata.

## Historical input and fallow gates

Original `swap_base` lines261..263 reads SWCROPSNM only inside SWCROP=1.
The first SWCROP=0 controls therefore ran hydrology and did not execute Soil-N;
zero nutrient records exposed that distinction. They are retained separately.
The qualified cases use SWCROP=1, SWCROPSNM=1 and crop emergence1998-01-15,
after the10-day horizon. This exercises genuine configured-crop fallow rather
than forcing a SoilManagement call through a scaffold. Demand is exactly zero
and there is no crop growth. Tiny signed uptake diagnostics, at most
3e-13kg/m²/day, are retained in the compartment book and cancel as internal
transfers in the whole-N book. They are below the unchanged1e-10kg/m² scale;
they are not promoted as physical crop uptake.

Original TTUTIL also requires a real token for rdsdor: HUM_T=0 is an INTEGER
and is rejected. Generated real scalars use explicit exponential real syntax.
Earlier rejected input runs, including original fatal O2 return0, remain
archived. Return code alone never establishes model success; the owner checks
completion marker, error state, source/parameter identity and actual N records.

FOM pools and humus are zero, with Bio1e-8kg/m³. This neutralizes the known
FOM R1 defect while retaining the original respiration-dependent denitrification
route. The sole material event is a zero-dose future event. Same-day R2 and the
seepage-reader defect cannot cause the result: all bottom/lateral concentrations
are zero. Nitrate top concentration is0.005kg/m³. Initial nitrate is0 or
0.05kg/m³; reference denitrification is50/day or0. The strong rate is an
explicit historical-boundary stress, not a recommended field parameter.

## Source to stock to sink and independent balances

Original management_soil constructs:

`Q_N_top = 0.01*(igrai+isnrai+igsnow+igird-iintc+irunon-iruno)/outper`.

This original aggregate is not matrix infiltration. On a dry day, runoff of
previously ponded water can make it negative. The actual original hydraulic
to integral to SoilManagement path produces that negative carrier here.
Nitrate loading is Q_N_top times its prescribed source concentration. All
sources and gas/transport outputs are booked from the original nutrient CSV;
initial/final organic, NH4 and NO3 stocks are reconstructed independently.

`N_total = N_FOM + N_Bio + N_Hum + NH4 + NO3 + N_crop`.

Here inactive-crop inventory/change is zero. Mineralisation, immobilisation,
nitrification and soil-to-crop transfer cancel internally. The verifier keeps
separate NH4, NO3 and organic residuals, a soil control-volume residual including
signed uptake, and a whole-N residual with uptake canceled internally. Genuine
denitrification and boundary export remain external outputs.

| Original actual case | Max daily N discrepancy (kg/m²) |10-day whole-N residual (kg/m²) |10-day relative residual | Depleted negative days |
| --- | --- | --- | --- | --- |
| Low initial N, denitrification50/day |3.594831001e-4 | -4.902651126e-4 |0.427157625 |3 |
| High initial N, denitrification50/day |3.594831001e-4 | -4.902941126e-4 |0.068057289 |3 |
| Low initial N, denitrification0 |8.116500012e-5 | -9.992800012e-5 |0.087065153 |2 |
| Ample initial N, denitrification0 |5.799999897e-8 | +7.999999965e-8 |1.110472866e-5 |0 |

The largest depleted daily case is1998-01-02. Initial total N is
1.4363174001908342e-5kg/m², prescribed external input -3.6752e-4,
external output6.3261e-6 and final1.7411582467e-10. The residual is
-3.594831001139163e-4kg/m², or -3.594831001kg/ha; its relative magnitude is
0.9413431243. The wet-day nitrate loss naturally depletes the initially high
case too; its initial nitrate is60.564kg/ha versus zero in the low case.
No stock is manually reset between these days.

Original WaterN limits a negative concentration through Vsmall=1e-12kg/m³
and a shortened analytical interval Ttry. Its declared boundary loading still
uses the full daily negative carrier. Near-zero positive final stocks are
therefore identified using the literal Vsmall times the actual water volume,
not by pretending they are exactly zero. The actual counterexample reproduces
the earlier conditional process witness under the real original time loop.

## Precision, tolerances and scientific consequence

The existing production N gate remains1e-10kg/m². The original CSV writes
1pe11.4, so it cannot prove a full original-model1e-10 balance. The owner sums
conservative half-last-digit rounding bounds for every printed budget term,
including zeros. The worst depleted daily bound is1.055500100e-7kg/m², over
3400 times smaller than the observed discrepancy. The ample/no-denitrification
control remains within its printed precision; no stronger intrinsic precision
claim is made. Whole-period conservative printed bounds are1.04e-6 to2.14e-6
kg/m². Period relative scaling uses initial inventory plus absolute signed
external fluxes, avoiding cancellation of wet input and dry extraction.

Maximum absolute printed water BALDEV is8.50584e-7cm. At the prescribed top
N concentration its loading equivalent is4.25292e-11kg/m², over eight million
times smaller than the largest N discrepancy. These results do not equate
original hydraulic tolerances with current SWAP5 production tolerances.

A negative prescribed loading cannot be debited in full once the available
stock is exhausted while also keeping stocks nonnegative and conserving N.
Literal original output and the required conservation/positivity contract
therefore disagree on a reachable historical path. Admitting that path would
need an explicit corrected-reference decision about the actual boundary-N
flux or a source-authorized surface-N inventory. Neither an invented
compensating source nor silent flux clipping is justified here. Current
production rejection remains intact. Other admitted paths are unaffected.

This is the strictly bounded scientific blocker for full historical closure.
It does not demonstrate unrestricted original active crop-N trajectories,
full multiyear SWAP5/original equivalence, snow or persistent surface-N binding.
Current SWAP5 rollback and persistent restart evidence remains the separately
admitted56-transition Gash/current model qualification.

## Reproduction and qualification cost

Set an explicit GNU compiler in FC and PATH, OMP_NUM_THREADS=1,
PYTHONDONTWRITEBYTECODE=1, `ulimit -s unlimited`, and
N_ORIGINAL_FULL_RESULT_DIR to a new directory. Execute
`python integration/audits/run_nut_original_full.py`. The runner uses120-second
native budgets and noninteractive unbuffered IO. Execute
`python integration/audits/verify_nut_original_full.py` and its `--self-test`
for the immutable admitted evidence. All9 corruption controls pass.

Final measured costs:33.941667s complete original builds,0.075534s main
compilation,0.147272s main linking and15.494723s actual model processes.
The archive retains original/selected source, complete commands, logs, inputs,
outputs, success markers, end conditions, previous failures and interruption.
No new current production compilation, F-CI campaign, RossFast or aquifer
qualification is selected for this evidence-only unit; current production
providers are unchanged from canonical790fb52f/source2b2d253d.

## Canonical evidence integration

PR#1340, canonical `e41f36658f23dcd6aa3f34835e4722eae23fba42`, qualified
`171e45a48afe6a08d3e62a250c72ef6aba3fdd67`; actual full tree dc02644c equals the
qualified tree and the actual-merge owner passes. Production source2b2d253d
is unchanged. Evidence integration preserves QUALIFICATION_ONLY: no negative
production path or full historical closure is admitted. Existing master receipt
`34f5a9fc3a7f061d8fb05e8320b8f549f1465d1d` preserves234 other rows and243
dispositions and passes all nine original scoped production-reachability checks.
