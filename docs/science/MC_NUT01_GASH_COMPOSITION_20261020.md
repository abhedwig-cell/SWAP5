# MC-NUT01 original Gash branch and coupled nitrogen composition

Owning record: `gash_interception_successor` in the existing
`integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json`.
Current qualification base: canonical `9a3a15197adbf37dba340f4f9acbbb44fe76a989`,
including admitted PERF01. Original Gash preimage is also present unchanged
at prior canonical `5ce0f1115a5ea89be54aacaae02ed61ab2ca2696`.
This is a bounded successor of the nine existing nutrient rows and preservation
of already admitted SW431-INT-GASH, not a new capability register.

## Source authority and single-line correction

The pinned SWAP4.3.1 archive, decoded SHA256
`18396ecb9ec297e360d9ef720b8f5359522bca05070c6305c5d9608324247f4c`,
contains `MOD_meteo.f90` Gash (lines2135..2197, total-rpd branch2189)
and `functions.f90` AFGEN. The authority runner
extracts both whole routines unchanged. Only module variables, forcing and
clock are supplied by a test scaffold. The original branch compares total
interceptable precipitation `rpd`, including intercepted irrigation, with
`psatcan`. The former SWAP5 provider compared rain alone. Its only production
change is `if(input%gross_rain_cm<psatcan)then` to `if(rpd<psatcan)then`.
There is no interface, state, restart schema or parameter change.

The original routines are executed in 54 combinations per optimization:
three rain rates, three irrigation rates, three positions relative to the
irrigation window and two irrigation interception choices. The unchanged
preimage fails six cases, maximum 0.17903910039235824 cm interception/day
(1.7903910039235824 mm/day). The corrected provider equals the original
in every case at GNU Fortran O0 and O2, maximum difference zero. The four
existing Gash process, independent oracle, irrigation window and daily
application drivers also run with bounds/FPE checks and strict Fortran flags.
These are process fixtures, not a complete historical model trajectory.

## Source to stock to sink

For the qualified snow-free, daily, stateless Gash application:

`P_interceptable = rain + irrigation_intercepted`

`P_throughfall = rain + irrigation - interception`

`Q_N_top = 0.01 * (rain + irrigation - interception + runon - accepted_runoff)`

Water quantities in these equations are cm/day; the factor 0.01 produces
m/day. Original `management_soil` subtracts integrated interception in its
gross aggregate atmospheric N carrier. Multiplying this carrier by the
historical NH4/NO3 concentrations gives external loading into the existing
soil stores. Accepted bottom and lateral influxes are added once using their
own concentrations. Interception withholds loading before the soil/crop
accounting domain. This does not invent a canopy N stock, gaseous N emission,
or an evaporation-driven dissolved-N removal process.

The actual application derives LAI from the committed accepted crop state,
evaluates the existing Gash process/daily API, then sends throughfall into
the existing accepted Richards/crop/N application. Irrigation alternates
between intercepted and bypass days. Intercepted days cross the original
saturation threshold with irrigation while rain alone stays below it. The
existing daily interception threshold is respected in this profile; no new
claim is made for near-zero, Rutter, Braden or general dispatcher regimes.

The original Soil-N source equation additionally contains rain-on-snow and
gross snow. Melt in an accepted hydraulic trace does not reconstruct those
two original inputs. Snow and persistent surface stores therefore retain
separate explicit admission boundaries; they are not inferred from this test.

## Actual coupled calculation and restart

The 12-day Gash profile uses controlled forcing, actual Reference Richards
steps and accepted water content/fluxes, active WOFOST crop/root states,
dated historical sources, existing organic/mineral chemistry, crop uptake,
transport, bottom exchange and total N accounting. It is a real SWAP5 model
calculation under synthetic forcing, not field calibration or an original
full-model comparison. The existing low/high-N, 730-day crop/calendar,
humus, atmospheric, gross and surface profiles remain in the same run.

Each accepted Gash day checks canopy water closure and the exact independent
source-to-soil NH4+NO3 loading. Cumulative source, output, uptake and canopy
interception diagnostics are advanced only after successful commit. The
application writes eight diagnostic real64 values to a 64-byte `.ledger`
companion at its normal checkpoints. This is a test application journal,
not a new production restart schema. Existing hydraulic/crop/chemical state
uses the unchanged persistent restart owners. New processes resume from
day1 and day6 and compare final state and all eight cumulative diagnostics
byte-for-byte with uninterrupted execution. Rejected hydraulic, nutrient and
clean retry trials preserve their serialized committed state exactly.

Numerical results and costs below come from the completed actual current-canonical
execution. The registered owner and all14 corruption controls pass; canonical
admission receipts are recorded in the existing status. No full-workstream
closure or master disposition promotion follows from the bounded result.

## Reproduction

Use GNU Fortran with `ulimit -s unlimited`, `OMP_NUM_THREADS=1` and
`PYTHONDONTWRITEBYTECODE=1`. Set `FC` to the compiler executable for the direct
runner. Set `N_GASH_AUTHORITY_RESULT_DIR` to a new output directory and run
`python integration/audits/run_nut_gash_authority.py` for the original
archive/direct process qualification. Set `N_HIST_RESULT_DIR` and
`REPRODUCTIVE_LITERAL_FILE` to the pinned literal file, then run
`python tests/nut-crop/run_hist_complete.py` for current physical O0/O2 work.
Run `python tests/nut-crop/verify_hist_native_successor.py` for the owning
registered qualification and
`python integration/audits/verify_nut_gash_successor.py --self-test` for its
negative evidence controls. The original predecessor owners are executed
unchanged at their exact admitted commits, including PERF01 and its13 controls.

## Current executed results

| Actual coupled profile | Duration | Absolute N residual (kg/m²) | Relative N residual |
| --- | --- | --- | --- |
| rotation-profile | 730 days | 9.957312752e-16 | 1.305396388e-15 |
| atmospheric-profile | 730 days | 1.517883041e-15 | 2.234252221e-15 |
| humus-profile | 730 days | 5.034167527e-15 | 7.410057147e-15 |
| gross-profile | 730 days | 1.993197274e-15 | 2.909183298e-15 |
| surface-profile | 12 days | 1.044628793e-16 | 1.554114233e-16 |
| gash-profile | 12 days | 3.697129408e-16 | 5.500308916e-16 |

Relative residual is `abs(R_N)/max(abs(initial)+abs(input),abs(final)+abs(output))`.
The unchanged whole-N acceptance tolerance is 1e-10 kg/m². With inventory scales
0.67 to0.76 kg/m², this corresponds to approximately1.3e-10 to1.5e-10 relative.
It is1e-6 kg/ha and conservatively covers real64 summation over thousands of
accepted operations without masking physically relevant loading or loss. All
observed residuals are over four orders smaller. Internal transfers cancel in
the whole-element budget; uptake is separately retained in the diagnostic
journal and does not become a second external export.

Gash actual initial N is0.66592190132155538 kg/m², external input
0.0062456922725657935, external output0.00032463090923177452 and final
0.67184296268488974. Its whole-N residual is -3.6971294081755701e-16 kg/m².
The actual canopy interception integral is0.11738870308410805 cm; top external
N loading is1.0852225938317840e-5 kg/m² and crop uptake
5.0581249655702181e-6 kg/m². Maximum daily chemical/material residual is
1.5293878664857877e-16 kg/m²; maximum accepted hydraulic-step mass residual is
4.7748534726804737e-15 cm. Canopy water closure is checked at1e-14 cm and
per-day independent NH4+NO3 source loading at1e-14 kg/m². Production water
admission remains governed by the unchanged hydraulic owner.

The full current O0/O2 run reports213.683648 s compile,0.665578 s link,
13.831781 s native model and33.011849 s restart processes. These costs are
observations of this run, not a portable performance claim. O0/O2 complete
results, all14 prior endpoint files and the new two Gash endpoints are exact;
56 transition processes pass. Gash fresh day1/day6 endpoints and all eight
cumulative diagnostic quantities are byte-identical. The original 54-case
process comparison, preimage six-case counterexample and four incumbent
Gash owner drivers pass separately from these actual coupled calculations.


## Incumbent application build closure

The same retained-joint driver remains consumed by the older actual B112
launcher. Its unchanged calendar closure is extended by explicit `visit` calls to the
existing Gash process and daily providers. These two modules are independent.
No old assertion or numerical input changes. The complete older launcher is
executed locally at O0/O2, including default/request/reproductive byte gates,
malformed restart/profile controls and actual source124-day fresh continuation.
Its raw result, compiler/native events and final state files are admitted in
the same capsule. The owning guard compares its default and source endpoints
with the complete current run and includes two additional corruption controls,
for14 controls overall. The early PR head omitted this link-closure extension;
it is superseded before integration, with hosted results recorded by head.

The final incumbent launcher run passed852 measured compiler/native events.
Its measured costs are195.627825 s provider compilation,51.526325 s driver
compilation,2.637839 s linking,8.706358 s native cases and0.491841 s source
continuations. The corrected launcher explicitly resolves both independent
Gash modules. Its O0/O2 retained results and default/source endpoints agree
exactly with the complete current physical run. All14 owning corruption
controls pass. The earlier missing-provider compile failures are retained
separately and do not count as numerical passes.
