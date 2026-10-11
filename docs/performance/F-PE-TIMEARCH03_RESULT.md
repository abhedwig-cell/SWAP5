# F-PE-TIMEARCH03 result — timestep decision attribution and shadow observation

Date: 2026-09-28

Status: `QUALIFIED_TIMESTEP_ATTRIBUTION_SEAM`

Base authority:

`integration/f-ci-canonical@ad9240fba9bd339fcd0bd456e3e6cbb47e45d152`

Current canonical during closeout:

`integration/f-ci-canonical@e78e9094d3c6bb1bbb0816487289299e84b7e7a9`

Canonical drift since preregistration adds TIMEARCH02 closeout documentation only and does not alter the traced BOFEK harness or timestep source.

Primary evidence:

- Actions run: `36420298580`;
- job: `108921115728`;
- paired preservation: PASS for all 20 cases;
- attribution completeness: PASS;
- shadow execution isolation: PASS.

## Preservation

The trace harness exactly preserved the current Reference execution on all 20 hydraulic/regime cases for:

- accepted steps;
- rejected attempts;
- nonlinear iterations;
- backtracks;
- Jacobian builds;
- linear solves;
- cumulative runoff;
- terminal top/mid/bottom head;
- terminal ponding;
- terminal storage;
- maximum ledger residual.

The shadow controller never affected execution.

## Aggregate attribution

Across the bank:

- attempted intervals: 188;
- accepted steps: 186;
- solver retries: 2;
- total deterministic work index: 3259;
- retry work: 64.

Accepted-step proposal reasons:

- GROW_LOW_ITER: 135 steps, work 2008;
- KEEP: 48 steps, work 1091;
- SHRINK_MAX_ITER: 3 steps, work 96;
- GROW_THEN_SHRINK: 0.

Thus the dominant current controller behavior is repeated demand for a larger next step.

## Fixed DTMAX ceiling

Reference next-step proposals reached the DTMAX ceiling on:

- 90/186 accepted steps;
- fraction: 48.4%.

The observation-only normalized shadow controller preferred a timestep above current DTMAX on:

- 78/186 accepted steps;
- fraction: 41.9%.

It preferred a timestep above the actual current Reference next proposal on:

- 82/186 accepted steps;
- fraction: 44.1%.

This satisfies the preregistered criterion for classifying the fixed global ceiling as a material current-policy limiter on this bank.

## By hydrologic regime

### DRY

- DTMAX hit fraction: 62.5%;
- shadow above DTMAX: 65.6%;
- median shadow/reference proposal ratio: about 1.89.

### TRANSITION

- DTMAX hit fraction: 53.1%;
- shadow above DTMAX: 56.3%;
- median shadow/reference ratio: about 1.38.

### MOIST

- DTMAX hit fraction: 68.8%;
- shadow above DTMAX: 46.9%;
- median ratio: about 1.01.

### WET

- DTMAX hit fraction: 28.9%;
- shadow above DTMAX: 26.3%;
- median ratio: about 0.91.

### POND

- DTMAX hit fraction: 38.5%;
- shadow above DTMAX: 26.9%;
- median ratio: about 0.91.

The fixed ceiling is therefore most obviously restrictive in dry and transition regimes, while wet and ponding regimes more often justify conservative stepping.

## Event attribution boundary

The short BOFEK observation bank contains only the requested-horizon clamp as a real scheduler boundary.

Horizon clamps:

- 20/188 attempts;
- fraction: 10.6%.

This bank does not contain representative day, output, detailed-meteo, rainfall-event, irrigation or runon event density.

Therefore TIMEARCH03 does not infer that legacy event scheduling is cheap or unimportant.

A separate event-density characterization is required.

## Architectural interpretation

The user's current DTMAX is not behaving merely as a rare emergency ceiling.

On this representative bank it actively limits nearly half of all accepted next-step proposals.

Meanwhile nonlinear solver failure itself is rare.

This means a substantial fraction of timestep conservatism is policy-imposed rather than directly forced by observed nonlinear difficulty.

That does not prove larger steps are physically safe. Earlier BOFEK and dynamic-top work already shows that some wet transitions are unsafe.

It does prove that a redesigned controller should not treat one global DTMAX as the normal operating selector.

## Decision

TIMEARCH03 advances.

The timestep redesign now has:

1. a qualified architecture decision;
2. executable legacy-compatible decision contracts;
3. a non-invasive attribution seam;
4. evidence that the fixed DTMAX ceiling is materially active.

Required successor:

`F-PE-TIMEARCH04 — hard-event density and scheduler ownership characterization`.

TIMEARCH04 must separate unavoidable time-axis discontinuities from legacy output/day-control artifacts before any production controller replacement.

## Production boundary

No production `src/**` change.

Final classification:

`QUALIFIED_TIMESTEP_ATTRIBUTION_SEAM`.
