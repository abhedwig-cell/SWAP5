# PUB-GC / COUPLE claim–evidence ledger

> **SEMANTIC HOLD — 2026-09-20.** The SWAP5-MODFLOW6 coupling-semantics audit at
> `docs/integration/SWAP5_MODFLOW6_COUPLING_SEMANTICS_AUTHORITY_AUDIT.md` supersedes
> application-level interpretations that equate groundwater coupling with legacy
> `bottom_mode=5`. E1-E5 remain bounded numerical evidence requiring semantic
> reinterpretation; E6 and E7 require coupling-assumption-dependent requalification.
> PUB-GC submission authority is held. Historical experiment records below are
> retained as provenance and must not be read as overriding the semantic audit.


## Purpose

This ledger ties manuscript claims to literature boundaries, repository evidence and still-required publication experiments.

A manuscript claim may be strengthened only when its evidence state changes. The ledger is intended to prevent unsupported prose from getting ahead of the science.

Status vocabulary:

```text
SUPPORTED_RESTRICTED
    demonstrated inside a bounded qualified envelope

SUPPORTED_ARCHITECTURE
    contract and implementation exist, but publication-scale scientific evidence is incomplete

PLANNED_EXPERIMENT
    explicit evidence still required

HYPOTHESIS
    not yet a result

EXCLUDED_NOVELTY
    true or useful, but cannot be claimed as new
```

## Ledger

| ID | Manuscript claim | Literature boundary | Repository evidence | Publication evidence still required | Status |
| --- | --- | --- | --- | --- | --- |
| GC-C01 | SWAP5 and MODFLOW6 can participate in strong coupling while retaining independent solver/state ownership. | Solver autonomy and partitioned coupling are established in FMI/preCICE/IQN literature; novelty cannot be claimed from autonomy alone. | F-GC39, F-GC42, F-GC43, F-GC44 | Demonstrate beyond the restricted F-GC44 case and document exact ownership in manuscript figure. | SUPPORTED_RESTRICTED |
| GC-C02 | Every SWAP corrector in one coupling window can be recomputed from the same immutable accepted origin. | Checkpoint/restore is established generic co-simulation practice. | F-GC39, F-GC43, F-GC44; PUB-GC E1/E2 real rejected-trial probes | Expand beyond the near-equilibrium F-GC44 envelope. | SUPPORTED_RESTRICTED |
| GC-C03 | MODFLOW6 can remain in one prepared nonlinear solve while SWAP replays complete finite-window correctors. | MODFLOW API/XMI and iterative co-simulation are prior art. | F-GC38/F-GC39/F-GC44 | Publication trace of XOLD, X iterates, SWAP trials and convergence over representative cases. | SUPPORTED_RESTRICTED |
| GC-C04 | Coupled convergence requires both groundwater nonlinear convergence and SWAP-groundwater exchange consistency. | Generic coupled-residual criteria are established; hydrological specialization requires evidence. | F-GC39/F-GC44 plus E3/E3-R: valid cases show large loose interface mismatch and 2–5-iteration restoration of the coupled flux criterion; E3-D2 proves higher-flux predictor failure is a bounded SWAP transaction/retry envelope rather than outer-coupling failure. | Still requires an admitted non-trivial hydrological-feedback case; even the 100x-flux E3-R refinement produced at most 1.83e-9 m loose-to-iterative head correction before the long-window corrector envelope became limiting. | SUPPORTED_RESTRICTED |
| GC-C05 | q_bot, q_u and accepted whole-window transfer are physically distinct quantities that must not be silently aliased. | MetaSWAP/HYDRUS-MODFLOW provide strong hydrological prior art; distinction itself must be physically demonstrated for SWAP. | F-GC30/F-GC44 plus PUB-GC E1: q_bot=1e-6 cm/day, q_u=-9.65885e-7 cm/day; accepted rate/ledger amount identity closes in the restricted real case | Repeat under contrasting non-equilibrium states and active-process envelopes. | SUPPORTED_RESTRICTED |
| GC-C06 | Rejected predictor/corrector calculations contribute zero authoritative interface mass. | Rollback exists generically; explicit hydrological mass-authority semantics are candidate contribution. | F-GC41 deterministic failure injection plus PUB-GC E2 real trial/discard/prepublication-abort probes | Add restart/durability evidence and broader process envelopes. | SUPPORTED_RESTRICTED |
| GC-C07 | Accepted interface mass is published exactly once after all preflights pass. | Exactly-once scientific exchange is not a new generic transaction concept; hydrological application requires evidence. | F-GC41–F-GC44 plus PUB-GC E2 publication-order trace and accepted ledger identity | Add restart/durability evidence and combined-system closure in broader cases. | SUPPORTED_RESTRICTED |
| GC-C08 | A finite-window SWAP response can be exposed without exposing the internal Richards Jacobian or timestep controller. | Interface Jacobian/derivative exposure is established in FMI and co-simulation. | F-GC30/F-GC33/F-GC39/F-GC44 plus PUB-GC E4: exposed `u_A` agrees with an independent pure-bottom finite-difference response without exporting the internal Richards Jacobian or timestep sequence. | Black-box learned response is compared separately in E5; it is not required to establish this bounded exposure claim. | SUPPORTED_RESTRICTED |
| GC-C09 | F-GC30/F-GC44 response information has a clear physical relation to storage response J_S and actual exchange response J_R. | Dynamic storage response is established in MetaSWAP and transient-specific-yield literature. | PUB-GC E4: u_A matches independent pure-bottom u_FD; low-flux J_S≈-J_R≈u_A in magnitude; B3 head-driven response is 8.1% stronger; B5 has no symmetric J_R domain. | Treat u_A as a finite-window flux-driven predictor response, not a universal head-to-exchange Jacobian. A later J_B!=0 case may further separate storage and interface interpretations. | SUPPORTED_RESTRICTED |
| GC-C10 | Supplied finite-window response can reduce total coupling work beyond strong black-box multisecant learning in identifiable regimes. | IQN/Anderson, history reuse and surrogate-assisted QN are strong prior art. | PUB-GC E5a: zero-cost J_R oracle saves one SWAP evaluation in 16/18 comparable converged cases, two in one case and zero in one; no convergence-domain extension over cold secant; u_A has the same work pattern. | Result supports modest incremental value only. A separately acquired J_R is not justified by observed work reduction; warm-history E5b is not required by the frozen continuation gate. | SUPPORTED_RESTRICTED — MODEST VALUE, NO STANDALONE ACCELERATE GATE |
| GC-C11 | A weak-coupling regime exists in which sophisticated acceleration is unnecessary for materially changing groundwater head, even when strict interface closure benefits from iteration. | Schüller et al. 2025 makes this a serious null hypothesis, not novelty. | PUB-GC E3 plus E3-R: low-flux and 30–100x higher admitted-flux cases achieve strict closure in 2–5 iterations while loose-to-iterative head corrections remain at most 5.55e-9 m in the original fixture and 1.83e-9 m in the zero-gradient refinement. E6 then failed, by preregistered rules, to create a stronger valid synthetic case: the active-drainage qbot tangent was outside the prescribed-head corrector envelope and the 20-case state/flux screen yielded zero E6-B candidates. | Generalize with E7 through a realistic already admitted hydrological application; do not relax coupling/component tolerances to manufacture a positive strong-feedback case. | SUPPORTED_RESTRICTED |
| GC-C12 | The cell-response reduction preserves the weighted sum of tile-local affine responses at a common reference head. | Linear aggregation is not novelty. Physical aggregation validity is outside this paper. | F-GC40 contract | Executable N:1 qualification and deterministic reduction evidence if included in manuscript. | SUPPORTED_ARCHITECTURE |
| GC-C13 | The same coupling ownership and mass-publication principles can scale to regional execution. | Framework scalability is common in environmental modelling; quantitative evidence required. | Architecture supports composition; F-GC40 gives response reduction | Multi-column live-MODFLOW experiment, scaling curve, deterministic mass closure. | PLANNED_EXPERIMENT |
| GC-C14 | The integrated coupling contract is a transferable contribution beyond one SWAP5 implementation detail. | HydroCouple, MODFLOW API, SWAT+MODFLOW and ParFlow coupling papers show the publication precedent but raise the generalization burden. | Design documents and current implementation | Discussion must extract principles and demonstrate at least one non-trivial hydrological/operational regime beyond the first restricted case. | HYPOTHESIS |
| GC-C15 | A prospectively selected authentic Hupsel application can reach the production participant domain before loose/strong coupling convergence is assessable. | Component-envelope limitations are not unique to SWAP5; novelty lies only in the explicit evidence-bound hydrological classification. | E7 frozen Hupsel selection, M1 whole-Hupsel authority, PPA-WU01 mode-5 production owner, E6 active-drainage precedent, E7 qualification run 35375181814 | No further evidence required for the bounded claim; do not reinterpret as outer-coupling divergence or realistic strong-coupling magnitude. | SUPPORTED_RESTRICTED |

## Explicit non-novelty guard

The manuscript may use the following techniques but must not claim them individually as new:

- fixed-point coupling;
- Aitken relaxation;
- IQN/Anderson multisecant acceleration;
- interface Jacobians or directional derivatives;
- checkpoint/restore;
- autonomous component solvers;
- multirate or adaptive internal timestepping;
- MODFLOW external API control;
- dynamic storage coefficients;
- iterative vadose-zone/groundwater feedback;
- response reuse or refresh;
- N:1 mapping as a software capability.

## Figure/evidence targets

### Figure F1 — coupling ownership and publication boundary

Supports: GC-C01, C02, C03, C06, C07.

Must distinguish:

```text
accepted state
trial computation
coupled convergence
publication preflight
irreversible publication
```

### Figure F2 — hydrological interface quantities

Supports: GC-C05, C09.

Show:

- fixed SWAP coupling plane;
- hydraulic head datum;
- q_bot;
- q_u;
- storage change;
- whole-window V_u.

### Figure F3 — one-window convergence trace

Supports: GC-C03, C04.

Plot:

- MODFLOW nonlinear iterate head;
- q_gw;
- q_swap;
- coupling residual;
- accepted iteration.

### Figure F4 — rejection/retry mass authority

Supports: GC-C06, C07.

Show zero committed mass for rejected attempts and one committed transfer for the accepted attempt.

### Figure F5 — response identity

Supports: GC-C09.

Compare:

```text
u_FD
J_S
J_R
```

across perturbation scale and hydrological states.

### Figure F6 — acceleration information value

Supports: GC-C10, C11.

Compare:

```text
FP
Aitken
IQN cold
IQN warm
zero-cost oracle
practical supplied response
```

using total equivalent SWAP work and failure/convergence domain.

### Figure F7 — realistic Hupsel component-domain result

Supports: GC-C15 and the bounded interpretation of GC-C14.

Show the two frozen standalone dates, their positive drainage evidence, the production mode-5 prescribed-head profile boundary and the preregistered zero-window `REALISTIC_COMPONENT_DOMAIN_LIMIT`. Do not imply that realistic loose/strong corrections or regional groundwater validation were obtained.

## Manuscript stop rules

The central coupling paper remains viable even if GC-C10 is falsified.

However:

- if GC-C05 cannot be resolved physically, the core coupling method is not publication-ready;
- if GC-C06/C07 cannot be demonstrated under retry/restart, the transactional claim must be weakened;
- if the paper contains only the existing near-equilibrium F-GC44 case, the evidence base is too narrow for the intended broader method claim;
- if no non-trivial coupled regime is demonstrated, the manuscript must be framed primarily as a software/model-development paper rather than as a hydrological convergence advance.

## Current next evidence order

1. **E1 closed — SUPPORTED_RESTRICTED** for identity/sign/accounting in the near-equilibrium F-GC44 envelope; retain a targeted non-zero-storage extension.
2. **E2 closed — SUPPORTED_RESTRICTED** for pre-publication rejection/abort and exactly-once successful publication; post-publication durability remains separate.
3. **E3 CLOSED AS SUPPORTED_RESTRICTED.** Main matrix, E3-D predictor envelope, E3-D2 failure mechanism and E3-R stronger-flux refinement are complete. The current fixture is a demonstrated weak-feedback control; a non-trivial positive feedback case remains future evidence, not an open E3 bookkeeping item.
4. **E4 CLOSED — SUPPORTED_RESTRICTED.** The component-supplied `u_A` is identified as a finite-window flux-driven predictor response: it agrees with independent pure-bottom `u_FD`, is not universally interchangeable with head-driven `J_R`, and remains available in B5 where no symmetric local `J_R` is admitted.
5. **E5 CLOSED — SUPPORTED_RESTRICTED.** Acceleration clearly outperforms plain fixed point near/above the fixed-point stability boundary, but the zero-cost J_R oracle provides only modest incremental value over cold secant and no observed convergence-domain extension. The quantitative gate for a warm-history E5b / standalone ACCELERATE continuation was not passed.
6. **E6 CLOSED_NEGATIVE_WITH_BOUNDARIES.** Two preregistered stress routes were exhausted without a valid positive live-coupling case. The F-GC31 active-drainage predictor is valid but its smooth qbot projection is not an admitted prescribed-head corrector profile. The separate 20-case accepted-state/flux screen produced eight predictor-ready cases but zero cases with the required symmetric ±1e-4 m corrector domain; no E6-B candidate was admitted.
7. **E7 CLOSED — REALISTIC_COMPONENT_DOMAIN_LIMIT.** The frozen dates remain 2003-06-17 and 2003-05-20. Both require authentic Hupsel drainage, while the current production prescribed-head groundwater owner rejects `drainage_response_active` before owner-state allocation. Qualification run 35375181814 passes the preregistered component-domain classification; zero loose/strong E7 windows are completed and no physics/tolerance/date/window rescue is permitted.
8. E8 remains deferred and is not required for the current bounded coupling-contract manuscript.

## First publication evidence record

E1/E2 preregistration:

`PUB_GC_E1_E2_PREREGISTRATION.md`

E1/E2 results:

`PUB_GC_E1_E2_RESULT.md`

Machine-readable result:

`PUB_GC_E1_E2_RESULT.json`


## E3 evidence

Consolidated publication result:

`PUB_GC_E3_RESULT.md`

Machine-readable consolidated summary:

`PUB_GC_E3_RESULT.json`


Preregistration:

`PUB_GC_E3_PREREGISTRATION.md`

Initial 48-case result:

`PUB_GC_E3_INITIAL_RESULT.md`

Machine-readable result:

`PUB_GC_E3_INITIAL_RESULT.json`

Post-hoc but separately preregistered predictor-envelope diagnosis:

`PUB_GC_E3D_PREDICTOR_ENVELOPE_PREREGISTRATION.md`


E3-D predictor-envelope result:

`PUB_GC_E3D_PREDICTOR_ENVELOPE_RESULT.md`

E3-D machine-readable result:

`PUB_GC_E3D_PREDICTOR_ENVELOPE_RESULT.json`

E3-D2 failure-mechanism preregistration:

`PUB_GC_E3D2_PREDICTOR_FAILURE_PREREGISTRATION.md`

E3-R stronger-feedback preregistration:

`PUB_GC_E3R_STRONGER_FEEDBACK_PREREGISTRATION.md`

E3-D2 predictor-failure result:

`PUB_GC_E3D2_PREDICTOR_FAILURE_RESULT.md`

E3-D2 machine-readable result summary:

`PUB_GC_E3D2_PREDICTOR_FAILURE_RESULT.json`

E3-R stronger-feedback result:

`PUB_GC_E3R_STRONGER_FEEDBACK_RESULT.md`

E3-R machine-readable result summary:

`PUB_GC_E3R_STRONGER_FEEDBACK_RESULT.json`


## E4 publication evidence

Preregistration:

`PUB_GC_E4_RESPONSE_IDENTITY_PREREGISTRATION.md`

Result:

`PUB_GC_E4_RESPONSE_IDENTITY_RESULT.md`

Machine-readable summary:

`PUB_GC_E4_RESPONSE_IDENTITY_RESULT.json`

Publication table:

`PUB_GC_E4_RESPONSE_IDENTITY_TABLE.csv`

E4 closes GC-C09 only in a restricted sense: the map differentiated by `u_A` is identified, but the simple fixture structurally aliases `J_S` and `-J_R` when `J_B ~= 0`.


## E5 publication evidence

Preregistration:

`PUB_GC_E5_INFORMATION_VALUE_PREREGISTRATION.md`

Analytical pre-result control:

`PUB_GC_E5_LINEAR_CONTROL.md`

Result:

`PUB_GC_E5_INFORMATION_VALUE_RESULT.md`

Machine-readable result:

`PUB_GC_E5_INFORMATION_VALUE_RESULT.json`

Algorithm comparison table:

`PUB_GC_E5_INFORMATION_VALUE_COMPARISON.csv`

E5 closes the current independent ACCELERATE continuation gate. This does not assert that response information is useless; it records that a perfect free local derivative did not show a sufficiently large or general advantage over a competent cold black-box scalar secant comparator to justify a separate acceleration line.


### E4 durable raw evidence

The complete E4 perturbation record is retained under `docs/publication/evidence/`:

- `PUB_GC_E4_RAW_HEAD_SCANS.json` — 5 head scans with all perturbation trials and authority checks;
- `PUB_GC_E4_RAW_FLUX_POINTS.json` — 70 pure-bottom flux points;
- `PUB_GC_E4_FULL_RESULT.json` — full derivative sequences, plateau candidates and selected estimates;
- `PUB_GC_E4_DERIVATIVES.csv` — machine-readable derived head and flux response rows.

This closes the persistence gap left by the expiring Actions artifact and does not alter the E4 scientific conclusion or production semantics.


## E6 publication evidence

Active-drainage preregistration:

`PUB_GC_E6_ACTIVE_DRAINAGE_PREREGISTRATION.md`

Active-drainage result:

`PUB_GC_E6_ACTIVE_DRAINAGE_RESULT.md`

Machine-readable active-drainage result:

`PUB_GC_E6_ACTIVE_DRAINAGE_RESULT.json`

Durable active-drainage raw evidence:

`evidence/PUB_GC_E6_ACTIVE_DRAINAGE_RAW.json`

Accepted-state / predictor-flux screen preregistration:

`PUB_GC_E6A_STATE_SCREEN_PREREGISTRATION.md`

Accepted-state / predictor-flux result:

`PUB_GC_E6A_STATE_SCREEN_RESULT.md`

Machine-readable 20-case result:

`PUB_GC_E6A_STATE_SCREEN_RESULT.json`

Publication summary:

`PUB_GC_E6A_STATE_SCREEN_SUMMARY.csv`

Durable raw 20-case evidence:

`evidence/PUB_GC_E6A_RAW_CASES.json`

Consolidated E6 result:

`PUB_GC_E6_RESULT.md`

E6 closes negatively rather than supplying the previously sought positive strong-feedback synthetic case. This does not make component failure a coupling result; it records that both preregistered routes reached component-admission boundaries before a stronger valid live-coupling experiment was available.

## E7 publication evidence

Prospective execution preregistration:

`PUB_GC_E7_HUPSEL_EXECUTION_PREREGISTRATION.md`

Standalone selection frozen before coupled output:

- `PUB_GC_E7_STANDALONE_SELECTION_RESULT.md`;
- `PUB_GC_E7_STANDALONE_SELECTION_RESULT.json`;
- `PUB_GC_E7_SELECTED_DAYS.csv`.

Closed realistic result:

- `PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.md`;
- `PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.json`;
- qualification run `35375181814`, job `105698080443`;
- Figure F7: `figures/PUB_GC_F7_REALISTIC_COMPONENT_DOMAIN_LIMIT.svg`.

E7 closes under its preregistered `REALISTIC_COMPONENT_DOMAIN_LIMIT` outcome. The selected authentic Hupsel days have positive drainage, but the production prescribed-head owner rejects active drainage before owner allocation. This is a component-domain result, not a completed loose/strong trajectory.

## Manuscript consolidation

Current manuscript:

`PUB_GC_COUPLE_MANUSCRIPT_DRAFT.md`

Figure/table evidence map:

`PUB_GC_MANUSCRIPT_FIGURE_TABLE_PLAN.md`

Consolidation/readiness state:

`PUB_GC_MANUSCRIPT_CONSOLIDATION_STATUS.md`


Standalone selection result:

`PUB_GC_E7_STANDALONE_SELECTION_RESULT.md`

Machine-readable selection:

`PUB_GC_E7_STANDALONE_SELECTION_RESULT.json`
