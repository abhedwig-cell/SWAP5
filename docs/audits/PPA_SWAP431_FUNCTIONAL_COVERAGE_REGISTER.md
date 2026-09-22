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
| Macropore flow | PPA-WU05-A | BLOCKED | Requires B1.11 mutable-state/mass census | Complete PPA-WU05-A1 |
| Lower boundary mode 2, constant typed qbot | PPA-WU02-A | CANONICALLY_ADMITTED | Owner, independent, hard-mass and preservation gates | Preserve |
| Lower boundary mode 2 sine/table and dry continuation | PPA-LOW02-TIME | CANONICALLY_ADMITTED | Typed B1.11 time law and state-derived dry continuation qualified | Preserve restricted profile |
| Lower boundaries modes 1, 3, 4, 5 standalone, 8 | PPA-WU02 C--G | ABSENT | Exact selector classification exists | Dependency-order after WU02-B; mode 5 must respect groundwater ownership |
| WOFOST bounded runtime | Status-A traceability | CANONICALLY_ADMITTED | Capability-specific qualified runtime | Preserve bounded runtime; no broad API claim |
| Management: full irrigation, tillage and parser grammar | B1; PPA audit | ABSENT | Tillage has unresolved SWAP-003/004 policy | Recover source and decide B1 defects first |
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
3. **PPA-WU05 remaining root family** has small exact-equation oracles but no qualified multi-stressor or MICRO stateful runtime owner.

No production-admission candidate is currently `READY`: PPA-ATM-02 reached the pure typed-ingress and PMdirect/SWINTER=0 composition boundary, but accepted production publication requires an explicit transaction/mass/restart contract. PPA-WU04-C/D required the exact B1.11
`MOD_meteo.f90` equation oracle has been reconstructed and verified from the
byte-exact distribution: B1.11 has 63 members, 1,886,519 bytes and manifest
`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`. Local
campaign checkpoints cover additional pure WU05 equations and the shared F-KT
retry/restart contract. No new production-admission candidate is `READY`; keep
working independent source-bound slices while the full-SWAP owner/coupling
contracts remain open.

No item above authorizes a change to Reference Richards, mass accounting,
transaction ownership, restart ownership, or shared groundwater interfaces.
