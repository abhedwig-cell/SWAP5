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
| Legacy weather files, calendars and complete meteorological preprocessing | B1 `MOD_meteo`, `readswap`, `timecontrol`; PPA-ATM-02 | PARTIAL | Decoded daily records, generic-time coverage and PMdirect/SWINTER=0 pure composition are qualified; file/date decoding and accepted production publication remain open | Define transaction/mass/restart composition before production binding |
| PMdirect normal-input derivation | B1 `MOD_meteo`; PPA-ET-00 | PARTIAL | Restricted typed Hupsel composition admitted | Bind ordinary input derivation without changing ET physics |
| Dynamic top: head/flux/ponding/linear runoff | B1 `boundtop`; PPA-TOP-01 | IMPLEMENTED_NOT_FULLY_QUALIFIED | Restricted profile only | Broaden only with option-specific authority |
| SWINTER=0 / Rutter SWINTER=3 | PPA-INT-00 / PPA-INT-03 | CANONICALLY_ADMITTED | Bounded typed applications | Preserve profile bounds |
| SWINTER=1 daily aggregate | PPA-INT-12; PPA-WU04-C | IMPLEMENTED_NOT_FULLY_QUALIFIED | B1.11 oracle, typed receipt/restart progress, accepted-only F-KT publication, exhausted-retry rejection and changed-dt replay; no full-SWAP ingress/hard-mass closure | Qualify combined production hydraulic/source-window replay |
| SWINTER=2 daily aggregate | PPA-INT-12; PPA-WU04-D | IMPLEMENTED_NOT_FULLY_QUALIFIED | B1.11 Gash oracle and shared F-KT receipt/retry/restart contract; no full-SWAP ingress/hard-mass closure | Qualify combined production hydraulic/source-window replay |
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
| Management: full irrigation, tillage and parser grammar | B1; PPA audit | PARTIAL_ORACLES_PRODUCTION_HELD | TCS1–4, TCS7 and TCS8/DCS2 selectors match B1.11 timing/AFGEN rules over 100,000 O0/O2 inputs; isolated TCS6 weekly-counter/deficit gate, typed schedule-eligibility/fixed-event-precedence gate, fixed and scheduled split/retry candidate identity, fixed-input unit/SSDI-depth normalization plus explicit-rate-to-application composition, root-zone availability/deficit aggregation, TCS7/8 sensor-depth node search, task-4 external-availability scaling, TCSFIX interval filter, fixed-event date/application, scheduled-window date predicate, DCS1 amount/rain/limit/solute equations and rate/duration materialization match their source rules; generic management parsing, other TCS/DCS modes, event-calendar ingestion, production binding and accepted-mass/restart integration remain absent; tillage has unresolved SWAP-003/004 policy | Continue remaining source-bound selector equations separately; do not infer broad management or runtime admission |
| Snow restricted daily path | Status-A | CANONICALLY_ADMITTED | Exact-head preservation | Preserve; advanced Snow is future scope |
| Drainage and surface evaporation | Status-A | CANONICALLY_ADMITTED | Current preservation authority | Preserve |
| Restart v1 and serialized MultiSWAP v1 | Status-A | CANONICALLY_ADMITTED | Same-tree and permanent preservation | Preserve; parallel real physics is separately bounded |
| Groundwater gateway and MODFLOW6 application chain | Status-A plus post-Status-A F-GC49D | CANONICALLY_ADMITTED | F-GC qualification chain | Product driver integration remains separate |
| iMOD Coupler product lifecycle | Post-Status-A | ABSENT | F-GC50 blocked external/shared authority | Do not implement locally |
| ROSS/RossFast, EB and broad APIs | Future scope | INTENTIONALLY_SUPERSEDED | Explicit Status-A exclusions | Do not treat as migration gaps |

## Candidate ordering and current block

1. **PPA-WU04-C/D** have source, receipt and restart layers implemented, but
   their typed production ingress and hard-mass closure remain open.
2. **PPA-LOW05-APP** is blocked pending an ownership/mass-publication contract.
3. **PPA-LOW01 / PPA-LOW08** now have pure input/regime/profile/row-term oracles, but their stateful lower-boundary slices remain open; do not conflate them with production migration.
4. **PPA-WU05 remaining root family** has exact-equation oracles but no qualified multi-stressor or MICRO stateful runtime owner.

No production-admission candidate is currently `READY`: PPA-ATM-02 reached the pure typed-ingress and PMdirect/SWINTER=0 composition boundary, but accepted production publication requires an explicit transaction/mass/restart contract. PPA-WU04-C/D required the exact B1.11
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
pressure-envelope saturation clamping and Mualem terms. B1.11 assigns local `SorpFac` only inside that branch but
later reads it unconditionally in arbitration; stale/undefined cases remain
held out pending source-owner resolution. These remain bounded equations
rather than a complete macropore process or runtime migration. The full B1.11 reconstruction helper still fails
closed on an unrelated SWAP-009 patch-hash mismatch; the exact A1 macropore and
macrorate member hashes nevertheless match the isolated materialized files.
