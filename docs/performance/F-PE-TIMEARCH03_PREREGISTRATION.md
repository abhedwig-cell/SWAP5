# F-PE-TIMEARCH03 preregistration — timestep decision attribution and shadow observation

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ad9240fba9bd339fcd0bd456e3e6cbb47e45d152`

Parents:

- TIMEARCH01 — `QUALIFIED_TIMESTEP_ARCHITECTURE_REDESIGN`;
- TIMEARCH02 — `QUALIFIED_EXECUTABLE_TIMESTEP_DECISION_CONTRACTS`.

## Purpose

Measure what currently determines timestep length before changing production semantics.

TIMEARCH03 is observation-only.

The accepted trajectory must remain identical to the current BOFEK Reference harness.

## Observation bank

Use all 20 combinations from the existing repository-backed hydraulic/regime bank:

- B01, B12, O05, O14;
- DRY, TRANSITION, MOIST, WET, POND.

These cases are already exposed and are used only for architecture attribution.

## Current-policy trace

For every attempted interval record:

- origin time;
- nominal controller dt before final-horizon clipping;
- attempted dt;
- whether the requested horizon clipped the attempt;
- nonlinear iterations;
- backtracks;
- Jacobian builds;
- linear solves;
- solver success/failure;
- retry dt when failed;
- accepted-step proposal reason:
  - GROW_LOW_ITER;
  - KEEP;
  - SHRINK_MAX_ITER;
  - GROW_THEN_SHRINK;
- Reference next preferred dt;
- whether the Reference next proposal is ceiling-limited by DTMAX;
- ponding/runoff state.

Every attempt must receive exactly one attempt/retry classification.

## Shadow proposal

After every accepted step compute, observation-only:

`r_h = max_i(|h_i(t1)-h_i(t0)| / max(10 cm, |h_i(t0)|))`

with the previously characterized target `R=0.40`.

Shadow proposal:

`factor = clamp(sqrt(R/max(r_h,1e-12)), 0.5, 2.0)`

`shadow_dt = clamp(accepted_dt*factor, DTMIN, 4*DTMAX)`.

The shadow value never changes execution.

Record:

- shadow dt;
- shadow/reference preferred-dt ratio;
- whether shadow prefers dt > Reference DTMAX;
- whether shadow prefers dt > current Reference next proposal.

This is not a policy qualification.

## Preservation gate

For every case, the traced harness must match the unmodified canonical BOFEK01 Reference harness in:

- accepted steps;
- rejected attempts;
- total nonlinear iterations;
- total backtracks;
- total Jacobian builds;
- total linear solves;
- cumulative runoff;
- terminal top/mid/bottom head;
- terminal ponding;
- terminal storage;
- maximum ledger residual.

Floating comparisons use a scale-aware 1e-12 tolerance for physical outputs; integer diagnostics must match exactly.

## Attribution outputs

Aggregate at minimum:

- accepted-step count;
- rejected-attempt count;
- counts and deterministic work by proposal reason;
- DTMAX-ceiling hit count and fraction;
- horizon/event clamp count and fraction;
- retry count and work;
- fraction of accepted steps where shadow prefers above DTMAX;
- fraction where shadow prefers above current Reference proposal;
- median shadow/reference proposal ratio;
- same metrics by regime.

Deterministic work:

`nonlinear iterations + backtracks + Jacobian builds + linear solves`.

## Architecture interpretation rules

A fixed global ceiling is classified as a material current-policy limiter on this bank if:

- at least 25% of accepted steps are DTMAX-ceiling hits; and
- shadow preference exceeds DTMAX on at least 25% of accepted steps.

This does not mean the shadow proposal is safe.

It only establishes that the current ceiling is materially active.

Hard-event burden is not generalized beyond events actually present in the bank.

If event coverage is insufficient, TIMEARCH03 must explicitly open a separate event-density characterization rather than infer that events are unimportant.

## Advancement

TIMEARCH03 advances if:

1. all 20 traced cases preserve Reference execution;
2. every attempt has typed attribution;
3. no shadow value affects accepted execution;
4. aggregate attribution is complete.

Possible outcomes:

- `QUALIFIED_TIMESTEP_ATTRIBUTION_SEAM`;
- `BLOCKED_TRACE_CHANGES_REFERENCE_EXECUTION`.

No production source change is allowed.
