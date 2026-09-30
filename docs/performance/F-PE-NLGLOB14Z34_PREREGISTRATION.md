# F-PE-NLGLOB14Z34 preregistration — production-shaped moving-interface manager prototype seam

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z33: `QUALIFIED_Z33_READY_FOR_PRODUCTION_SHAPED_MANAGER_PROTOTYPE`;
- Z31R: protocol-correct adaptive driving reaches 540 d in both fine fixtures without a physical blocker;
- Z32: no material same-origin local equation defect is identified;
- deterministic adaptive/full nonlinear work reduction is about 20% across the long qualified fixtures.

## Purpose

Identify and qualify the smallest production/runtime seam for a non-default adaptive moving-interface manager in SWAP Heritage.

Z34 is primarily an architecture and smoke workunit.

It must not become another long O05 micro-attribution study.

## Frozen architectural contract

### Accepted physical state

The existing full-column accepted SWAP state remains the sole physical authority.

The manager may derive a reduced active solve view from that accepted state, but the reduced view is reconstructible scratch only.

No reduced workspace, tail descriptor or active-view object may independently own committed physical state.

### Active solve view

The manager may expose:

- full physical node count;
- active nonlinear node count;
- shallowest reconstructed saturated-tail node;
- interface face;
- reduced-workspace generation;
- fallback reason;
- whether reduced solve was attempted, accepted or bypassed.

### Transaction boundary

The manager participates only inside existing trial/candidate transaction semantics.

Rejected or failed reduced candidates must not mutate:

- accepted h/theta;
- ponding;
- groundwater state;
- provider state;
- mass ledger authority;
- ownership authority.

### Fallback

Exact full-column fallback must remain available and explicit.

Fallback is allowed only as a declared route with typed reason, not as a silent repair of a reduced candidate.

### Defaults

`LEGACY_NUMERICS` remains production default.

The prototype route is research-only/non-default.

## Frozen seam questions

Q1. Is there an existing typed request/result/workspace seam where active nonlinear node count can be carried without changing the full accepted-state shape?

Q2. Can the existing `reference_richards_workspace_t` and linear solver be reused with a reduced `active_nodes` count while preserving a separate full-state authority?

Q3. Is a new manager object required, or can the prototype be expressed as a thin orchestrator around existing request/workspace/result contracts?

Q4. Can fallback reason and active-dimension diagnostics be added without contaminating physical semantics?

Q5. Can a small production-shaped smoke fixture exercise:
- full route;
- reduced route;
- fallback route;
- rollback/no-leak route;
without modifying the production default?

## Frozen implementation preference

Prefer the smallest seam in this order:

1. thin manager/orchestrator module around existing typed solver request/result contracts;
2. extension of existing diagnostics/state-binding types;
3. only if necessary, a new reduced-solve service.

Do not create a parallel solver stack if existing reference workspace/linear solver primitives suffice.

## Frozen smoke qualification

The first Z34 executable smoke must prove:

1. full accepted-state object remains full-column before and after reduced solve;
2. reduced workspace dimension is less than full dimension on an eligible fixture;
3. successful reduced candidate is materialized back into a full candidate state;
4. forced reduced failure leaves accepted state byte-equivalent to origin;
5. explicit full fallback reproduces the full reference candidate;
6. diagnostics expose active dimension and fallback reason;
7. mass/rollback hard gates remain unchanged;
8. `LEGACY_NUMERICS` production default is untouched.

## Frozen classifications

### `QUALIFIED_Z34_MANAGER_SEAM_READY`

Require all architecture questions to have a clean implementation answer and the smoke gates to pass.

### `Z34_MANAGER_SEAM_REQUIRES_SOLVER_CONTRACT_EXTENSION`

Use if existing typed request/result/workspace contracts cannot carry the reduced view without changing accepted-state ownership.

### `Z34_MANAGER_SEAM_TRANSACTION_LEAK`

Use if reduced/fallback trial state leaks into accepted authority.

### `Z34_MANAGER_SEAM_DIAGNOSTIC_AMBIGUITY`

Use if active dimension/fallback ownership cannot be reported unambiguously.

### `Z34_MANAGER_SEAM_SMOKE_FAILED`

Use for executable smoke failure not covered above.

## Performance boundary

Z34 does not claim end-to-end runtime speedup.

Only structural reduced-dimension execution and smoke-level work diagnostics are in scope.

Broader application holdouts and runtime benchmarking are downstream.

## Stop rules

Do not:

- change production defaults;
- relax historical Z30/Z31 gates;
- introduce fitted corrections;
- add mass redistribution;
- add anti-chatter logic;
- create a second accepted-state owner;
- run broad/expensive holdouts before the seam is clean.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z34

BASELINE: `674b60ce16d7d7809bee753e53dcc41d2e3217e8`

BRANCH: `research/f-pe-nlglob14z34-manager-prototype-seam`

NEXT SAFE STEP: static production seam audit, then minimal implementation and smoke qualification only if the existing contracts support it.

## Production boundary

Research prototype only.

`LEGACY_NUMERICS` remains production default.
