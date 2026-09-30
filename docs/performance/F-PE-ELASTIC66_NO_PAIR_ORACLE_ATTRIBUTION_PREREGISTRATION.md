# F-PE-ELASTIC66 — residual no-pair oracle attribution preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC61 — QUALIFIED_TWO_LEVEL_REFERENCE_ORACLE_FALLBACK_WITH_RESIDUAL_SOLVABILITY_BLOCKER`

Parent branch:
`research/f-pe-elastic61-two-level-oracle`

Current canonical authority:
`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

## Question

What exact nested-Reference solvability pattern causes the remaining 12 C-SAFE accepted cases to have no two consecutive successful refinement levels?

## Frozen policy

Do not change:
- alpha = `0.17320259355765216`;
- C-SAFE Binf limit = `0.05773585599727987 cm`;
- head limit = `0.01 cm`;
- theta limit = `1e-5`;
- terminal bottom-flux relative limit = `1%`;
- integrated bottom-exchange relative limit = `0.5%`;
- hard mass acceptance;
- solver tolerances;
- Reference levels N = 2,4,8,16,32,64.

## Scope

Replay the parent 192-sequence bank exactly.

Identify the exact 12 cases for which ELASTIC61 reports `NO_PAIR`.

For each such case report for every N:
- Reference completion;
- independent mass-ledger status;
- terminal solver status where available;
- the resulting success/failure bit pattern across N.

Also report state, forcing, ELAS regime, accepted dt and profile.

## Hypotheses

H1. All 12 cases reproduce on profile 8016 only.

H2. The no-pair condition is caused by isolated successful levels separated by failures, or by at most one successful level, rather than by a physical-envelope failure.

H3. The pattern is regime-independent if elastic storage is inactive along the relevant unsaturated trajectories.

## Gates

A1. Parent replay remains 96 accepted, 96 exhausted, 60 three-level qualified, 24 two-level recovered and 12 no-pair.

A2. Exact 12 no-pair cases are emitted.

A3. Every no-pair case has an explicit six-level success/mass pattern.

A4. O0/O2 controller decision identity is preserved.

A5. Zero production `src/**` changes.

## Decision

This workunit is attribution only.

It may identify a narrower next oracle construction, or establish a genuine Reference-solvability blocker.

It does not authorize:
- tolerance changes;
- non-consecutive oracle pairing;
- budget changes;
- hard-mass relaxation;
- production default head-budget admission.
