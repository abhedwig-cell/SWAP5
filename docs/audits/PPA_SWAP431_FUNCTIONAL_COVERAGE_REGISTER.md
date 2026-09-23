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
| Macropore flow | PPA-WU05-A/A1/A2/A3 | PARTIAL_ORACLES_PRODUCTION_HELD | Exact B1.11 source/state/mass census (A1), isolated typed rollback/restart DTO and harness (A2), plus bitwise VOLUNDR volume-under-level and RAPIDDRAIN transmissivity-profile equations (A3) are source-tested; drainable-storage limitation, flow composition, accepted Richards-owner mass receipt, restart/retry and runtime route remain absent | Continue exact-source A3 equations in isolation; do not admit production macropore flow until one owner closes state and whole-column mass |
| Lower boundary mode 2, constant typed qbot | PPA-WU02-A | CANONICALLY_ADMITTED | Owner, independent, hard-mass and preservation gates | Preserve |
| Lower boundary mode 2 sine/table and dry continuation | PPA-LOW02-TIME | CANONICALLY_ADMITTED | Typed B1.11 time law and state-derived dry continuation qualified | Preserve restricted profile |
| Lower boundary mode 1 prescribed GWL / hybrid state | PPA-WU02-D / PPA-LOW01 | PARTIAL_ORACLES_PRODUCTION_HELD | DATE1/GWLEVEL guards, AFGEN, top/profile/below regime, in-profile flux/head reconstruction, surface q0→qv→profile→qbot composition are source-tested; pondrunoff/top ingestion, low-GWL transitions and accepted-owner route remain absent | Reuse a proven sole owner or define its transactional contract before production admission; do not alias to mode 5 |
| Lower boundary mode 3 Cauchy/deep aquifer | PPA-WU02-E / PPA-LOW03 | PARTIAL_ORACLES_PRODUCTION_HELD | Explicit/implicit qbot terms, explicit profile C-value and SW3 sine/table forcing have O0/O2 source oracles; HeadCalc/Newton, state and mass routes remain untouched | Reconcile typed components only behind the actual single solver/groundwater owner and qualify retries, restart and accepted mass |
| Lower boundary mode 4 q(GWL)/q(h) | PPA-WU02-F / PPA-LOW04 | PARTIAL_ORACLES_PRODUCTION_HELD | Exponential q(GWL) and absolute-head q(h) AFGEN laws each pass O0/O2 source oracles; no groundwater-state timing or qbot application route | Continue to source-window/state binding without adding a competing GWL owner |
| Lower boundary mode 5 prescribed head | PPA-WU02-C / PPA-LOW05 | PARTIAL_ORACLES_PRODUCTION_HELD | DATE5/HBOT5 AFGEN law is source-tested; ordinary non-groundwater mode-5 semantics remain distinct from groundwater-owned bottom_mode=5 | Define ordinary adapter/ownership and mass-publication contract before production binding |
| Lower boundary mode 8 lysimeter | PPA-WU02-G / PPA-LOW08 | PARTIAL_ORACLES_PRODUCTION_HELD | Strict task-1 active threshold, task-2 flag reuse, plate gradient, residual and Jacobian terms have source oracles; active-set lifecycle is not integrated | Preserve transactional active-set behavior across nonlinear iterations and rejected steps before any admission |
| WOFOST bounded runtime | Status-A traceability | CANONICALLY_ADMITTED | Capability-specific qualified runtime | Preserve bounded runtime; no broad API claim |
| Management: full irrigation, tillage and parser grammar | B1; PPA audit | PARTIAL_ORACLES_PRODUCTION_HELD | TCS7/DCS2 scheduled selector matches B1.11 AFGEN semantics over 100,000 O0/O2 inputs; generic management parsing, other TCS/DCS modes, event-calendar ingestion, production binding and accepted-mass/restart integration remain absent; tillage has unresolved SWAP-003/004 policy | Continue source-bound selector equations separately; do not infer broad management or runtime admission |
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

PPA-IRR-TCS7-DCS2 is a local, partial numerical checkpoint only. The exact
B1.11 source equations select irrigation when sensor pressure head is less
than or equal to the TCS7 AFGEN threshold, and convert DCS2 fixed depth from
millimetres to centimetres. The typed evaluator now also follows B1.11's
first-/last-value clamps for partial AFGEN tables. Its 100,000-vector O0/O2
source-oracle test covers interpolation, both clamps, threshold equality and
the resulting event amount; it does not qualify a production irrigation route
or alter the restricted F-APP07 admission.

PPA-WU05-A1 source hashes and A2 state DTO/rollback authority are now in the
repository. A3 has begun with the pure `VOLUNDR` volume-under-level equation
and the `RAPIDDRAIN` compartment-transmissivity profile, each bitwise compared
against B1.11 over 100,000 deterministic O0/O2 vectors. These are source terms
used in MACRORATE calculations, not a complete macropore process or runtime
migration. The full B1.11 reconstruction helper still fails closed on an
unrelated SWAP-009 patch-hash mismatch; the exact A1 macropore and macrorate
member hashes nevertheless match the isolated materialized files.
