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
- The exact member text is not materialized in this execution surface. D1 pins the B1.11 root-extraction member identity and records the stress order; its public-source comparison is corroboration, not a byte-exact replay. For the missing solute-state and restart lifecycle, the public SWAP source family at commit [`c22bd832`](https://github.com/SWAP-model/SWAP/tree/c22bd832ddf3e53e330a552f5e31e74f183362d1) is corroborating evidence only. Keep that boundary explicit in any migration claim.

## Historical reconstruction, bounded to the available evidence

The corroborating source-family implementation distinguishes three things:

1. **Transported salt state.** The solute model transports dissolved concentration in mobile soil water. Its root-extraction code reads `CML(node)`, the mobile-region concentration at the same soil node used for root extraction. The legacy state inventory describes `CML` as mass per water volume and `CMSY` as dissolved plus adsorbed mass per soil volume. Initial concentration profiles are interpolated from depth/concentration input when the applicable initialization mode requests it. Transport includes advective/dispersive boundary exchange and has separate cumulative solute accounting.
2. **Salinity response, switch 1.** When solute transport is enabled and `SWSALINITY=1`, the Maas-Hoffman response is evaluated nodewise:
   `alpha_sol = 1` for `CML <= SALTMAX`; otherwise `alpha_sol = max(0, 1 - (CML - SALTMAX) * SALTSLOPE)`.
   The corroborating input reader bounds `SALTMAX` to 0..100 mg/cm3 and `SALTSLOPE` to 0..1 cm3/mg. These ranges and unit labels must be checked against the exact B1.11 member before production migration.
3. **Osmotic route, switch 2.** This is not an independent `alpha_sol`. The source family converts concentration to osmotic head (`h_osm = SALTHEAD * CML`) and corrects matric-flux potential before the Jong-van-Lier microscopic drought evaluation. Its input reader rejects this mode with Feddes drought (`SWDROUGHT=1`) and requires `SWDROUGHT=2`. Salinity is therefore folded into the drought response and its diagnostics, not separately emitted as the Maas-Hoffman stress output.

For switch 1, the source-family order inside the root-extraction loop is potential node sink, oxygen/drought/salinity/frost factors, multiplication of the node sink by those factors, then aggregate `qrosum` and stress-loss attribution. The Maas-Hoffman `alpsol(node)` is nodewise; the total root-zone salinity loss is attributed into the `qred` accounting. Compensation follows those reductions. The corroborated compensation algebra first forms `alptot=qrosum/ptra` and `qred=ptra-qrosum`, with a guard for positive reduction and `alptot >= 0.05`. Each aggregate stress factor is reconstructed as `alptot**(qred_stressor/qred)`. For selector 4, only the salinity aggregate factor is divided by `alphacrit` and capped at one; the compensated total is the product of the stress factors. The final candidate node sinks are uniformly rescaled once by `alptotcom/alptot`, then totals and attribution are recomputed. This is the source-family/corroborated rule recorded in `integration/audits/PPA_WU05D_STATUS.json` and `docs/audits/PPA_WU05D_D1_RECONSTRUCTION_RESULT.md`; byte-exact B1.11 equation text remains unavailable here, so it is not a byte-exact legacy claim.

The response/transport split also bounds initialization and temporal ownership: source-family `SWINCO != 3` interpolates a supplied depth/concentration profile for initialization, while `SWINCO=3` restores warm-start concentration rather than reapplying that profile. Candidate salt mass must advance using the same accepted root-water sink after compensation, and a rejected attempt must discard it. D1 found no corroborated continuation state for compensation itself; that does not remove the independently required persistent solute state and restart contract.

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
- The driver forms `CMSY`, the total dissolved plus adsorbed solute concentration per bulk soil volume, from water content and mobile concentration. With Freundlich sorption enabled it also depends on bulk density, `KF`, `CREF`, and `FREXP`. Column inventory is the depth integral of `CMSY`. A restart contract cannot preserve only a label called concentration: it must preserve enough accepted state to recover both the mobile concentration used by salinity stress and the stored solute mass.
- The transport balance has explicit surface input, inter-node advective/dispersive flux, bottom exchange, lateral drainage, root uptake, and optional decomposition terms. The source-family solute driver substeps the water interval according to a solute timestep constraint and updates `CMSY before solving back for `CML.
- Root-mediated solute uptake is `TSCF * qrot(node) * CML(node)` in the source-family mass equation. The final accepted nodewise root-water sink therefore has to be the exact sink used to advance the candidate salt state. Root stress does not account for this solute mass itself.
- The source family has distinct input for precipitation/irrigation concentration and bottom concentration modes, including a time-varying bottom concentration option. Drainage may remove or supply solute depending on flow direction.

These details show why a prescribed or frozen `CML` profile is not a production replacement for salinity physics: it bypasses storage, boundary transfer, root removal, and restart continuity. The first E1 envelope must state which of these terms it includes and prove a separate column salt balance. If sorption or decomposition is excluded, the contract must set those terms to zero and prevent inputs that would activate them. The chosen restart representation should make the committed solute mass authoritative, with `CML` derived or checked consistently; exact legacy warm-restart behavior still needs the pinned B1.11 source census.

## Work plan and gates

### E0: reconstruction checkpoint (this record)

Persist the canonical/current audit, historical formula family, exact-source limitation, and separate-state decision. No production or reference source mutation.

### E1: solute-state contract and minimal transport owner

Reconstruct the B1.11 mass/state lifecycle, input switches, concentration units, depth/node mapping, initialization, accepted-step updates, and restart behavior. Define typed committed and candidate state and a sole salt-mass ledger owner. Select and preregister the narrow first physics envelope before implementation.

The first E1 contract is restricted to one conservative dissolved salt constituent in the mobile liquid phase:

- `SWSP=0`: no Freundlich sorption; decomposition, macropore exchange, ageing, saturated-aquifer breakthrough, and MICRO are disabled.
- The typed state stores accepted salt mass per node and derives `CML` from that mass and the matching accepted water content. For node thickness `dz_i`, the restricted storage relation is `M_i = theta_i * CML_i * dz_i`. Its units are mass per area for each node. Dry-state behavior outside the admitted liquid-water range must fail closed until a physical immobile/precipitated salt owner is defined.
- Initial concentration uses an explicit depth/node mapping. Warm restart restores committed salt mass together with the corresponding committed water state; it must not reapply the initial profile.
- Transport uses the matching trial's water fluxes and water contents, plus typed solute concentrations for incoming boundary flows. The current explicit upwind prototype uses committed-start mobile concentration for outgoing and inter-node donor fluxes; replacing it with substepped or implicit trial concentration requires its own source review and qualification. Root salt uptake is explicit through `TSCF * qrot_i * CML_i`, with the same candidate root sink that feeds the existing single water-mass receipt. The initial admitted TSCF envelope is `0 <= TSCF <= 1`; this is a restricted migration claim, not full legacy-range equivalence.
- The first test profile has one connected soil column, no surface storage or aquifer mixing, and prescribed typed top/bottom solute boundary traces. Lateral drainage is excluded from this first slice and added only with an explicit mass-flux contract.

### Implemented local E1/E2 prototype boundary (not admitted)

The branch now contains `src/process/mod_solute_mobile_salt_state.f90` and `src/process/mod_root_salinity_response.f90`, tested by `tests/physics/run_ppa_wu05e_mobile_salt.sh` at O0 and O2. The first module owns a candidate column salt mass ledger and accepts explicitly supplied water start/trial contents, face fluxes, root sink, boundary concentrations, timestep, and TSCF. It checks water closure, derives `CML` from mass and matching water content, uses upwind **committed-start** concentration for an explicit advective step, records top/bottom and root salt terms, and rejects negative mass rather than clipping it. It excludes dispersion, internal solute substeps, boundary schedule parsing, drainage, and runtime/restart binding. This is an exploratory minimal envelope; the last three transport exclusions and explicit scheme still need physical/numerical qualification before widening or integrating it.

The second module independently implements the Maas-Hoffman switch-1 response with `CML` and `SALTMAX` in mg/cm3, `SALTSLOPE` in cm3/mg, and dimensionless bounded alpha. It has no state ownership and is not wired to Jarvis. Its unit tests exercise threshold, onset, partial reduction, zero floor, bounds, monotonicity, and invalid inputs. The exact B1.11 solute member text, production parameter limits, production runtime coupling, committed restart serialization, full balances under changing forcing, and stress-combination qualification remain open. These local prototypes establish implementation/test status only, not production qualification or canonical admission.

`src/process/mod_solute_water_face_flux_reconstruction.f90` provides a third independent helper. It reconstructs positive-downward net interval-mean Richards face flux from start/end water contents, node thickness, signed net node sources, timestep, and top flux; its recurrence is closed against the independently supplied bottom flux. The O0/O2 manufactured test covers downward, upward, and reversing fluxes plus bottom-closure and nonfinite-input rejection. A second O0/O2 test now checks closure against an actual Reference Richards solve with nonzero subsurface source and nonzero separately bound final root sink, zero imposed top flux, and the independently reported head-boundary bottom flux. Both levels pass with deterministic output. This restricted direct-solver check does not exercise the FMR transaction or drainage/macropore/snow source routes. For the current FMR sign convention, positive-downward boundary flux is `-solver_top_flux` and `-solver_bottom_flux`; the node source rate is `qssdi - sum(qdra) - final qrot`. Macropore, snow, and special surface routes may contribute additional terms, so any route-specific term not included must fail closed before reconstruction is used.

Each trial starts from committed salt mass. A rejected water/solute trial discards both candidates; retry recomputes both from committed state and the retry's water fluxes. Acceptance commits one water sink and the matching salt-state candidate. No stress function or Jarvis code owns salt mass. If the source-bound review shows this envelope cannot represent the selected B1.11 `CML` semantics, split the required physics into a new slice before widening it.

### E2: independently testable salinity response

Implement the selected response as a pure process that reads an authorized candidate concentration view and returns nodewise factors. It must not mutate concentration, salt mass, root water mass, or continuation state.

For Maas-Hoffman, use analytical oracles for no stress, onset, partial reduction, zero-floor saturation, boundary values, negative/nonfinite concentration, invalid parameters, uniform concentration on different node grids, and deterministic replay. Require $0 \\le \\alpha_{\\mathrm{sol}} \\le 1$, monotone non-increase with concentration, and nodewise bounds.

Treat osmotic-head mode separately. Do not call it a second multiplicative factor. It remains blocked until the Jong-van-Lier authority and its source/state/transaction conditions are satisfied.

Current local oracle run covers the Maas-Hoffman routine only. The routine is not admitted and E2 is not considered fully qualified until the concentration provenance and state/transaction contract are accepted.

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
- Local production-source prototype changes: mobile salt-state/transport owner and independent Maas-Hoffman response; no reference source changes
- Persisted: reconstruction, restricted E1 contract, implementation, tests, and local prequalification manifest
- Tested: focused O0/O2 local gates and a restricted real Reference Richards face-flux closure check pass; this is not qualification
- Qualified/admitted: no; canonical PR base still has no salinity implementation
- Next action: bind the restricted FMR accepted-substep trace to a candidate salt state in the shared physical transaction and explicit clone/restart layout. Add the salt candidate only with independent salt mass closure and accepted/trial/discard/retry/restart tests. Keep the special routes fail-closed. Qualify the independent salinity response with authorized salt state before integrating it into Jarvis.

### Runtime transaction/restart audit (2026-10-04)

`docs/audits/PPA_WU05E_RUNTIME_TRANSACTION_BOUNDARY.md` records a source-backed audit of the kernel commit, FMR physical-state cloning, Restart v2 payload and layout validation, and the committed crop root-uptake adapter. It finds that the current salt candidate has no kernel provenance or restart owner, and that a separate salt commit would not be atomic with the water state. It also records the state-layout coexistence issue: a salinity-only physical subtype is insufficient unless clone, layout validation, and restart cover combinations with existing optional physical continuations.

The audit does not qualify E1 transport or alter the D2 compositor. The branch design decision in `docs/audits/PPA_WU05E_STATE_LAYOUT_DECISION.md` selects an optional typed salt component inside the existing per-column physical object, with an independent salt-layout discriminator in template/restart identity. The generic kernel commit remains the sole state transition. Implementation and qualification must show synchronized water/salt revision and restart behaviour before any crop salinity view or Jarvis integration is added.

### Restricted live Richards continuity and FMR transaction checks (2026-10-04)

`tests/fpm/test_ppa_wu05e_real_water_face_closure.f90`, compiled and run as part of `tests/fpm/run_ppa_wu05a26_real_richards_binding.sh`, verifies the face-flux recurrence against the admitted Reference Richards solver's candidate water storage and independently reported top/bottom boundary rates. It passes at O0 and O2 and the output is identical. The fixture includes separate nonzero subsurface source and root-sink terms, so the reconstruction's source/sink signs are checked in a real solve. Drainage and other FMR-owned source routes remain excluded.

The broader A8 serialized FMR fixture now passes O0/O2 after both macropore test fixtures explicitly set `matrix_area_fraction=1.0` as a fixture-local assumption. The A7 live FMR trial accepts a nonzero final-node root sink (`qrot=2e-4`), closes the transaction water receipt at approximately `5.7e-16 cm`, and passes candidate discard, replay, commit, and restart checks. This resolves the earlier `MASS_REJ=41` fixture failure: storage accounting had been incomplete because the activated test macropore geometry omitted its matrix area fraction. No production default was added.

This transaction result now includes a restricted accepted-substep trace produced inside the FMR attempt. It records each accepted Richards physical substep's start/end water, exact root sink, top/bottom boundary rates and node source/sink terms. The A7 test receives both accepted halfsteps, reconstructs and closes each substep's internal face flux (maximum continuity residual 4.76e-13 cm/day), verifies the exact nonzero qrot, and checks that a discarded attempt does not mutate committed state. A snow-route request is rejected fail-closed. Trace data is attempt-local observation only: it is neither committed nor restart state, and retry/replay plus changed-forcing restart produce identical traces. The trace closes the missing restricted live water-flux producer gate, but it does not connect the salt process or add a salt mass owner. Snow, drainage, rapid macropore outflow, fixed-weir and other special routes remain excluded or fail-closed; no complete solute transport or Jarvis salinity integration is claimed.
