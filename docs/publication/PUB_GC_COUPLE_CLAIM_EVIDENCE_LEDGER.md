# PUB-GC / COUPLE claim–evidence ledger

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
| GC-C08 | A finite-window SWAP response can be exposed without exposing the internal Richards Jacobian or timestep controller. | Interface Jacobian/derivative exposure is established in FMI and co-simulation. | F-GC30/F-GC33/F-GC39/F-GC44 plus PUB-GC E4: u_A agrees with an independent pure-bottom finite-difference response without exposing the internal Richards Jacobian or timestep sequence. | Black-box learned response is compared separately in E5. | SUPPORTED_RESTRICTED |
| GC-C09 | F-GC30/F-GC44 response information has a clear physical relation to storage response J_S and actual exchange response J_R. | Dynamic storage response is established in MetaSWAP and transient-specific-yield literature. | PUB-GC E4: u_A matches pure-bottom u_FD; low-flux J_S≈-J_R≈u_A in magnitude; B3 head-driven response is 8.1% stronger; B5 has no symmetric J_R domain. | Treat u_A as a finite-window flux-driven predictor response, not a universal head-to-exchange Jacobian. A later J_B!=0 case may further separate storage and interface interpretations. | SUPPORTED_RESTRICTED |
| GC-C10 | Supplied finite-window response can reduce total coupling work beyond strong black-box multisecant learning in identifiable regimes. | IQN/Anderson, history reuse and surrogate-assisted QN are strong prior art. | No decisive publication result yet | Oracle vs IQN cold/warm, acquisition-cost accounting, regime/generalization tests. | HYPOTHESIS |
| GC-C11 | A weak-coupling regime exists in which sophisticated acceleration is unnecessary for materially changing groundwater head, even when strict interface closure benefits from iteration. | Schüller et al. 2025 makes this a serious null hypothesis, not novelty. | PUB-GC E3 plus E3-R: low-flux and 30–100x higher admitted-flux cases achieve strict closure in 2–5 iterations while loose-to-iterative head corrections remain at most 5.55e-9 m in the original fixture and 1.83e-9 m in the zero-gradient refinement. | Generalize beyond the current near-equilibrium state; the next positive case must change admitted hydrological state or groundwater-response geometry rather than relax coupling tolerances. | SUPPORTED_RESTRICTED |
| GC-C12 | The cell-response reduction preserves the weighted sum of tile-local affine responses at a common reference head. | Linear aggregation is not novelty. Physical aggregation validity is outside this paper. | F-GC40 contract | Executable N:1 qualification and deterministic reduction evidence if included in manuscript. | SUPPORTED_ARCHITECTURE |
| GC-C13 | The same coupling ownership and mass-publication principles can scale to regional execution. | Framework scalability is common in environmental modelling; quantitative evidence required. | Architecture supports composition; F-GC40 gives response reduction | Multi-column live-MODFLOW experiment, scaling curve, deterministic mass closure. | PLANNED_EXPERIMENT |
| GC-C14 | The integrated coupling contract is a transferable contribution beyond one SWAP5 implementation detail. | HydroCouple, MODFLOW API, SWAT+MODFLOW and ParFlow coupling papers show the publication precedent but raise the generalization burden. | Design documents and current implementation | Discussion must extract principles and demonstrate at least one non-trivial hydrological/operational regime beyond the first restricted case. | HYPOTHESIS |

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

### Figure F7 — regional/scaling result

Supports: GC-C12, C13.

Only include if the execution evidence is ready. Do not let this figure imply physical aggregation validity.

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
4. E4 response identity u_FD vs J_S vs J_R.
5. E5 oracle/IQN information-value test.
6. E6 hydrological stress extension.
7. E7 realistic case.
8. E8 scaling only after the scientific core is secure.

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

Result narrative:

`PUB_GC_E4_RESPONSE_IDENTITY_RESULT.md`

Machine-readable result:

`PUB_GC_E4_RESPONSE_IDENTITY_RESULT.json`

Publication table:

`PUB_GC_E4_RESPONSE_IDENTITY_TABLE.csv`

E4 resolves `u_A` as a flux-driven finite-window predictor response and explicitly falsifies the broader assumption that it is automatically identical to the head-driven interface Jacobian `J_R`.
