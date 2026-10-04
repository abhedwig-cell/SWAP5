# PPA-WU05-E: salinity state and root-stress migration

Date: 2026-10-04  
Status: `PREREGISTERED_RECONSTRUCTION_CHECKPOINT`  
Canonical baseline: `integration/f-ci-canonical@9605fbb1622d96f4691117f66264f13b6dd3a47b`  
Work branch: `work/ppa-wu05e-salinity-state-root-stress-20261004`

## Purpose

Migrate the minimum production-worthy salt state and salinity-root-stress capability needed before salinity can enter the already admitted Jarvis root-uptake composition. This work unit owns the independent solute-state/transport prerequisite and salinity response. It does not give Jarvis ownership of salt or salt mass.

This is a new bounded unit. PPA-WU05-D remains closed for D2 Jarvis and D3 Walsum. Its D4 and D5 statements remain intact: D4 covered drought plus admitted oxygen, while D5 is the separate MICRO/Jong-van-Lier authority gap. This unit does not rename either slice.

## Reconciled canonical evidence

- Current canonical head is `9605fbb1622d96f4691117f66264f13b6dd3a47b`; its commit closes the D2/D3 canonical admissions and gap registration.
- D2 and D3 qualification records are `integration/audits/PPA_WU05D_D2_QUALIFICATION.json` and `integration/audits/PPA_WU05D_D3_QUALIFICATION.json`. The closeout is `docs/audits/PPA_WU05D_D2_D3_CANONICAL_CLOSEOUT.md`.
- The D2 compositor in `src/process/mod_root_uptake_compensation.f90` currently admits drought and oxygen reductions and rejects unadmitted salinity/frost selectors. The existing nodewise root sink remains the only water-mass owner.
- The canonical tree has no SWAP5 `src/solute`, salinity, salt-transport, or concentration-state implementation. The production-physics gap register already says salinity requires an independently admitted solute-state owner, osmotic-stress process, typed forcing, and transactional composition qualification.
- The pinned B1.11 source identity for `SWAP/rootextraction.f90` is SHA-256 `8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5`, 22,013 bytes. The B1.11 63-member manifest identity is `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`; prior exact-tree replay evidence is `docs/performance/evidence/F-PE19_B1_11_FULL_REPLAY.json`.
- The exact member text is not materialized in this execution surface. The public SWAP source family at commit [`c22bd832`](https://github.com/SWAP-model/SWAP/tree/c22bd832ddf3e53e330a552f5e31e74f183362d1) is corroborating evidence only, not a byte-exact B1.11 oracle. Any final equation or restart claim must keep that boundary explicit.

## Historical reconstruction, bounded to the available evidence

The corroborating source-family implementation distinguishes three things:

1. **Transported salt state.** The solute model transports dissolved concentration in mobile soil water. Its root-extraction code reads `CML(node)`, the mobile-region concentration at the same soil node used for root extraction. The legacy state inventory describes `CML` as mass per water volume and `CMSY` as dissolved plus adsorbed mass per soil volume. Initial concentration profiles are interpolated from depth/concentration input when the applicable initialization mode requests it. Transport includes advective/dispersive boundary exchange and has separate cumulative solute accounting.
2. **Salinity response, switch 1.** When solute transport is enabled and `SWSALINITY=1`, the Maas-Hoffman response is evaluated nodewise:
   `alpha_sol = 1` for `CML <= SALTMAX`; otherwise `alpha_sol = max(0, 1 - (CML - SALTMAX) * SALTSLOPE)`.
   The corroborating input reader bounds `SALTMAX` to 0..100 mg/cm3 and `SALTSLOPE` to 0..1 cm3/mg. These ranges and unit labels must be checked against the exact B1.11 member before production migration.
3. **Osmotic route, switch 2.** This is not an independent `alpha_sol`. The source family converts concentration to osmotic head (`h_osm = SALTHEAD * CML`) and corrects matric-flux potential before the Jong-van-Lier microscopic drought evaluation. Its input reader rejects this mode with Feddes drought (`SWDROUGHT=1`) and requires `SWDROUGHT=2`. Salinity is therefore folded into the drought response and its diagnostics, not separately emitted as the Maas-Hoffman stress output.

For switch 1, the source-family order inside the root-extraction loop is oxygen reduction, drought reduction, salinity reduction, frost reduction, then multiplication of the node sink by all four factors. The compensation block follows those reductions. With selected-stressor selector 4, the salinity aggregate factor is the selected factor to which the critical compensation threshold is applied. This describes the corroborating family; D1's exact B1.11 identity and order evidence is recorded in `integration/audits/PPA_WU05D_STATUS.json`, but byte-exact equation text is still unavailable here.

The crop-side response consumes an already authorized concentration; it owns neither solute transport nor salt mass. The legacy solute model also uses actual node root-water extraction in its solute uptake term, scaled by the transpiration stream concentration factor. That makes accepted root water uptake and salt-state advancement a coupled physical transaction. Root stress must not book a second water sink or mutate solute mass independently.

## SWAP5 audit classification

| Capability | Canonical state at baseline | Classification |
| --- | --- | --- |
| Feddes drought/root sink | Existing admitted root-water process | Already admitted within its bounded profile |
| Bartholomeus oxygen | Independently admitted C3A route | Already admitted within its bounded profile |
| Jarvis and Walsum composition | D2/D3 canonical closeout | Already admitted; salinity remains fail-closed |
| Solute transport and concentration state | No corresponding SWAP5 `src/solute` or typed state in the canonical tree | Missing; separate migration prerequisite |
| Maas-Hoffman response | No SWAP5 response implementation or tests located in the canonical tree | Missing |
| Osmotic-head correction | No SWAP5 response implementation located; depends on Jong-van-Lier drought | Missing and dependent on D5 authority |
| Salinity-to-Jarvis composition | D2 rejects unsupported salinity selection | Not implemented or qualified |
| Solute restart/rollback contract | No admitted SWAP5 solute state exists | Missing; must follow explicit committed/candidate ownership |

The apparent legacy labels `CML`, `CMSY`, and concentration are not enough to imply a current SWAP5 equivalent. No SWAP5 state with verified physical meaning, units, node mapping, mass closure, transaction semantics, or restart contract was found.

## Additional source-family state and mass census

The public source-family solute driver provides a more specific migration checklist, still subject to the byte-exact limitation above:

- `SWSOLU=1` activates solute transport. The crop salinity options are read only when solute is active.
- The soil-water initialization mode separates initial profile from warm restart. For `SWINCO != 3`, the supplied depth/concentration pairs `ZC/CML` are interpolated to the soil nodes. For `SWINCO=3`, the warm-start concentration profile is supplied through the restart path; the initial profile table is not reapplied.
- The driver forms `CMSY), the total dissolved plus adsorbed solute concentration per bulk soil volume, from water content and mobile concentration. With Freundlich sorption enabled it also depends on bulk density, `KF`, `CREF`, and `FREXP). Column inventory is the depth integral of `CMSY). A restart contract cannot preserve only a label called concentration: it must preserve enough accepted state to recover both the mobile concentration used by salinity stress and the stored solute mass.
- The transport balance has explicit surface input, inter-node advective/dispersive flux, bottom exchange, lateral drainage, root uptake, and optional decomposition terms. The source-family solute driver substeps the water interval according to a solute timestep constraint and updates `CMSY) before solving back for `CML).
- Root-mediated solute uptake is `TSCF * qrot(node) * CML(node)` in the source-family mass equation. The final accepted nodewise root-water sink therefore has to be the exact sink used to advance the candidate salt state. Root stress does not account for this solute mass itself.
- The source family has distinct input for precipitation/irrigation concentration and bottom concentration modes, including a time-varying bottom concentration option. Drainage may remove or supply solute depending on flow direction.

These details show why a prescribed or frozen `CML` profile is not a production replacement for salinity physics: it bypasses storage, boundary transfer, root removal, and restart continuity. The first E1 envelope must state which of these terms it includes and prove a separate column salt balance. If sorption or decomposition is excluded, the contract must set those terms to zero and prevent inputs that would activate them. The chosen restart representation should make the committed solute mass authoritative, with `CML` derived or checked consistently; exact legacy warm-restart behavior still needs the pinned B1.11 source census.

## Work plan and gates

### E0: reconstruction checkpoint (this record)

Persist the canonical/current audit, historical formula family, exact-source limitation, and separate-state decision. No production or reference source mutation.

### E1: solute-state contract and minimal transport owner

Reconstruct the B1.11 mass/state lifecycle, input switches, concentration units, depth/node mapping, initialization, accepted-step updates, and restart behavior. Define typed committed and candidate state and a sole salt-mass ledger owner. Select and preregister the narrow first physics envelope before implementation.

The candidate first envelope is conservative dissolved transport with explicitly bounded boundaries and no sorption, decomposition, macropore exchange, or MICRO semantics unless the B1.11 audit shows one is required for valid `CML` semantics. Do not omit root-mediated salt uptake if its absence would break the selected mass contract; otherwise make it an explicit disabled boundary and test it. The envelope decision must be evidence-backed.

### E2: independently testable salinity response

Implement the selected response as a pure process that reads an authorized candidate concentration view and returns nodewise factors. It must not mutate concentration, salt mass, root water mass, or continuation state.

For Maas-Hoffman, use analytical oracles for no stress, onset, partial reduction, zero-floor saturation, boundary values, negative/nonfinite concentration, invalid parameters, uniform concentration on different node grids, and deterministic replay. Require (0 le alpha_{sol} le 1), monotone non-increase with concentration, and nodewise bounds.

Treat osmotic-head mode separately. Do not call it a second multiplicative factor. It remains blocked until the Jong-van-Lier authority and its source/state/transaction conditions are satisfied.

### E3: Jarvis integration, only after E1/E2 qualification

Bind the admitted Maas-Hoffman nodewise response into the existing compositor without adding a water-mass owner. Reconstruct and test drought-only, oxygen-only, salinity-only, drought+salinity, oxygen+salinity, and drought+oxygen+salinity cases. Test selector-4 compensation separately, including avoidance/redistribution among stressed nodes and correct publication of actual transpiration.

Do not claim that osmotic-head mode is integrated by E3.

### E4: transaction, restart, and regression admission

Qualify accepted and rejected trials, discard/retry from committed state, fresh-process replay, restart with changed forcing, no mutation from discarded attempts, independent water and salt balances, and reduced salt uptake under reduced accepted water extraction as applicable to the selected E1 envelope.

With salinity disabled, preserve the admitted Feddes, Bartholomeus, D2 Jarvis, D3 Walsum, application, transaction, and publication routes at existing equivalence criteria. Run local O0/O2 gates before any persisted admission CI.

## Invariants and exclusions

- Feddes remains the base root-water sink; admitted Bartholomeus oxygen may compose with it; Jarvis transforms the candidate; Walsum supplies only the admitted geometry rule.
- One final root-water sink and one accepted water receipt remain.
- The solute state owner alone advances and accounts for salt mass. The root response reads state; Jarvis owns neither.
- Rejected trials cannot mutate committed water or salt state. Retry rebuilds from committed state and applies each response once.
- Water mass and salt mass remain distinct ledgers. Solute uptake uses the accepted root-water candidate under its own bounded contract.
- No salinity restart payload is added to Jarvis. Persistent solute state belongs to the solute-state owner.
- This work does not admit complete legacy solute transport, all crop salt tolerance, solute uptake equivalence, all stress selectors, osmotic-head mode, MICRO/Jong-van-Lier, frost stress, or groundwater/macropore coupling without separate evidence.
- Admission is not a goal by itself. Stop or split further if source semantics or mass ownership demand a larger unit.

## Current checkpoint

- Work unit: `PPA-WU05-E`
- Workstream: PPA-WU05 advanced water-process migration
- Baseline: `integration/f-ci-canonical@9605fbb1622d96f4691117f66264f13b6dd3a47b`
- Production/reference source changes: none
- Persisted: reconstruction/preregistration only
- Tested: no code tests run
- Qualified/admitted: no
- Next action: finish the B1.11 solute state/mass/restart census from source-bound evidence, then decide the minimal transport slice before any production implementation.
