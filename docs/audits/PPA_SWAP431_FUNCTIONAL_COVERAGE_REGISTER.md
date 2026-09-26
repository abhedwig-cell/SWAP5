# PPA SWAP 4.3.1 functional coverage register

## Scope and authority

This is the recoverable campaign index for SWAP 4.3.1 corrected-reference
coverage. It is anchored to `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`.
It reuses, rather than replaces, the source-bound detail in
`integration/audits/production_physics_application_envelope_gap_register.json`.
Statuses describe the current canonical implementation/admission state, not the
frozen Status-A denominator. B1.10 is the current corrected legacy oracle;
confirmed B0 defects are not migration targets.

| Capability family / activation surface | Legacy and SWAP5 authority | State | Qualification / dependency | Next action |
| --- | --- | --- | --- | --- |
| Core Richards, dynamic top and mass accounting | B1; Status-A traceability; PPA-TOP-01 | CANONICALLY_ADMITTED | Status-A scientific/numerical preservation; transaction and mass invariants | Preserve; do not reopen without dependency overlap |
| Typed production bootstrap, mode 7 standalone / all-mode-5 groundwater | PPA-WU01 | CANONICALLY_ADMITTED | PPA-WU01 owner, O0/O2 and preservation gates | Hold fixed; mixed 5/7 remains fail-closed |
| Resolved forcing, SWETR=1, SWINTER=0 and resolved irrigation | PPA-WU03 / PPA-ATM-03 | CANONICALLY_ADMITTED | PPA-WU03 owner/independent/preservation gates | Extend only through a separate ingestion slice |
| Legacy weather files, calendars and complete meteorological preprocessing | B1 `MOD_meteo`, `readswap`, `timecontrol`; PPA-ATM-02 | PARTIAL | Branch-local PMdirect/SWINTER=0 prescribed-root owner, marked weather transition, accepted uptake, exact restart and failed/partial rollback pass O0/O2 under explicit numerical options; third-period completion, file/date decoding and canonical admission remain open | Diagnose the late unmarked continuation failure; broaden ingestion only within the existing owner contract |
| PMdirect normal-input derivation | B1 `MOD_meteo`; PPA-ET-00 | PARTIAL | Restricted typed Hupsel composition admitted | Bind ordinary input derivation without changing ET physics |
| Dynamic top: head/flux/ponding/linear runoff | B1 `boundtop`; PPA-TOP-01 | IMPLEMENTED_NOT_FULLY_QUALIFIED | Restricted profile only | Broaden only with option-specific authority |
| SWINTER=0 / Rutter SWINTER=3 | PPA-INT-00 / PPA-INT-03 | CANONICALLY_ADMITTED | Bounded typed applications | Preserve profile bounds |
| SWINTER=1 daily aggregate | PPA-INT-12; PPA-WU04-C | IMPLEMENTED_NOT_FULLY_QUALIFIED | B1.11 oracle plus branch-local explicit mode-7 storage/temporal/event owner gates: hard mass, failed/partial rollback, accepted-only receipts, mid-window restart and changing-source sequences; not canonical admission | Broaden ordinary ingress and dynamic-top regimes beyond the qualified fixed-flux profile |
| SWINTER=2 daily aggregate | PPA-INT-12; PPA-WU04-D | IMPLEMENTED_NOT_FULLY_QUALIFIED | B1.11 Gash oracle plus branch-local owner hard-mass/receipt/mid-window restart gates; low-rain full-window replay passes with explicit numerical retry profile 0.8/64; not canonical admission | Extend bounded source transitions; ordinary ingress, disk restart and broader regimes remain open |
| SWREDU=1 Black | PPA-WU04-A | CANONICALLY_ADMITTED | Transaction, restart, mass and preservation evidence | Preserve restricted envelope |
| SWREDU=2 Boesten, `0 < COFRED <= 1` | PPA-WU04-B | IMPLEMENTED_NOT_FULLY_QUALIFIED | Qualified owner gate; admission evidence is required before canonical claim | Reconcile current canonical and route for admission |
| Boesten `COFRED=0` | B1 / PPA-WU04-B | CONFIRMED_LEGACY_DEFECT | Exact branch can form `0/0` | Classify and qualify a B1 correction before SWAP5 work |
| Root uptake / basic Feddes route | Status-A; PPA root-hydraulic authorities | CANONICALLY_ADMITTED | Admitted bounded chain | Preserve |
| Oxygen, salinity, frost, compensated and advanced root stress | PPA-WU05-C and PPA-WU05 | PARTIAL_ORACLES_PRODUCTION_HELD | Pure oxygen factors/cache guard, compensation, salinity and macro-frost factors plus micro Campbell response have exact-source tests; source/state, thermal/coupling and single root-sink composition dependencies remain | Continue independent source-bound oracles; do not claim runtime admission |
| Macropore flow | PPA-WU05-A/A1/A2/A3 | PARTIAL_ORACLES_PRODUCTION_HELD | Exact B1.11 source/state/mass census (A1), isolated typed rollback/restart DTO and harness (A2), plus bitwise VOLUNDR, complete RAPIDDRAIN composition, SATFLOW task-1 interval/incoming composition, task-2 negative-flux partition, task-4 derivative update, ABSORPTION sorptivity/diffusion candidates, sorptivity-vs-Darcy arbitration, defined Darcy candidate, derivative and SWABS=2 diffusivity setup (A3) are source-tested; accepted Richards-owner mass receipt, restart/retry and runtime route remain absent | Continue other exact-source A3 equations in isolation; do not admit production macropore flow until state/mass ownership closes and stale SorpFac source behavior is resolved |
| Lower boundary mode 2, constant typed qbot | PPA-WU02-A | CANONICALLY_ADMITTED | Owner, independent, hard-mass and preservation gates | Preserve |
| Lower boundary mode 2 sine/table and dry continuation | PPA-LOW02-TIME | CANONICALLY_ADMITTED | Typed B1.11 time law and state-derived dry continuation qualified | Preserve restricted profile |
| Lower boundary mode 1 prescribed GWL / hybrid state | PPA-WU02-D / PPA-LOW01 | PARTIAL_ORACLES_PRODUCTION_HELD | DATE1/GWLEVEL guards, AFGEN, top/profile/below regime, in-profile flux/head reconstruction, surface q0→qv→profile→qbot composition are source-tested; pondrunoff/top ingestion, low-GWL transitions and accepted-owner route remain absent | Reuse a proven sole owner or define its transactional contract before production admission; do not alias to mode 5 |
| Lower boundary mode 3 Cauchy/deep aquifer | PPA-WU02-E / PPA-LOW03 | PARTIAL_ORACLES_PRODUCTION_HELD | Explicit/implicit qbot terms, explicit profile C-value and SW3 sine/table forcing have O0/O2 source oracles; HeadCalc/Newton, state and mass routes remain untouched | Reconcile typed components only behind the actual single solver/groundwater owner and qualify retries, restart and accepted mass |
| Lower boundary mode 4 q(GWL)/q(h) | PPA-WU02-F / PPA-LOW04 | PARTIAL_ORACLES_PRODUCTION_HELD | Exponential q(GWL) and absolute-head q(h) AFGEN laws each pass O0/O2 source oracles; no groundwater-state timing or qbot application route | Continue to source-window/state binding without adding a competing GWL owner |
| Lower boundary mode 5 prescribed head | PPA-WU02-C / PPA-LOW05 | PARTIAL_ORACLES_PRODUCTION_HELD | DATE5/HBOT5 AFGEN law is source-tested; ordinary non-groundwater mode-5 semantics remain distinct from groundwater-owned bottom_mode=5 | Define ordinary adapter/ownership and mass-publication contract before production binding |
| Lower boundary mode 8 lysimeter | PPA-WU02-G / PPA-LOW08 | PARTIAL_ORACLES_PRODUCTION_HELD | Strict task-1 active threshold, task-2 flag reuse, plate gradient, residual and Jacobian terms have source oracles; active-set lifecycle is not integrated | Preserve transactional active-set behavior across nonlinear iterations and rejected steps before any admission |
| WOFOST bounded runtime | Status-A traceability | CANONICALLY_ADMITTED | Capability-specific qualified runtime | Preserve bounded runtime; no broad API claim |
| Management: full irrigation, tillage and parser grammar | B1; PPA audit | PARTIAL_ORACLES_PRODUCTION_HELD | TCS1–4, TCS7 and TCS8/DCS2 selectors match B1.11 timing/AFGEN rules over 100,000 O0/O2 inputs; isolated TCS6 weekly-counter/deficit gate, typed schedule-eligibility/fixed-event-precedence gate, fixed and scheduled split/retry candidate identity, fixed-input unit/SSDI-depth normalization plus explicit-rate-to-application composition, root-zone availability/deficit aggregation, TCS7/8 sensor-depth node search, task-4 external-availability scaling, TCSFIX interval filter, fixed-event date/application, scheduled-window date predicate, DCS1 depth equation through surface/SSDI application composition and rate/duration materialization, and the surface irrigation solute source amount match their source rules; generic management parsing, other TCS/DCS modes, event-calendar ingestion, production binding, SSDI solute transport and accepted-mass/restart integration remain absent; tillage has unresolved SWAP-003/004 policy | Continue remaining source-bound selector equations separately; do not infer broad management or runtime admission |
| Snow restricted daily path | Status-A | CANONICALLY_ADMITTED | Exact-head preservation | Preserve; advanced Snow is future scope |
| Drainage and surface evaporation | Status-A | CANONICALLY_ADMITTED | Current preservation authority | Preserve |
| Restart v1 and serialized MultiSWAP v1 | Status-A | CANONICALLY_ADMITTED | Same-tree and permanent preservation | Preserve; parallel real physics is separately bounded |
| Groundwater gateway and MODFLOW6 application chain | Status-A plus post-Status-A F-GC49D | CANONICALLY_ADMITTED | F-GC qualification chain | Product driver integration remains separate |
| iMOD Coupler product lifecycle | Post-Status-A | ABSENT | F-GC50 blocked external/shared authority | Do not implement locally |
| ROSS/RossFast, EB and broad APIs | Future scope | INTENTIONALLY_SUPERSEDED | Explicit Status-A exclusions | Do not treat as migration gaps |

## Candidate ordering and current block

Current branch-local checkpoint `e2ebb40f2` (tested postimage `52189a2af`)
supersedes the historical irrigation implementation limits below. Restricted
TCS7/TCS8 and DCS1/DCS2 single-node SSDI now includes committed pending events,
accepted-only publication, decoded restart and opted-in bootstrap execution.
Exact-interval, event-aligned prefix and bounded multi-prefix window APIs are
qualified in the recorded fixtures, including mixed outcomes and durable budget
boundaries. See `integration/audits/PPA_IRR_APPLICATION_CONTRACT.md` and
`integration/audits/PPA_IRR_EVENT_OWNER_STATUS.json`. This remains branch-local,
not general management/calendar admission or whole-migration closure. Initial
zero-source numerical failures remain open.

### Historical progression (not current implementation limits)

At 1e1cb89a0 the prescribed-source runtime gate covers three windows: start,
unchanged active source after a fresh-owner hydraulic restart, and explicit
source stop. O0/O2 transcripts agree; pressure, water content, time, revision
and inflow agree exactly between original and restored owners. Hard mass gates
hold and the stop window contains no repeated SSDI inflow. The earlier
second-window failure was caused by replaying an expired forcing-event marker
in the test; the unchanged-source continuation now carries no new event.
The separate half-length initial-window failure remains open. This is supplied
forcing, not persisted irrigation scheduling. The isolated event carrier and
its validation/clone/assembly are still unregistered; see
`integration/audits/PPA_IRR_EVENT_OWNER_STATUS.json`.

Current branch-local irrigation progress extends beyond the historical process
checkpoints below. The bounded DCS1 selected-source test now passes accepted
water accounting, per-tile rollback, fresh-owner physical-profile restart and
explicit stopped-source continuation at O0/O2 (8b5920a2d). Total inflow includes
both selected SSDI and the fixture's incoming prescribed drainage. The test uses
stable storage differences, seeded initial derivatives, explicit forcing events
and a 0.8/64 retry profile; mass and temporal limits are unchanged. The zero-source
initial control still fails on one tile, so this is not general numerical
robustness or whole-batch atomicity. Evidence:
`integration/audits/PPA_IRR_SOURCE_ACCEPTANCE_STATUS.json`.

The production owner exposes detached, revision/time-tagged hydraulic profiles;
checked profile-to-DCS1 composition is callable but application scheduling remains
test-controlled. Active-state and nonfinite-interval rejection are covered by
`integration/audits/PPA_IRR_CONTINUATION_GUARDS_STATUS.json`.
Pending event-state persistence and automatic accepted-only publication are
the next implementation phase, preregistered in
`integration/audits/PPA_IRR_EVENT_OWNER_PREREGISTRATION.json`.
That phase is **not implemented** by the profile-copy or source-acceptance tests.

At 163834dca, root-zone accounting gains a checked supplied-input entry:
array extents and layer indices are checked before access, and finite bounded
contents, thickness and final rooted fraction are required before division.
All four accounting outputs match 100,000 source vectors bitwise at O0/O2;
twelve invalid-input cases return zero outputs with an explicit error status.
The scheduled DCS1 suite also remains green. This is not a production
hydraulic-state binding or accepted water booking. Evidence:
`integration/audits/PPA_IRR_DEFICIT_CHECKED_STATUS.json`.

At 728085a6e, explicit DCS1 selection joins the existing scheduled single-node
SSDI candidate route. The 100,000-case TCS7 integration gate and independent
DCS1 oracle pass O0/O2, including source-ordered limits, solute increment,
rate/duration, split/retry and copied-event continuation. The DCS2 bundle and
F-APP07 exact 110-interval composition remain green. This is not a scheduled
surface route, accepted soil/solute booking or whole-application restart.
Evidence: `integration/audits/PPA_IRR_DCS1_SCHEDULED_STATUS.json`.

Verification follow-up at 3474958de covers both TCS7 and TCS8 (100,000
source-order cases each at O0/O2), TCS8 inclusive threshold and immediately
higher non-trigger value, copied-event continuation and all seven selection
eligibility/fixed-precedence gates. Production code and admission are unchanged.

Branch-local irrigation follow-up at 91e62d47b adds default-disabled scheduled
DCS2 minimum/maximum gift limits in B1.11 order: limit, solute overirrigation,
then rate/duration. The 100,000-case O0/O2 gate, split/retry and invalid-input
checks pass. Five existing irrigation suites and the frozen F-APP07 exact
110-interval composition also pass. This is typed candidate-process coverage,
not calendar, accepted soil/solute booking or canonical admission. Evidence:
`integration/audits/PPA_IRR_DCS2_LIMIT_STATUS.json`.

ATM02's late third-period continuation remains open: the explicit 0.9/128 retry
experiment at 18275e28f also fails, after 10,093 internal accepts per tile.
Direct copied-boundary feasibility does not establish full runtime completion;
exact trial-clock/attempt-context diagnosis is still needed. This local numerical
boundary does not prevent independent capability work.

1. **PPA-WU04-C/D** have bounded branch-local combined hydraulic/source-window
   receipt, in-memory restart, failed/partial rollback and hard-mass evidence.
   These explicit opt-in mode-7 gates do not close ordinary weather ingress,
   disk persistence, unrestricted dynamic-top regimes or canonical admission.
   Exact tested refs and limits are recorded in
   `integration/audits/PPA_MVG_STORAGE_DIFFERENCE_STATUS.json` and
   `integration/audits/PPA_WU04D_PREREGISTRATION.json`.
2. **PPA-LOW05-APP** is blocked pending an ownership/mass-publication contract.
3. **PPA-LOW01 / PPA-LOW08** now have pure input/regime/profile/row-term oracles, but their stateful lower-boundary slices remain open; do not conflate them with production migration.
4. **PPA-WU05 remaining root family** has exact-equation oracles but no qualified multi-stressor or MICRO stateful runtime owner.

No production-admission candidate is currently `READY`. PPA-ATM-02 now has
bounded branch-local owner/restart/accepted-uptake evidence at d234a4524, including
a changed-weather event and failed/partial rollback. A later unmarked interval
still fails and is qualified only for exact rollback, not completion. The
explicit numerical profile does not establish broad weather ingress or canonical
admission; see `PPA_ATM02_PRODUCTION_COMPOSITION_PREREGISTRATION.json` in the
integration audit records. For PPA-WU04-C/D, the required exact B1.11
`MOD_meteo.f90` equation oracle has been reconstructed and verified from the
byte-exact distribution: B1.11 has 63 members, 1,886,519 bytes and manifest
`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`. Local
campaign checkpoints cover additional pure WU05 equations and the shared F-KT
retry/restart contract. No new production-admission candidate is `READY`; keep
working independent source-bound slices while the full-SWAP owner/coupling
contracts remain open. LOW01 and LOW03/04/05/08 now have several 100,000-vector
O0/O2 source-oracle checkpoints, but those tests do not bind SWAP state, source
time, the Richards/HeadCalc owner, accepted flux publication, retry or restart.
They are partial mathematical coverage only, not migrated lower-boundary modes.

No item above authorizes a change to Reference Richards, mass accounting,
transaction ownership, restart ownership, or shared groundwater interfaces.

PPA-IRR-TCS7-DCS2 and PPA-IRR-TCS8-DCS2 are local, partial numerical
checkpoints only. Their exact B1.11 source equations select irrigation when
sensor pressure head (TCS7) or volumetric water content (TCS8) is less than or
equal to its AFGEN threshold; both use DCS2's fixed-depth conversion from
millimetres to centimetres. The typed evaluator preserves the existing TCS7
default and adds an explicit TCS8 selector. Separate 100,000-vector O0/O2
source-oracle tests cover AFGEN interpolation and endpoint semantics, trigger
equality and the resulting event amount. They do not qualify a production
irrigation route or alter the restricted F-APP07 admission. PPA-IRR-TCS6-WEEKLY
also isolates the legacy weekly counter transition: it increments `dayfix`,
resets at seven, and tests `10*cdef > irgthreshold` only on reset. Its
100,000-vector O0/O2 source oracle covers the 366 startup sentinel and strict
threshold, but does not establish the daily invocation/calendar or restart
owner.
PPA-IRR-DCS1-DEPTH independently tests the DCS1 amount branch: AFGEN-based
millimetre correction, strict rainfall threshold/reduction, zero floor,
optional depth limits, and optional solute-triggered over-irrigation. Its
100,000-vector O0/O2 oracle does not establish the crop-deficit or solute-state
owner, event selection, or accepted source mass.
PPA-IRR-DCS1-APPLICATION-COMPOSITION composes that DCS1 depth with the existing
fixed-input unit/node normalization and rate materialization helpers. Its
100,000-vector O0/O2 oracle checks surface and SSDI offered amount conservation,
including omitted-rate fallback and selected SSDI node counts. It does not bind DCS1 to a production trigger,
calendar, restart owner, or accepted-mass booking and does not widen production
admission.
PPA-IRR-TCS1-4-TIMING isolates the four earlier crop-timing comparisons. It
source-tests the dry/saline transpiration ratio, readily available depletion
with its source cap, total available depletion, and allowable-depletion amount.
Each selector has 100,000 O0/O2 deterministic AFGEN/equation comparisons plus
boundary cases; crop/root-zone derivation and daily irrigation selection stay
outside the oracle.
PPA-IRR-TCSFIX-FILTER separately tests the fixed-interval post-filter and its
`dayfix` transition, including the 366 startup sentinel, threshold equality,
counter hold, increment and accepted-event reset. This equation does not bind
the saved counter to a daily calendar or Restart-v1 owner; B1's TCS6/TCSFIX
configuration conflict remains a parser-level rule outside the slice.
PPA-IRR-RATE-MATERIALIZATION tests the legacy duration cap and rate selection:
rates producing durations over one day are temporarily adapted to one day,
while zero rate spreads the selected depth across the full day. The source
oracle also reproduces per-node SSDI assignment; its rate sum is expressly not
treated as a whole-column accepted-water amount.
PPA-IRR-FIXED-DATE-MATCH compares the existing typed fixed-event evaluator to
B1.11's strict absolute date tolerance (`<1e-3` day) and verifies that only a
match advances the candidate event index. Its 100,000-vector O0/O2 test is a
date-selector check, not event-calendar, persistence or accepted-mass evidence.
PPA-IRR-FIXED-APPLICATION separately checks the existing typed materializer's
surface (type 0/1) versus SSDI (type 2) rate/concentration/source-vector
assignments over 100,000 deterministic cases. This does not qualify event
ingestion, Restart-v1 ownership, or accepted whole-column mass.
PPA-IRR-WINDOW isolates the B1.11 scheduled-irrigation date-window predicate:
the crop-relative window has a strict lower `>1e-3` comparison while the
absolute-date route has `>=-1e-3`; both retain the source upper `<=1e-3` test.
Each branch passes 100,000 O0/O2 source comparisons plus exact tolerance-edge
checks. Date decoding, crop-year construction, calendar ownership, event
selection, and production binding remain outside this equation oracle.
PPA-IRR-WATER-DEFICIT replays the B1.11 root-zone loop in node order, including
the partial last compartment, to produce `awlh`, `awmh`, `awah`, and `cdef`.
The bitwise O0/O2 oracle covers 100,000 deterministic columns; it does not
derive or own root geometry, layer retention values, or actual water content.
PPA-IRR-SENSOR-NODE reproduces B1.11's first-compartment search for the
TCS7/TCS8 sensor depth with its exact `1e-5` tolerance. The 100,000-profile
O0/O2 oracle is limited to valid in-profile depths and ordered grids; the
bounded helper returns “not found” instead of reproducing legacy out-of-range
memory access.
PPA-IRR-AVAILABILITY-SCALE replays task 4's exact scalar behavior: the surface
rate is always multiplied by `f_irr_avail`, while event duration is multiplied
only when `irr_rate>0`. This does not establish accepted irrigation amount or
cover the separately represented SSDI source vector.
PPA-IRR-ELIGIBILITY exercises the existing typed scheduler's full fail-closed
gate conjunction, including the “fixed event already selected” suppression.
It is deliberately not described as an exact B1 interface replay: B1 exposes
five direct caller conditions, while the typed API adds selection-opportunity
and explicit configuration/request enable checks.
PPA-IRR-FIXED-SPLIT sends 100,000 oversized fixed-event intervals through the
existing typed evaluator, checks that a split request leaves candidate state
and flux untouched, then verifies bitwise identity between the exact retry
and a direct event-sized interval. Solver transaction acceptance and booked
mass are explicitly not inferred.
PPA-IRR-SCHEDULED-SPLIT repeats the interval-equivalence check through the
TCS7/DCS2 scheduled path, including hydraulic triggering and a held candidate
until retry. Neither split test proves solver acceptance or production event
calendar ownership.
PPA-IRR-FIXED-INPUT-NORMALIZATION preserves B1.11's order: omitted `irrate`
is derived from input depth first, SSDI depth is then divided over its selected
nodes, and depth/rate are converted to cm and cm/day. The 100,000-vector
bitwise check is numeric normalization only; it does not parse files or
construct the node range.
PPA-IRR-FIXED-INPUT-APPLICATION composes the explicit-rate normalizer with the
typed event materializer for sprinkler, surface, and SSDI events. Across
100,000 cases, the completed offered source amount reconstructs input gross
depth within rounding tolerance. This is not proof of soil acceptance or
whole-column water balance; omitted-rate inputs remain covered only by the
separate normalization oracle.
PPA-IRR-SCHEDULED-SOLUTE-CARRIER carries B1.11's scheduled `cirrs` value,
bounded to its input range, alongside the typed SSDI source. Its 100,000-event
oracle confirms concentration preservation and unchanged offered water amount;
solute mass integration and transport remain unqualified.
PPA-IRR-SCHEDULED-SOLUTE-OVERIRRIGATION composes the strict dual-switch
`cml(nodsen) > cirrthres` rule after scheduled DCS2 depth selection and before
rate/duration materialization. It preserves the one-node SSDI water vector and
tests both switches, equality and one-switch-disabled branches over 100,000
events. DCS1 integration and solute mass booking remain unqualified.
PPA-IRR-SCHEDULED-RATE-FALLBACK preserves B1.11's zero-rate and duration-over-
one-day behavior by using the event depth as a one-day source rate. The
normalized rate remains in the existing transactional irrigation candidate
state across a partial interval and retry. All 11 direct consumers of the
irrigation module pass O0/O2; parser, production restart and accepted-mass
integration remain unqualified.
PPA-IRR-INTERCEPTION-SOLUTE-MASS composes the B1.11 Von-Höhe/Braden net surface
irrigation partition with the source amount `nird*cirr*dt` over 100,000
deterministic O0/O2 cases. The pure amount helper fails closed on invalid and
overflowing inputs. A companion oracle covers the source's combined
irrigation-plus-precipitation surface-solute storage increment and prior-store
addition over 100,000 cases. These pure source terms do not qualify SSDI solute
transport, cumulative accepted solute balance or production mass booking. The
surface pond dilution, matrix-only top-flux share, and remaining pond solute
store are also bitwise checked over 100,000 cases, including the strict
`qtop < -1e-6` gate; invalid and overflow domains fail closed. The bottom
solute flux uses the source's strict positive-water-flux seepage concentration
selection, otherwise the last matrix concentration, bitwise checked over
100,000 cases. Its cumulative `sqbot`/`imsqbot` increment is also checked over
100,000 cases using the pre-update matrix concentration and source operation
order; cumulative booking remains an isolated oracle, not a production route.
The internal-face convective-plus-dispersive solute flux amount independently
matches B1.11 over 100,000 vectors, including positive/negative gradient and
zero-advection/diffusion branches; invalid and overflow inputs fail closed.
The per-cell `cmsy` flux-divergence plus decomposition/root/lateral sink
storage update is also an independent 100,000-vector equation oracle. This
does not qualify concentration inversion, nonlinear adsorption, reaction
parameterization, solver iteration, accepted state or mass closure. The
linear-Freundlich `cmsy`→`cml` inversion and strict sub-`vsmall` roundoff branch
are independently checked over 100,000 vectors; the nonlinear fixed-point
adsorption inversion remains explicitly unsupported. Root solute uptake rate
per layer and its cumulative amount are separately bitwise checked over
100,000 vectors using the source's `tscf*qrot*cml` operation order. The
soluble/adsorbed decomposition rate also matches the B1.11 temperature-factor
cutoff, moisture limitation, and Freundlich term over 100,000 vectors; cases
outside the guarded equation domain remain held. Water-content molecular
diffusion, pore-water velocity, longitudinal dispersion and timestep
correction feeding the internal-face flux are independently source-checked
over 100,000 vectors. The source's per-compartment `dz²/(2*dispr)` stability
limit, `1e-8` dispersion floor, remaining-interval cap and `dtmin` floor are
also compared over 100,000 eight-layer cases; this is not a complete transport
subcycling or accepted-state integration. A separate composed regression
feeds per-layer dispersion into the global stability minimum and timestep
clamps for 100,000 six-layer cases at O0/O2.
The subsequent substep-advance operation is now independently compared with
the B1.11 `do while ((dt-tcumsol)>1e-15)` loop over 100,000 deterministic
schedules. The oracle preserves the `min`-then-`max(dtmin)` ordering, including
the legacy final-step overshoot, and checks exact elapsed-time updates and
continuation decisions at O0/O2. Invalid, non-progressing and overflowing
advances fail closed; no transport-state or production-owner integration is
implied.
The B1.11 lateral-drainage source term is also independently checked over
100,000 vectors: each signed level flux selects matrix concentration for
strictly positive drainage and aquifer concentration otherwise, then adds in
level order. Both the per-thickness sink rate and interval amount match the
source bitwise at O0/O2. Invalid inputs fail closed; aquifer ownership and
accepted mass publication remain unqualified.
The B1.11 `swbr==1` aquifer concentration update is now source-checked for
positive, zero and negative aggregate drainage, including the strict positive
outflow term, decay, updated seep concentration and subsequent surface-mass
booking with the updated concentration. A 100,000-vector O0/O2 oracle preserves
the source expression order. It is deliberately an isolated equation test:
the legacy post-loop storage-array index, aquifer state ownership, restart and
accepted aquifer mass closure have not been qualified.

PPA-WU05-A1 source hashes and A2 state DTO/rollback authority are now in the
repository. A3 has independently tested source terms: the pure `VOLUNDR`
volume-under-level equation, and `RAPIDDRAIN` compartment transmissivity,
drain-base-gated drainable storage, scalar head/resistance/flux, proportional
compartment distribution and complete eligibility/control-flow composition.
The single-compartment `SATFLOW` task-1 oracle now also compares infiltration
and exfiltration heads, Darcy exchange, radial seepage resistance, Youngs
seepage potential and saturated/top-compartment factors. Each was bitwise
compared against B1.11 over 100,000 deterministic O0/O2 vectors. SATFLOW task 1
also has an interval-composition oracle covering its active-zone gate and
incoming-only ordered aggregate; task 2 has an independent negative-only
sign-partition and ordered aggregation oracle. Task 4 has a pure
derivative-state-transform oracle with strict head-difference threshold and
covering-top-layer correction. Each SATFLOW task was replayed over 100,000 vectors.
The `ABSORPTION` sorptivity branch separately tests event start/continue/end,
wall-wetting scaling and its peak amount cap over 100,000 vectors. The
sorptivity-vs-Darcy arbitration has a further 100,000-vector test for strict
selection, equality, residual and event-closure semantics. The defined active
ABSORPTION Darcy branch is also bitwise tested for head gates, resistance and
moisture factor. The diffusion candidate amount is also independently tested
across its strict wet-matrix cutoff and wall-wetting factor. The SWABS=2
diffusivity equation has its own 100,000-vector test for lambda flooring,
pressure-envelope saturation clamping and Mualem terms. The SHRINK clay
equation, continuous peat curve, and three-piece peat curve are each covered
in a 100,000-vector bitwise O0/O2 source oracle. Non-finite inputs and the
undefined rigid-soil (`SwSoilShr=0`) legacy branch fail closed; this is a pure
equation evaluator, not a macropore runtime/state-owner migration. The clay
SHRINKPAR clay tasks 1 and 2 and the peat task-4 typical-point calibration are
bitwise checked over 100,000 vectors each. Both Newton/root paths have finite
iteration limits, guarded domains, and explicit invalid/source-error checks.
The standalone `DiamPolyg` geometry equation is
also bitwise tested over 100,000 vectors across each of its three density
paths and fixed-diameter fallback. B1.11 assigns local `SorpFac` only inside that branch but
later reads it unconditionally in arbitration; stale/undefined cases remain
held out pending source-owner resolution. These remain bounded equations
rather than a complete macropore process or runtime migration. The full B1.11 reconstruction helper still fails
closed on an unrelated SWAP-009 patch-hash mismatch; the exact A1 macropore and
macrorate member hashes nevertheless match the isolated materialized files.
