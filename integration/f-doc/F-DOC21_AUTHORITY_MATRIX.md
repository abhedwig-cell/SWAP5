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

## Claim ceilings

| Topic | Scientific/formulation authority available | Frozen implementation/evidence available | F-DOC21 claim ceiling | Explicit non-claim / treatment |
| --- | --- | --- | --- | --- |
| Vertical matrix soil-water flow | F-DOC18 `RB1-SW-REFERENCE`: mass conservation + Darcy-Buckingham, 1D Richards equation, upward-positive `z` and hydraulic `q`, restricted `SWSOPHY=0`, `SWKIMPL=0` route | Frozen production baseline contains the admitted reference Richards binding/legacy HeadCalc route; current Status-A traceability/preservation remains controlling for admission | Explain physical balance, sign convention, restricted constitutive/formulation family, compartment discretisation and reference Newton route | Do not generalise to every legacy constitutive switch, macropore route, RossFast, universal tolerance or universal time-step policy |
| ET demand partition | F-DOC18 `RB1-ET-ROOT-SERIAL`; controlled SWAP ET lineage | Frozen `src/process/mod_reference_et_demand_process.f90` implements `SWETR=1`, `SWMETDETAIL=0`, `SWCFBS=0`, `SWINTER=0` restricted partition, returning nonnegative public demands in cm/day | Document the exact restricted reference-ET partition and its input/output units | Do not describe arbitrary meteorological ET methods, interception routes or crop options as admitted |
| Root-water uptake | F-DOC18 drought branch of Feddes response | Frozen `src/process/mod_root_water_uptake_process.f90` implements rooted-compartment partition, demand-dependent `h3`, `h4` cutoff and drought reduction | Explain drought-only root extraction, root-fraction distribution and single mass booking | Do not claim wet/oxygen stress, salinity stress, compensation, process-based root hydraulics or an independent root solver |
| Surface evaporation | F-DOC18 `RB1-SURFACE-EVAP-RESTRICTED`: stateless Darcy-capacity route | Frozen production and current narrative support the restricted `SWINTER=0`, `SWREDU=0` evaluator | Explain ponded/unponded branch, hydraulic-capacity limitation and stateless ownership | Do not admit Black/Boesten-Stroosnijder cumulative routes, interception-dependent alternatives or performance claims |
| Water balance and sign conventions | F-DOC18 states one conservative soil-water balance; current VQ accounting contract supplies a normalization convention | Status-A transaction architecture establishes tentative versus committed accounting and exactly-once accepted-state semantics | Distinguish process-local hydraulic signs from VQ normalized accounting signs; explain storage-change = net external transfer and single-authority accounting | Do not invent a single raw-code sign convention for every legacy/process variable. Where signs differ, adapters/process contracts must translate explicitly |
| Upper hydrological boundary | F-DOC18 establishes an admitted top interface and restricted surface evaporation, but does not by itself enumerate the full Status-A top-boundary option set | Current production/evidence is distributed | Describe only boundary-role/accounting concepts already supported; defer detailed option catalogue until exact authority is acquired | No exhaustive rainfall/irrigation/runoff/ponding/interception option table yet |
| Lower hydrological boundary | F-DOC18 establishes an admitted bottom interface; current Status-A includes bounded groundwater gateway/coupling capability | Current production/evidence is distributed across groundwater capability and coupling authorities | Explain the bottom interface as a mass-conserving external boundary and document only explicitly admitted gateway/coupling semantics after targeted acquisition | Do not infer broad legacy bottom-boundary modes or new MODFLOW semantics |
| Drainage | Status-A admits Drainage as a bounded capability; detailed formulation authority is capability-specific | Current capability, qualification/admission and preservation evidence are distributed | Document scientific role and balance ownership only after targeted capability authority acquisition | Do not reconstruct drainage equations from legacy manuals unless reconciled against frozen implementation and admission evidence |
| Richards discretisation / nonlinear solve | F-DOC18 T6/T7: implicit backward compartment scheme, actual water-content storage difference, internodal Darcy flux, restricted conductivity linearisation, Newton/Jacobian/tridiagonal solve/backtracking | Frozen reference implementation plus current numerical/transaction evidence | Expand reviewer-facing numerical formulation within the frozen reference route | No RossFast promotion, no global true-error theorem, no universal iteration/tolerance claim |
| Time stepping, retry, commit/rollback | Current numerical and Status-A architecture authorities separate solver candidate, assessment, retry and commit | Status-A transaction/preservation evidence | Explain that convergence is necessary but not by itself authority to mutate committed state; rejected trial accounting is non-authoritative | Do not define a new adaptive controller or imply that a performance mode may change physics |
| Groundwater coupling | Status-A admits Groundwater Coupling v1 and external gateway boundary in bounded scope | Capability-specific current authorities exist, but exact scientific formulation is distributed | Publish only after targeted acquisition of the current groundwater capability authority | No broad MODFLOW/backend evolution, no unqualified head/flux convergence claim |

## Cross-cutting publication rules

1. **Lineage is not admission.** A SWAP manual or historical F-DOC18 statement can explain scientific meaning but cannot independently establish current SWAP5 behaviour.
2. **Frozen code is implementation evidence, not theory.** Source inspection may confirm that a bounded documented formulation is present; theory must still be cited to an accepted scientific authority.
3. **Current Status-A evidence controls admission.** Historical RB1 hashes are not current production locks after Status-A.
4. **No silent scope widening.** If an equation contains generic source/sink terms, only separately admitted terms may be described as active capability.
5. **No invented global conventions.** Hydraulic `q` and VQ normalized accounting have explicitly documented conventions; implementation-local variables must not be forced into one convention without authority.
6. **No duplicate water booking.** Reporting or attribution of a physical transfer does not create a second mass term.
7. **No universal tolerance by prose.** Any numerical or mass tolerance must retain its qualification/provenance authority.

## Initial publication slice permitted by this matrix

The presently acquired authority is sufficient to publish, without reopening scientific qualification:

- water balance and sign/unit conventions at the reviewer-facing level;
- restricted reference ET and drought-only root-water uptake;
- additional detail for the existing reference Richards numerical narrative;
- explicit boundaries on what those pages do not claim.

Detailed upper/lower boundary catalogues, drainage equations and groundwater-coupling formulation remain `ACQUIRE_REQUIRED` until their exact current authorities are reconciled.
