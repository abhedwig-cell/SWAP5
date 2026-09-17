# F-DOC21 technical-reference authority matrix

Date: 2026-09-17

This matrix bounds the scientific and numerical claims that F-DOC21 may publish. It is a documentation-control artifact, not a new scientific authority.

## Pinned review denominator

- Frozen Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- Frozen scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- Frozen scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- F-DOC18 historical RB1 physical-science branch head: `bddb43d821fd757a307aad88528464dd0c89a484`
- F-DOC18 qualified conceptual base: F-DOC16 `b0bdf08b5c38771a4ee22c93ed0949f408ceeb2b`

Historical SWAP/F-DOC18 material may establish scientific meaning and a bounded historical formulation. A current SWAP5 implementation claim additionally requires support from the frozen production postimage and accepted Status-A/capability evidence. A legacy manual never proves current implementation by itself.

## Live-canonical reconciliation

F-DOC21 started from canonical `99fa5160d90c296ff5aec5c7f607ffa9e8b7bfd3`. During ACQUIRE, live canonical moved to `786fe5bf59e616dcfa9a86b16b58c67ac0b3b97d` through post-Status-A F-ROSS12 work.

That drift does not change the pinned F-DOC21 scientific review denominator. The exact canonical delta from the F-DOC21 start head touches only F-ROSS12 runtime/solver-selection source, tests, workflows and F-ROSS12 governance. It does not overlap the F-DOC21 documentation or `mkdocs.yml` surface. In particular, post-Status-A ROSS/RossFast solver-selection work is not silently promoted into the frozen Status-A scientific claims documented here.

## Claim ceilings

| Topic | Scientific/formulation authority available | Frozen implementation/evidence available | F-DOC21 claim ceiling | Explicit non-claim / treatment |
| --- | --- | --- | --- | --- |
| Vertical matrix soil-water flow | F-DOC18 `RB1-SW-REFERENCE`: mass conservation + Darcy-Buckingham, 1D Richards equation, upward-positive `z` and hydraulic `q`, restricted `SWSOPHY=0`, `SWKIMPL=0` route | Frozen production baseline contains the admitted reference Richards binding/legacy HeadCalc route; current Status-A traceability/preservation remains controlling for admission | Explain physical balance, sign convention, restricted constitutive/formulation family, compartment discretisation and reference Newton route | Do not generalise to every legacy constitutive switch, macropore route, RossFast, universal tolerance or universal time-step policy |
| ET demand partition | F-DOC18 `RB1-ET-ROOT-SERIAL`; controlled SWAP ET lineage | Frozen `src/process/mod_reference_et_demand_process.f90` implements `SWETR=1`, `SWMETDETAIL=0`, `SWCFBS=0`, `SWINTER=0` restricted partition, returning nonnegative public demands in cm/day | Document the exact restricted reference-ET partition and its input/output units | Do not describe arbitrary meteorological ET methods, interception routes or crop options as admitted |
| Root-water uptake | F-DOC18 drought branch of Feddes response | Frozen `src/process/mod_root_water_uptake_process.f90` implements rooted-compartment partition, demand-dependent `h3`, `h4` cutoff and drought reduction | Explain drought-only root extraction, root-fraction distribution and single mass booking | Do not claim wet/oxygen stress, salinity stress, compensation, process-based root hydraulics or an independent root solver |
| Surface evaporation | F-DOC18 `RB1-SURFACE-EVAP-RESTRICTED`: stateless Darcy-capacity route | Frozen production and current narrative support the restricted `SWINTER=0`, `SWREDU=0` evaluator | Explain ponded/unponded branch, hydraulic-capacity limitation and stateless ownership | Do not admit Black/Boesten-Stroosnijder cumulative routes, interception-dependent alternatives or performance claims |
| Water balance and sign conventions | F-DOC18 states one conservative soil-water balance; current VQ accounting contract supplies a normalization convention | Status-A transaction architecture establishes tentative versus committed accounting and exactly-once accepted-state semantics | Distinguish process-local hydraulic signs from VQ normalized accounting signs; explain storage-change = net external transfer and single-authority accounting | Do not invent a single raw-code sign convention for every legacy/process variable. Where signs differ, adapters/process contracts must translate explicitly |
| Upper hydrological boundary | F-DOC18 establishes the scientific top interface and restricted evaporation lineage | Frozen `src/solver/mod_soil_water_solver_contract.f90` plus `src/solver/mod_b110_dynamic_top_boundary_provider.f90` expose the bounded top flux/head interface and the restricted B1.10 atmospheric/flux/ponding/linear-runoff routes | Explain the boundary interface, surface supply composition, regime switching and accepted-state accounting for the acquired restricted route | No exhaustive historical rainfall, interception, runoff or top-boundary option catalogue |
| Lower hydrological boundary | F-DOC18 establishes the bottom-interface role; Status-A admits Groundwater Coupling v1 | Frozen solver contract exposes bottom flux/head fields; F-GC28 plus the frozen restricted predictor-corrector runtime establish the bounded admitted groundwater composition | Explain the bottom interface, mass-transfer ownership and the admitted predictor/corrector publication semantics | Do not infer broad legacy bottom-boundary modes, arbitrary coupling schedules or unrestricted MODFLOW semantics |
| Drainage | Frozen Drainage-v1 denominator is controlled by F-PM13 and closed by F-PM19 with variant-specific F-VQ authorities | Frozen production includes the restricted single-level linear evaluator and dedicated drainage-family modules; F-PM19 records all eight denominator variants scientifically/runtime qualified or preserved | Document drainage role, exact restricted linear response, fixed eight-variant denominator, balance ownership, transaction/restart/MultiSWAP bounds | Do not infer additional legacy drainage options, reverse exchange, or fully implicit response coupling; do not restate other variant equations until their exact scientific/source authority is stitched |
| Richards discretisation / nonlinear solve | F-DOC18 T6/T7: implicit backward compartment scheme, actual water-content storage difference, internodal Darcy flux, restricted conductivity linearisation, Newton/Jacobian/tridiagonal solve/backtracking | Frozen reference implementation plus current numerical/transaction evidence | Expand reviewer-facing numerical formulation within the frozen reference route | No RossFast promotion, no global true-error theorem, no universal iteration/tolerance claim |
| Time stepping, retry, commit/rollback | Current numerical and Status-A architecture authorities separate solver candidate, assessment, retry and commit | Status-A transaction/preservation evidence | Explain that convergence is necessary but not by itself authority to mutate committed state; rejected trial accounting is non-authoritative | Do not define a new adaptive controller or imply that a performance mode may change physics |
| Groundwater coupling | Status-A Groundwater Coupling v1 capability, F-GC qualification/admission chain | F-GC28 admission plus frozen `src/runtime/mod_groundwater_predictor_corrector_window.f90` and coupling/ledger contracts | Explain restricted predictor/corrector ownership, discard of predictor candidates, accepted corrector publication and paired interface transfer semantics | No broad backend evolution, no arbitrary temporal policy, no claim that head convergence alone proves mass closure |

## Cross-cutting publication rules

1. **Lineage is not admission.** A SWAP manual or historical F-DOC18 statement can explain scientific meaning but cannot independently establish current SWAP5 behaviour.
2. **Frozen code is implementation evidence, not theory.** Source inspection may confirm that a bounded documented formulation is present; theory must still be cited to an accepted scientific authority.
3. **Current Status-A evidence controls admission.** Historical RB1 hashes are not current production locks after Status-A.
4. **No silent scope widening.** If an equation contains generic source/sink terms, only separately admitted terms may be described as active capability.
5. **No invented global conventions.** Hydraulic `q` and VQ normalized accounting have explicitly documented conventions; implementation-local variables must not be forced into one convention without authority.
6. **No duplicate water booking.** Reporting or attribution of a physical transfer does not create a second mass term.
7. **No universal tolerance by prose.** Any numerical or mass tolerance must retain its qualification/provenance authority.

## Acquired publication slice

The acquired authority is now sufficient to publish, without reopening scientific qualification:

- water balance and sign/unit conventions at reviewer-facing level;
- restricted reference ET and drought-only root-water uptake;
- restricted B1.10 upper-boundary semantics and explicit lower-boundary contract framing;
- Groundwater Coupling v1 predictor/corrector ownership and publication semantics;
- Drainage-v1 role, exact restricted linear response and the fixed eight-variant completion denominator;
- additional detail for the existing reference Richards numerical narrative;
- explicit boundaries on what these pages do not claim.

Still deferred are an exhaustive historical top/lower boundary catalogue, detailed equations for the seven non-linear/non-single-level drainage denominator variants, and any post-Status-A solver-selection semantics outside the frozen review denominator.
