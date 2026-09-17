# F-GC30 — MODFLOW6 tangent coupling contract and harness

## Status

**PROPOSED / NOT ADMITTED**

This workunit is a starter boundary for the proposed SWAP5–MODFLOW6 coupling. The controlling scientific design note is:

- `docs/science/modflow6-tangent-coupling-proposal.md`

Groundwater Coupling v1 remains the admitted Status-A capability. F-GC30 must not silently reinterpret, replace or broaden that authority.

## 2026-09-17 execution reset

Repeated attempts to prove completeness of the existing analytic/trajectory tangent before implementing F-GC30 caused long dependency-tracing chains and repeated execution timeouts without advancing the coupling capability.

F-GC30 therefore separates **scientific correctness** from **numerical optimisation**.

For F-GC30 v0.1 the canonical response-coefficient route is the historical, independently understandable centered finite-difference construction from one immutable SWAP origin:

```text
q_1 = q_0 - delta_q
q_2 = q_0 + delta_q
u = ((q_2 - q_1) * delta_t) / (H_2 - H_1)
```

The existing SWAP5 analytic/trajectory derivative is **not a prerequisite** for F-GC30 v0.1 and must not block implementation or qualification.

It may later replace the finite-difference calculation only after a separate qualification demonstrates that its derivative covers every active state-dependent production owner relevant to the qualified route and agrees with the centered finite-difference oracle within governed tolerance.

In particular, F-GC30 v0.1 must not reopen broad derivative-coverage investigation of root uptake, drainage or other process owners. Those questions are deferred to a later optimisation/qualification surface.

This reset is an execution-policy decision, not a rejection of the analytic tangent. The centered finite difference is deliberately retained as both:

1. the first scientifically conservative implementation route; and
2. the independent oracle against which any future analytic acceleration must be qualified.

## Baseline

At the execution reset:

- current canonical observed: `integration/f-ci-canonical` at `fc6c4e00d3b94f39dee5a30d68f4c6ef22385f9e`;
- F-GC30 work branch before the reset commit: `work/f-gc30-modflow6-tangent-coupling-contract` at `fb534f089a3fe0803ce94bc8b49d1b7c6ec7bf4d`.

Reconcile only the files and contracts required by the next bounded implementation step. Do not repeat broad groundwater, tangent, drainage or transaction recovery.

## Goal

Prove, with a deterministic groundwater harness, that one accepted SWAP5 state can support:

1. a flux-predictor over one coupling window;
2. centered lower-boundary flux perturbations to derive the coupling/storage response `u`;
3. reconstruction of the MODFLOW-facing exchange flux `q_u`, distinct from native SWAP `q_bot`;
4. repeated head-driven SWAP corrector trials from the same accepted origin;
5. bounded coupled convergence without leaking rejected state;
6. exactly-once accepted interface mass publication.

## Scientific quantities

The workunit must keep these quantities distinct:

```text
q_bot  native/fixed-plane SWAP lower-boundary flux
q_u    MODFLOW-facing exchange/recharge flux
u      coupling/storage response coefficient, approximately delta_storage / delta_head
H      hydraulic head at the fixed SWAP/MODFLOW coupling plane
```

For the predictor perturbations:

```text
q_1 = q_0 - delta_q
q_2 = q_0 + delta_q
u = ((q_2 - q_1) * delta_t) / (H_2 - H_1)
```

with `delta_q` governed and qualified rather than copied uncritically from the historical prototype.

The generic full-profile `accepted_storage_change` is not a substitute for the coupling-specific storage response represented by `u`.

## Required lifecycle

```text
RECONCILE
    |
    v
capture one accepted SWAP origin
    |
    +--> perturbation trial q0-dq --\
    +--> perturbation trial q0+dq ----> derive u
    +--> predictor trial q0 ---------> derive q_u(0)
    |
    v
controlled groundwater outer solve
    |
    v
candidate hydraulic head H(k)
    |
    v
SWAP head-corrector trial from original origin
    |
    v
updated q_u(k)
    |
    +--> repeat within bounded policy if needed
    |
    v
QUALIFY convergence + mass + transaction invariants
    |
    v
ADMIT/CLOSE only after evidence
```

No predictor or corrector result becomes committed authority before final coupled acceptance.

## In scope

- typed representations for `q_bot`, `q_u`, `u` and coupling-window metadata;
- explicit datum, units and sign translation at the boundary;
- predictor perturbation service from one checkpoint;
- finite-difference response diagnostics and failure modes;
- head-driven corrector trials from the same checkpoint;
- bounded outer-iteration harness using a deterministic dummy groundwater backend;
- configurable coupled convergence criteria;
- whole-window exchange accounting and coupling-ledger integration;
- Q1/Q2 scientific and transaction qualification from the controlling design note;
- resumable checkpoints after each meaningful phase.

## Explicitly deferred optimisation

The following is not part of F-GC30 v0.1 admission:

- replacing centered finite difference by F-KT21 or another analytic trajectory derivative;
- proving derivative ownership across root uptake, drainage or other state-dependent production processes;
- performance claims based on eliminating perturbation trials.

A later optimisation may use an analytic derivative only if it is compared against the centered finite-difference result on the same origin, forcing, coupling window and active process composition.

## Out of scope

- production MODFLOW 6 backend;
- Ribasim or surface-water coupling;
- irrigation allocation or pumping implementation;
- regional drainage ownership redesign;
- deep-groundwater/free-drainage fallback;
- concurrent real-physics MultiSWAP coupling;
- new Richards physics;
- solver changes made solely for coupling convenience;
- performance shortcuts that change scientific semantics.

## Hard invariants

1. Every perturbation, predictor and corrector SWAP trial starts from the same accepted origin for the active coupling window.
2. Rejected trials do not mutate committed SWAP state.
3. `q_bot`, `q_u`, `u`, groundwater pumping and irrigation may not be aliased.
4. Hydraulic head and SWAP pressure head require explicit datum-aware translation.
5. Public coupling signs and native solver signs require explicit adapters.
6. One physical transfer is booked exactly once per component and cancels in the combined-system ledger.
7. Only one final accepted candidate contributes committed exchange for a coupling window.
8. Coupling tolerances, perturbation size and iteration budgets are governed execution policy.
9. Missing scientific or backend prerequisites fail closed.
10. Existing Groundwater Coupling v1 evidence remains valid unless a dependency actually changes.
11. Analytic tangent availability alone is insufficient evidence to replace the finite-difference oracle.

## Initial qualification gates

### Q1 — response coefficient

Pass only if:

- centered perturbation is deterministic from one origin;
- `u` is finite and physically admissible for the qualified cases;
- sensitivity to `delta_q` is characterized;
- near-singular `H_2-H_1` handling fails closed;
- coupling-window and coupling-depth dependence are reported rather than hidden.

### Q2 — one column / one groundwater cell

Pass only if:

- coupled mass closes over the accepted window;
- bounded correction reduces the exchange inconsistency relative to predictor-only execution for the selected cases;
- replay from the same origin is deterministic within the qualified contract;
- rollback preserves the accepted origin;
- retry does not duplicate interface mass.

## Bounded execution rule

From the 2026-09-17 reset onward, the next permitted implementation step is intentionally narrow:

1. reuse an existing accepted SWAP checkpoint/origin;
2. execute exactly three non-committing prescribed-`q_bot` trials (`q0-dq`, `q0+dq`, `q0`);
3. expose the two terminal coupling-plane heads and derive `u`;
4. construct a typed predictor response containing at least origin/window identity, `q_bot`, terminal head, `u`, method=`CENTERED_FINITE_DIFFERENCE`, and failure diagnostics;
5. prove that the accepted origin is unchanged after all three trials.

Stop and persist a checkpoint after this step. Do **not** proceed in the same execution chain to MODFLOW/XMI binding, derivative optimisation, irrigation, drainage redesign or broad coupled orchestration.

## Evidence record

Each phase checkpoint should record at least:

```text
CAPABILITY       F-GC30
PHASE            RECONCILE | DESIGN | IMPLEMENT | QUALIFY | ADMIT | CLOSE
BASELINE         canonical branch + exact head
WORK BRANCH      exact branch + exact head
DEPENDENCIES     groundwater v1 / TX / HY / ledger seams used
CHANGES          files and interfaces changed
EVIDENCE         tests, fixtures and immutable outputs
RESULTS          pass/fail with numeric diagnostics
VERDICT          continue | blocked | qualified | admitted | closed
MUTATIONS        commits / PR actions performed
NEXT ACTION      one bounded permitted step
EXCLUSIONS       adjacent issues not pulled into scope
```

## Admission boundary

F-GC30 does not admit MODFLOW 6 itself. It closes only when the coupling scientific contract and transaction semantics are qualified against the controlled harness.

A later workunit may bind a concrete MODFLOW 6 backend only if it preserves the qualified quantities, time support, convergence semantics and accepted-state mass publication established here.
