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
- Exact source files have now been recovered in the local B1.11 reconstruction and byte-verified against the pinned manifest:
- `solute.f90`: SHA-256 `2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2`, 51,508 bytes; the B1.11 snapshot marks this member unchanged from B0.
- `rootextraction.f90`: SHA-256 `8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5`, 22,013 bytes.
The public SWAP source family remains corroboration only; source-based migration claims below use the byte-verified members and pinned snapshot manifest.

## Exact B1.11 source findings relevant to the next implementation

The reconstructed `SWAP/solute.f90` confirms that the root-extraction input is
mobile concentration `CML`, while the transported inventory is `CMSY`
(dissolved plus adsorbed constituent mass per soil volume). With sorption off,
the initial mobile inventory is `theta*CML); with sorption on, the authoritative
inventory also includes the Freundlich sorption term. The current E1 prototype
is mobile dissolved only, so its qualification must explicitly hold the
no-sorption/single-constituent envelope.

The exact top boundary accumulates salt from precipitation concentration
`CPRE` and irrigation concentration `CIRR` into surface salt storage; pond
infiltration uses the pond concentration and the `1-ArMpSs` split. At the
bottom, `SWBOTBC` selects lateral drainage concentration, a separate constant
`CSEEP`, or a time-varying seepage concentration table. Lateral drainage
uses mobile soil concentration for positive `QDRA`, and `CDRAIN` for negative
`QDRA`. With breakthrough switch `SWBR=1`, `CDRAIN` is a dynamic aquifer
concentration state updated from drainage receipt, aquifer mixing, and decay;
otherwise it is the prescribed input concentration. Thus a single untyped
Cdrain scalar cannot represent every legacy route.

The exact B1.11 root-extraction routine applies Maas-Hoffman
`alpha_sol=max(0,1-(CML-SALTMAX)*SALTSLOPE)` above the threshold and combines
it with wet, dry, and frost stress in the selected total-stress mode before
computing `QROT`. It does so in both microscopic and macroscopic root
extraction paths. Jarvis integration must retain the admitted D2 composition
owner while consuming this factor and must derive `CML` from the same trial
mass and water revision used for `QROT`; it must not feed salinity into Jarvis
as an independent water-mass sink.

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

The apparent legacy labels `CML`, `CMSY`, and concentration are not enough to imply a current SWAP5 equivalent. No admitted SWAP5 salt state with verified legacy equivalence, qualified units/node mapping, mass closure, transaction semantics, or restart contract was found. A provisional typed per-node mass field and Restart v3 layout scaffold have since been added on the work branch; active salt trials still reject, and the scaffold has not passed dedicated clone/restart or mass-coupled transaction qualification.

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
- Transport uses the matching trial's water fluxes and water contents, plus typed solute concentrations for incoming boundary flows. The current explicit upwind prototype uses committed-start mobile concentration for outgoing and inter-node donor fluxes; replacing it with substepped or implicit trial concentration requires its own source review and qualification. Root salt uptake is explicit through `TSCF * qrot_i * CML_i`, with the same candidate root sink that feeds the existing single water-mass receipt. The byte-verified B1.11 source permits `0 <= TSCF <= 10`; process kernels validate that range, without claiming FMR execution or donor-overdraw qualification.
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
- Next action: complete initialization and advancement of the new per-domain macro salt payload, then define typed boundary-salt receipts and bind matrix and macro mass to one FMR candidate/clone/restart lifecycle. The opt-in trace now carries accepted per-domain exchange, matching macro-water volumes and ordered vertical macro faces for the restricted route. Keep unsupported boundary routes fail-closed; prove independent water/salt closure through commit, discard, retry and restart before any Jarvis integration.

### Runtime transaction/restart audit (2026-10-04)

`docs/audits/PPA_WU05E_RUNTIME_TRANSACTION_BOUNDARY.md` records a source-backed audit of the kernel commit, FMR physical-state cloning, Restart v2 payload and layout validation, and the committed crop root-uptake adapter. It finds that the pure salt candidate has no kernel provenance and that a separate salt commit would not be atomic with the water state. Since that audit, the branch added an optional typed mass field to the common FMR physical state, an independent solute-layout identity, clone copying and Restart v3 matching. The serialized trial still rejects active solute layouts; no salt candidate advances in the physical transaction and the new layout has no dedicated roundtrip test yet. It also records the state-layout coexistence issue: a salinity-only physical subtype is insufficient unless clone, layout validation, and restart cover combinations with existing optional physical continuations.

The audit does not qualify E1 transport or alter the D2 compositor. The branch design decision in `docs/audits/PPA_WU05E_STATE_LAYOUT_DECISION.md` selects an optional typed salt component inside the existing per-column physical object, with an independent salt-layout discriminator in template/restart identity. The generic kernel commit remains the sole state transition. Implementation and qualification must show synchronized water/salt revision and restart behaviour before any crop salinity view or Jarvis integration is added. The added state/restart scaffold is not an admitted salt owner until that candidate lifecycle is implemented and tested.

### Restricted live Richards continuity and FMR transaction checks (2026-10-04)

`tests/fpm/test_ppa_wu05e_real_water_face_closure.f90`, compiled and run as part of `tests/fpm/run_ppa_wu05a26_real_richards_binding.sh`, verifies the face-flux recurrence against the admitted Reference Richards solver's candidate water storage and independently reported top/bottom boundary rates. It passes at O0 and O2 and the output is identical. The fixture includes separate nonzero subsurface source and root-sink terms, so the reconstruction's source/sink signs are checked in a real solve. Drainage and other FMR-owned source routes remain excluded.

The broader A8 serialized FMR fixture now passes O0/O2 after both macropore test fixtures explicitly set `matrix_area_fraction=1.0` as a fixture-local assumption. The A7 live FMR trial accepts a nonzero final-node root sink (`qrot=2e-4`), closes the transaction water receipt at approximately `5.7e-16 cm`, and passes candidate discard, replay, commit, and restart checks. This resolves the earlier `MASS_REJ=41` fixture failure: storage accounting had been incomplete because the activated test macropore geometry omitted its matrix area fraction. No production default was added.

This transaction result now includes a restricted accepted-substep trace produced inside the FMR attempt. It records each accepted Richards physical substep's start/end water, exact root sink, top/bottom boundary rates and node source/sink terms. The A7 test receives both accepted halfsteps, reconstructs and closes each substep's internal face flux (maximum continuity residual 4.76e-13 cm/day), verifies the exact nonzero qrot, and checks that a discarded attempt does not mutate committed state. A snow-route request is rejected fail-closed. Trace data is attempt-local observation only: it is neither committed nor restart state, and retry/replay plus changed-forcing restart produce identical traces. The trace closes the missing restricted live water-flux producer gate, but it does not connect the salt process or add a salt mass owner. Snow, drainage, rapid macropore outflow, fixed-weir and other special routes remain excluded or fail-closed; no complete solute transport or Jarvis salinity integration is claimed.


### FMR salt-consumer falsification (2026-10-04)

The opt-in accepted FMR water trace was passed to the ordered mobile-salt trial consumer in the A7 O0/O2 fixture. The actual active-macropore path contains non-root matrix water sources: `net_node_source + root_sink` is nonzero in the accepted halfsteps. The current E1 mobile-salt contract accounts for Richards face advection and root-water uptake, but has no typed source term or solute-concentration contract for that internal water exchange.

The paired candidate therefore returns `SOLUTE_WATER_CLOSURE`. The O0/O2 runner now requires this fail-closed result and verifies that no candidate mass/concentration or partial salt receipt escapes, and that committed salt mass/concentration remain unchanged. This is negative evidence: the current macropore-enabled FMR trace cannot be used as an E1 salt transport interval. It does not qualify salt advancement or a coupled transaction.

The next admissible experiment is a base Richards FMR route with macropore exchange disabled and all other non-root sources zero. If that route cannot be configured without changing admitted behavior, the alternative is a separate explicit mobile/macropore solute-transfer owner with a source concentration/partition contract. Jarvis integration remains blocked until one of these state/mass paths is independently qualified.

### Bounded matrix/macropore transfer kernel

The internal signed exchange arithmetic has now been promoted from a test-only
oracle to the stateless process kernel `src/process/mod_solute_macropore_exchange.f90`.
Its O0/O2 tests cover unequal domain donor concentrations, both transfer signs,
ordered reversal, zero exchange, equal-and-opposite inventory closure, dry or
overdrawn donors, and aggregate matrix donor-water limits. The kernel is
not called from FMR and owns no persistent salt state or route-boundary
receipts. This is a bounded process implementation, not qualification of
macropore solute transport or a coupled transaction.

Source tracing confirms that macro vertical face rates are reconstructed by domain from top inflow, storage change, matrix exchange and rapid outflow. The opt-in accepted FMR water trace now carries those domain/node face rates for the restricted zero-boundary route; A7 requires a nonzero macro face and checks exact retry/replay and fresh-process restart identity. This is water observation data only. Accepted top partition/returned surface water, rapid drainage, covered-top transfer, and any geometry return still need explicit typed salt routing. A typed macro salt-mass payload now has a distinct solute layout and passes in-memory Restart v3 clone/restore checks, but no FMR trial initializes or advances it. Typed boundary receipts remain the next migration boundary; Jarvis stays salinity-disabled.
### Base-route trial diagnostic (2026-10-04)

A local, unpersisted A7 fixture variation disabled macropore physics and its optional state layout while retaining nonzero root extraction and the accepted FMR trace request. Richards subsolves completed, but the full/half transaction did not produce an accepted candidate: the runtime returned canonical status 4 (`CANONICAL_STATUS_SUBSTEP_LIMIT`) after 2,050 temporal rejections, with zero solver rejections and no completed mass receipt. No temporal tolerance was loosened. This diagnostic variation is not part of the pinned passing source postimage and is not a qualification result.

The current work therefore has no demonstrated positive live FMR route for the restricted single-mobile-domain salt ledger: the macropore-enabled route has an unowned internal water/solute exchange, while the attempted base-only route does not pass the existing transaction acceptance gate. The next work must first establish a supported accepted base FMR route within existing tolerances, or define the mobile/macropore solute exchange state and transfer owner and qualify that larger physics boundary.
A second local run of the same macro-disabled fixture reduced the requested interval from 1e-3 to 1e-5 day without changing the acceptance tolerances. It still ended at status 4 after 1,438 temporal rejections, with zero solver rejections. This smaller-step diagnostic likewise produced no accepted water candidate for the salt consumer.

Source inspection explains the substep-limit result. In the pinned FMR backend, `fmr_serialized_temporal_identity` returns `huge()` for the base physical layout whenever the full and half physical states are not exactly identical (pressure head, water content, ponding, groundwater and optional-state identity checks). The Richards full/half states differ, so the transaction rejects them regardless of reducing the requested interval in this experiment. With macropore physics active, a separate evaluator computes a numerical state-distance maximum instead. This is a source-backed execution-policy boundary, not a salinity mass error. A base-layout numerical temporal metric would need its own acceptance authority and qualification; this work does not add one or relax the existing policy.


No water/salt commit or Jarvis salinity integration is justified yet.

### Signed drainage and irrigation process contract (2026-10-05)

The matrix mobile-salt process contract now accepts level-resolved signed
`qdra_rate` and matrix `qssdi_rate` for one substep and the ordered-trace API.
Positive `qdra` exports salt from its donor node at the substep-start CML;
negative `qdra` imports only when an explicit available Cdrain concentration
is supplied. Water closure includes `qssdi - sum(qdra)`, while `qssdi` creates
no salt receipt. Per-level signed salt receipts close the candidate mass
balance. Missing Cdrain authority and late trace failure clear the candidate
and receipts. The process gate passes at O0/O2.

This closes the process-kernel contract gap for these two matrix water routes.
It does not provide FMR with typed salt ownership, connect accepted physical
substeps to the kernel, or qualify candidate commit/discard/retry/restart.
FMR active salt layouts therefore remain fail-closed; Jarvis salinity remains
disabled.

### FMR backend integrity repair (2026-10-05)

Reconciliation against the advancing work branch found that commit
`fc590f6b6` had replaced most of `mod_fmr_serialized_reference_backend.f90`
with a literal truncated-tool-output marker. The branch tip therefore could
not compile. The backend has been restored from the last known-good branch
source at `bf6aaddf0e96b0500dd904351413b46240c13571`; the soil-interface salt
forcing type, source/revision/time/layout validation, and fail-closed trial
gate were then reapplied as a small change. The O0/O2 real-Richards FMR gate
passes again. Active salt trials remain fail-closed pending salt-mass
candidate advancement and its temporal/transaction/restart qualification.

The same source reconciliation preserves the exact B1.11 TSCF range
`0 <= TSCF <= 10`; the mobile-salt process test now covers TSCF above one and
rejects values above ten. The earlier paragraph describing a 0-to-1 envelope
is historical and no longer the current contract.


### Macropore solute boundary audit (2026-10-04)

`PPA_WU05E_MACROPORE_SOLUTE_BOUNDARY.md` records the current source boundary. The accepted FMR water trace carries signed exchange by domain/node, matching macro-water start/end volumes, and ordered per-domain vertical faces; the A7 O0/O2 gate checks nonzero signals, source-sum identity, water closure, and exact retry/replay/restart identity. The stateless exchange kernel passes its O0/O2 arithmetic oracle but is not called by FMR. A typed macro dissolved-salt payload and clone/Restart v3 scaffold now exist, but live initialization/advancement, typed boundary-salt receipts, and atomic FMR candidate ownership remain absent, so the live E1 consumer still fails closed. Preserve PPA-WU05-F for frost.


### Current live prototype follow-up (2026-10-05)

The earlier fail-closed-only findings are historical. The restricted live FMR
salt candidate and same-state Jarvis response have been recovered and advanced.
The current compatibility/storage/initialization contract is
[PPA_WU05E_LIVE_FMR_ENVELOPE.md](PPA_WU05E_LIVE_FMR_ENVELOPE.md); current
implementation and unresolved dependencies are in
`integration/audits/PPA_WU05E_STATUS.json`. Final local evidence is source-pinned
in `PPA_WU05E_FMR_SALT_LOCAL_GATE.json`. No production qualification or canonical
salinity admission is claimed. In-memory restart with a new backend must not
be described as separate-process serialized restart evidence.
