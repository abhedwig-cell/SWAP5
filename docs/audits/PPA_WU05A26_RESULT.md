# PPA-WU05-A26 result — bounded RFM serialized-backend dispatch

Date: 2026-10-01
Status: BLOCKED_BY_NODE_HYDRAULIC_HISTORY_CONTRACT
Baseline reconciled against: integration/f-ci-canonical@641a8ba7fad5b67f0ebff7c78dd065270ed46329
Investigated branch head: ae901a9a394e79b103e45393614fc33379ec5c3d

## Reconciliation

A25 is canonically admitted and closed as a bounded candidate-orchestrator primitive. Live backend dispatch remains deliberately not admitted and the A20 RFM NOT_ADMITTED guard remains authoritative.

A26 preregistration correctly requires same-postimage backend dispatch through A11-A25 and the A24 matrix-source seam. The branch addition of source-owned `rfm_surface_forcing_t%event_active` is consistent with A13: event identity must not be inferred from a flux threshold.

## Blocking finding

The live composition currently has no qualified contract that connects A25 node-hydraulic sorptivity derivation to A25 endpoint wall-history state.

`evaluate_rfm_node_sorptivity` is qualified as a node-hydraulic primitive, but `compose_rfm_runtime_candidate` does not consume caller-derived endpoint wall sorptivity. Before evaluating endpoint release it unconditionally assigns:

```fortran
er%accepted_wall_age_day=accepted%wall_age_day
er%wall_sorptivity_cm_sqrt_day=accepted%wall_sorptivity_cm_sqrt_day
```

The admitted RFM state initializer sets `wall_sorptivity_cm_sqrt_day` to zero. Therefore a normally initialized live RFM state has no admitted transition that seeds or refreshes endpoint wall sorptivity from the accepted matrix hydraulic state.

This matters physically. With zero stored wall sorptivity the Philip contribution to endpoint-to-matrix wall exchange is zero. Simply supplying a derived value in `request%endpoint_release%wall_sorptivity_cm_sqrt_day` does not work because the orchestrator overwrites it. Seeding arbitrary values at initialization would introduce hidden caller physics and would not establish the required accepted-state node-hydraulic mapping.

The same ownership question applies to MB wall sorptivity/history: the A25 request carries it, while the dedicated RFM state currently carries endpoint wall history only. A26 must not invent a universal MB history/default.

## Classification

This is an architecture/physics ownership blocker, not a harness defect and not a numerical-parameter failure.

It does not falsify A25's bounded primitive claims. It blocks composing those primitives into a production live backend without changing or extending the admitted contract.

## Required resolution before dispatch

A follow-up contract must explicitly decide and qualify, from the accepted origin only:

1. whether endpoint wall sorptivity is recomputed from accepted matrix node hydraulics each trial or persisted as physical history;
2. if persisted, the exact update/reset rule and restart semantics;
3. how newly wetted endpoints receive their first nonzero sorptivity without arbitrary defaults;
4. the corresponding MB wall sorptivity/history ownership;
5. that retry/replay remains bit-identical and rejected trials do not mutate committed history.

Only after that contract is qualified may A26 wire the A25 candidate into the A24 source seam and consider removal of the A20 guard.

## Decision

```text
A26_BACKEND_DISPATCH = BLOCKED
BLOCKER = NODE_HYDRAULIC_TO_WALL_HISTORY_OWNERSHIP
A25_PHYSICS = NOT_FALSIFIED
A20_RUNTIME_GUARD = KEEP
PARAMETER_TUNING = FORBIDDEN
NEXT = qualify explicit endpoint/MB wall-hydraulic history contract, then resume A26
```
