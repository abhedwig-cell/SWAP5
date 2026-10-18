# Historical native input and continuous crop rotation

Status: implemented and locally qualified bounded successor to canonical
`4a274c4650ec7f52324b8604838a8d27dd39edb3`. The exact execution commit,
terminal integration gates and canonical admission are recorded in
`integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json`.
This document does not declare the full HIST work unit complete.

## Source authority and input contract

The existing pinned nutrient archive and `tests/nut-crop/audit_legacy_snm_source.py`
remain the management/parameter authority. The separately archived unmodified
TTUTIL ZIP is `integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64`;
its decoded SHA256 is
`ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193`.
The independent executable oracle compiles all 153 original providers at O0/O2.
It reads the same four fixtures as the production parser and proves the original
scalar-versus-array rejection. This is independent input interpretation evidence,
not comparison with a complete legacy multiyear model run. Decimal conversion
in unmodified TTUTIL differs by one ULP for 0.21; the oracle uses 1e-14 for that
input comparison. Production water/N acceptance limits are unchanged.

| Semantic part | Source evidence | Implementation/test boundary |
| --- | --- | --- |
| Keywords and lexical types | TTUTIL RDAINR/RDFDOR/RDSDOR/RDATIM | Case insensitive; integer versus real, scalar versus array; assignments, positive repetitions, continuation, comments and complete typed tables |
| Materials | management_soil lines120..126 | At most20 positional contiguous IDs; names, age, organic matter/N and mineral fractions; repeated scalar input requires explicit `1*value` |
| Calendar | management_soil lines129..132 | At most1000 events, repeated same-date events, dosage and volatilization; daily dates across years; TTUTIL day1 mapped explicitly to internal day0 |
| Initial inventories | management_soil lines179..190 | All eight FOM pools, biomass, humus, NH4 and NO3 through existing storage conversion and owner |
| Rates and boundary parameters | management_soil lines192..214 | Named values, missing/duplicate/invalid rejection and original physical source line; both top concentration fields required and zero |
| Optional crop values | management_soil lines211,222..240 | LAI default0 and arable residue-age defaults1.27/.99/1.27/1.27 retained |
| Bounds | Original reader plus admitted owner | 512 characters/record,4096 records,20 materials,1000 events; tighter existing physical age<=100 and volatilization<=1 remain explicit restrictions |

`run_native_snm.py` executes24 cases at each optimization, including the complete
20-material/1000-event capacity, physical error-line mapping and atomic rejection.
The modern bracketed export contract stays separate; its four-provider regression
suite is preserved. A modern export convention is not a historical default.

UNSUPPORTED and unqualified: nonzero top dissolved-N concentrations, fractional
calendar timestamps, missing-value placeholders, string concatenation/quote
escapes, rerun sets and arbitrary scalar tables. Experimental humus parameters
`RateconHum_exp`/`tstartHumexp` and `flCropExt` diagnostics are not migrated.
SW_WOFOST selections beyond the currently admitted classical path are not inferred.
Historical broad age/volatilization ranges are not admitted physical ranges.
The source `cNO3N_seep` assignment into `cNO3N_lat` remains an explicit reference
policy gap documented by the historical named activation receipt; the existing
SWAP5 distinct inputs are preserved, without claiming B0 equivalence for that bug.

## Optional clean surface-water contract

This successor explicitly extends the existing bounded crop/Soil-N composition
with signed clean surface water. It adds no physical owner or persisted field.
The optional carrier is meters/day: positive infiltration adds water with zero
NH4/NO3; negative evaporation removes water without advective N loss. Only the
accepted Richards trace supplies this carrier. Whole-column water closure checks
its signed amount; the chemical kernel receives only positive top infiltration.
The option is explicit and defaults off at trace aggregation. Existing callers
retain their fail-closed top-flux contract. Runoff/exfiltration solute, ponding,
macropores and nonzero top concentrations are outside this extension.

The calendar composition now forwards the existing fallow path through the
material/joint owner, retaining daily chemistry and calendar amendments without
creating a crop. Active days retain the existing senescence route. An eight-ULP
root-water equality guard applies only to the crop forcing view when actual and
potential uptake differ solely by summation/unit-conversion roundoff. It does
not alter raw water receipts, N carriers, mortality thresholds, numerical policy
or genuine drought limitation. The direct mineral driver tests infiltration,
evaporation, wrong-sign closure and NaN rollback through the real owner.

Affected invariants:1..4,7,9,11,13,21..23,25,26,28..30. The existing private Soil-N
and crop hierarchy, accepted water state, restart codecs and Reference Richards
solver remain authoritative. RossFast receives no implementation or qualification
extension. The optional water carrier is ephemeral, so old restart schemas stay
unchanged and the owning old-byte integration gate remains selected.

## Continuous physical qualification

`tests/nut-crop/run_hist_complete.py` compiles the actual shared production
closure afresh at O0/O2. The 323 providers are required by the existing production
Richards bootstrap; the driver does not replace them with mocks. This expensive
stable-candidate gate is selected in the work-unit test-selection record.
The runner also executes the original B1.12 owner test and source124-day case,
with their fresh-process and opaque endpoint assertions.

The new profile advances730 actual days from30 December1900. Crop1 grows for120
days, is harvested and returns residues; soil chemistry and calendar applications
continue through fallow. A successor enters on day365, grows to harvest on day500,
and fallow chemistry continues to day730. Two materials and six dated events
include same-day events and organic amendment during fallow. Initial FOM,
biomass, humus, mineral N, retained/pending residues, export and successor seed
inventories remain in the existing owner and whole-N budget.

This is a controlled synthetic physical contract scenario, not a calibrated field
prediction. Temperature, radiation and daylength vary seasonally; root-water
extraction is nonzero on active days. Signed atmospheric exchange and groundwater
supply keep the column away from the previously rejected drying stress. Bottom
inflow supplies root demand plus a small seasonal exchange. Lateral drainage is
zero; signed bottom exchange is included. No claim is made for a field weather
series, a separate ET calculation or a complete legacy rotation oracle.

The complete730-day output and native endpoints must be exactly equal at O0/O2.
Fresh processes resume after days1,120,121,365,366,500 and must reproduce the same
endpoint bytes. Day120 and366 rejected stale-environment trials serialize to
identical before/after bytes, then retry the same calendar day successfully.
The combined endpoint proves that no material event is duplicated or omitted.
All eight FOM pools, biomass, humus, NH4/NO3 and final water/head ranges are recorded.
The cumulative whole-N budget includes external input/output, volatilization,
harvest export and successor seed; internal uptake is counted only as transfer.

The original imposed -0.1 bottom-flux stress still fails on day67 and remains
rejected evidence. Neither solver nor temporal criteria are reopened. Full F-CI,
RossFast and highest-low-air are NOT_SELECTED_IMPACT. Existing actual production
and focused native integrated gates remain required before canonical admission.
No whole-capability mastercoverage promotion follows from this bounded result.

## Reproduction

Use gfortran13 with an unlimited process stack for the large existing driver.
First execute `tests/nut-crop/run_reproductive_process.py` with
`REPRODUCTIVE_PROCESS_RESULT_DIR` to produce the pinned literal. Then run
`tests/nut-crop/run_hist_complete.py` with a fresh `N_HIST_RESULT_DIR` and
`REPRODUCTIVE_LITERAL_FILE` pointing to that generated literal. Raw events record
the exact compiler flags, commands, costs, source hashes and all subprocess output.
Use fresh `N_NATIVE_RESULT_DIR` for `tests/nut-input/run_native_snm.py`, then
`TTUTIL_RESULT_DIR` plus that fixture directory for
`tests/nut-input/run_ttutil_native_oracle.py`. Evidence archives omit reproducible
object/module/executable files, retain native restart payloads and all run logs,
and bind dependency reuse by input hashes rather than by branch names.
