# Trajectory 2: annual CO2 in physical daily crop production

Status: locally qualified and preserved; this is the immutable premerge checkpoint.
Final canonical admission authority is the merged work PR receipt.
Baseline: canonical `82209d0df68d14c5ebe707e9b6303f9b150488ca` (merged PR1227).
Recovery: `integration/audits/MC_CROP01_TRAJECTORY2_CO2_STATUS.json`.

## Dependency decision and physical contract

The shared harvest/rotation morning-boundary contract remains proposed in
`MC_CROP01_HARVEST_ROTATION_PHASE_DECISION.md`. No positive-window kernel,
clock/revision reset or invented zero-duration event resolves it. Trajectory 2
therefore selects the recovery document's independent CO2 production route.
SWRD2/3, anaerobic accepted carriers and rotation require their separate contracts;
this work does not promote component-only evidence into a full lifecycle claim.
Trajectory 3 is not started.

The admitted stateless CO2 resolver exists, but the daily application previously
rejected canopy CO2 and supplied only neutral assimilation factors. This successor
adds an explicit opt-in immutable annual atmospheric forcing. Historical B1.11
`SWAP/MOD_cropdevelopment.f90` selects an exact CO2year entry, then independently
resolves CO2EFFTB, CO2AMAXTB and CO2TRATB with AFGEN. Years are 1000..3000, ppm
10..3000. Missing years fail; concentrations are not interpolated across years.
A typed, sorted unique year/ppm constructor implements that adapter boundary.
External file parsing remains outside this qualified route.

The authentic immutable weather record selects the absolute calendar day. Rooted
ET reads the committed crop canopy and applies the resolved transpiration factor;
accepted Full Richards uptake enters the existing crop receipt. Both previous-day
morning publication and current-day completion use their own physical weather
record's year for efficiency/AMAX. WOFOST81 and all crop/root/soil process arithmetic
are reused without edits. Inactive pre-emergence crops consume no CO2 forcing.
The default OFF path retains its original calls and neutral factors. The separate
canopy-table selector remains refused, preventing two competing response authorities.

Annual forcing and response parameters belong to immutable configuration, already
retained by the opaque joint continuation. There is no new evolving physical state,
restart field/layout, kernel event, crop identity owner, mass owner or external disk
codec. Recomputed factors follow restored configuration and authentic records.
Invalid/missing forcing cannot publish hydrological uptake or growth. The same
source/parameter domain and existing canopy factor validation apply.

Affected invariants: 2,3,4,7,9,13,21,23,29,30. This is application/forcing composition,
not a solver or shared state-interface change. Full Richards, mass budget 1e-12cm,
accepted receipt lineage, retry/reject rollback and duplicate-event rejection stay
binding. The long highest low-air test is NOT_SELECTED under the programme decision;
fast independent oxygen/drainage/mass and numerical acceptance/restart checks remain.

## Qualification selection

1. Small real annual forcing plus existing resolver, literal authenticated B1.11
   AFGEN/response oracle, O0/O2, 2991 concentrations, independent knot vectors,
   endpoints, year/leap boundaries, missing/duplicate/unsorted/invalid years/ppm,
   nonmutation and OFF forcing independence. Measure actual provider closure.
2. Extend the existing seven authentic consecutive Andelst records on the explicit
   homogeneous four-node/30cm test soil. Test both crop publication schedules,
   actual wet-stressed Richards uptake against literal root/CO2 source, complete
   WOFOST81 owner equality using independent literal response factors, current-day
   final growth, rejected/duplicate events and partial/pending/completed restart.
   Execute all incumbent weather, PM, RAINTB and empirical-oxygen programs fresh in
   one isolated build per optimization. This is not an Andelst calibration.
3. Fresh fast direct assimilation, oxygen, numerical policy and short physical
   drainage/restart coverage, original shared-runtime/coupling owner gates and
   complete applicable moving F-CI. Scientific postimage and evidence prerequisites
   are fail-closed for exactly two source blobs; earlier branches remain unchanged.
   Source eligibility never claims qualification or admission.

The physical seven-day fixture stays within 1999; annual year-switch logic is tested
at the independent adapter contract, not claimed as a physical multi-year run.
Harvest/reset/fallow/new seasons, SWINCO3, broader root/demand selectors and joint
external disk restart remain open. No full historical capability/count promotion
follows solely from this bounded production addition.

## Focused terminal evidence and reproduction

The direct production closure has four providers plus driver and literal oracle.
O0/O2 compile/link/native total is 1.516892s; each executes 2991 concentrations.
The physical batch executes 28 programs in 267.704672s: compile 218.918916s,
link 0.971241s, native plus assertions 45.529225s. Each optimization builds 223
shared providers, ten external providers/oracles and five separate drivers. This
large closure is necessary for the actual private accepted-state/Full Richards and
opaque persistence contracts. No mock replaces those physical owners.

The CO2 programs retain both publication schedules and independent wet/dry sink
checks. Each seven-day trajectory has 448 accepted hydrological intervals, 320
wet-stressed intervals and actual positive growth. All complete crop owners match
the WOFOST81 composition with literal CO2 factors; the OFF-demand discriminator
changes uptake. Maximum physical mass residual is 6.0858002665087341e-14cm under
the unchanged 1e-12cm budget. Continuous/restart and O0/O2 outputs are identical.
This is a bounded active-growth route, not a harvest or multi-year physical run.
The annual adapter separately tests exact year switches and the leap day.

All ten original additional shared-runtime/coupling gates passed in 479.903073s
of command time. An absent immutable F-GC21 donor failed before native execution;
fetching the exact object allowed the existing resume controller to continue
without repeating earlier successful groups. The 14 source/physical and nine
additional owner positive/negative evidence controls pass. A relocation-only verifier repair
preserves the original ordered compilation paths under their recorded checkout
root; it does not permit foreign providers, stale inputs or changed flags.

```bash
python -B tests/crop-co2/run_co2_contract.py --output /tmp/co2-direct-new
python -B tests/crop-co2/run_co2_cycle.py --output /tmp/co2-physical-new
python -B tests/crop-co2/verify_co2_successor.py --physical-only
python -B tests/crop-co2/test_co2_successor_controls.py
python -B tests/crop-co2/test_co2_additional_controls.py
```

Use new output paths and a qualified GNU Fortran on PATH. The first two commands
execute science; the verifier checks immutable evidence against current inputs.
The existing status record identifies the separate full moving execution and its
terminal state. A prerequisite PASS does not replace that admission boundary.

To activate this route, construct `file_weather_atmospheric_co2` with
`construct_crop_atmospheric_co2_forcing(years,ppm,forcing,status)` and construct
`file_weather_co2_parameters` with the existing
`construct_crop_co2_response_parameters` using three independent knot vectors.
Set `file_weather_co2_response=.true.` only in the already explicit rooted weather
profile. The existing canopy parameters keep their separate CO2 selector OFF;
this application resolves the common transpiration response exactly once per
forcing evaluation. Original caller configuration changes cannot mutate its
retained copy or an opaque captured continuation.

## Complete preservation closeout

The complete current-source moving F-CI passed in 1883.082534s at
`f8ba5ff6154a397855b2aa8db44c1a6e246bf113`, canonical-first on the baseline above.
All applicable scientific groups executed fresh in SHADOW mode; terminal
`FCI_CANONICAL_LINEAGE_AWARE_GATE PASS` is preserved with raw stdout/stderr and
the actual executed Git bundle in the status-linked MOVING capsule. The source
eligibility subrecord remains explicitly unqualified because it is a prerequisite,
not the terminal result. No private receipt key is exported. Compilation/native
costs for this full command are UNKNOWN; only measured wall time is claimed.

The final candidate retains the exact executed src/tests/tools/reference/ref
closure; later changes only record documentation, status and immutable evidence.
The 24 default native outputs also match the admitted PR1227 evidence byte for
byte after fresh execution. Earlier failed preflights and corrected evidence
controls are retained in the diagnostic capsule. SW431-CROP-CO2 was already
ADMITTED as a component; this bounded daily-production successor changes no
master counts. Harvest/rotation and the broader lifecycle remain open.
