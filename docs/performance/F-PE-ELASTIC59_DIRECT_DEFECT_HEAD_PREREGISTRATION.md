# F-PE-ELASTIC59 — direct defect-head characterization preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC58 — QUALIFIED_SAFE_UNSATURATED_HEAD_BUDGET_WITH_SATURATED_EXHAUSTION`

Parent branch head:
`research/f-pe-elastic58-physical-head-budget@56f1af0d5c24e624b0ced84c78f64b598f0850ef`

Canonical authority:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Question

Is the saturated over-conservatism of mode-7 `Binf` primarily introduced by
the final weighted-norm to infinity-norm conversion

`Binf = bounded_M / sqrt(min_mass_weight)`?

## Research observables

Use the same mode-7 defect solve as ELASTIC53-58 and expose, research-only:

- `RAW_HEAD_INF = max(abs(e_raw))`;
- `DEFECT_HEAD_INF = max(abs(delta))`;

where `delta` is the already-computed tridiagonal defect correction.

No second defect solve is added.

The production indicator and result type are unchanged.

## Candidate head-space quantities

Characterize:

- C1 = `RAW_HEAD_INF`;
- C2 = `DEFECT_HEAD_INF`;
- C3 = `2 * DEFECT_HEAD_INF`.

C3 mirrors the existing factor 2 in
`bounded_M = min(raw_M, 2*defect_M)`, but applies it directly in head space.

No candidate threshold or scaling is fitted in ELASTIC59.

## Frozen bank

Replay the exact four-profile ELASTIC55/58 bank:

- profiles 11060, 10260, 8016, 3030;
- states -75, -20, +2, +10 cm;
- perturbations +/-0.035 and +/-0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- nine-step dt ladder;
- bottom mode 7;
- swkimpl=0;
- same retention, geometry, generated Ss, solver and tolerances.

## Comparisons

For every full-converged point record Binf, RAW_HEAD_INF and DEFECT_HEAD_INF.

For every paired full/half point additionally record realized H_INF.

Characterize separately for unsaturated and saturated initial states:

- Binf / H_INF;
- RAW_HEAD_INF / H_INF;
- DEFECT_HEAD_INF / H_INF;
- 2*DEFECT_HEAD_INF / H_INF;
- Binf / (2*DEFECT_HEAD_INF).

## Hypotheses

H1. Saturated `Binf` conservatism is materially larger than direct defect-head
conservatism.

H2. `2*DEFECT_HEAD_INF` remains conservative for most paired observations but
is materially tighter than Binf.

H3. The ratio `Binf/(2*DEFECT_HEAD_INF)` is largest in saturated active-ELAS
cases, consistent with small elastic mass weights driving the current bound.

## Gates

A1. Exact ELASTIC55 profile selection reproduced.

A2. Same 1728 requested physical cases execute.

A3. O0/O2 semantic identity.

A4. Direct head-space observables are finite and nonnegative whenever the
research indicator is available.

A5. No extra nonlinear solve and no extra tridiagonal solve relative to
ELASTIC53.

A6. Frozen 0.01-cm physical head limit is observation-only and unchanged.

A7. Zero `src/**` production changes.

## Decision

ELASTIC59 may qualify or falsify direct defect-head observables as a tighter
research metric.

It does not authorize:
- a production metric;
- a new temporal threshold;
- F-CI14 admission;
- any relaxation of the 0.01-cm head limit;
- any mass-gate change.
