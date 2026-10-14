# Trajectory 2: annual CO2 in physical daily crop production

Status: implemented candidate; qualification and admission remain separate.
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
