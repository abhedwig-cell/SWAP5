# F-PE-PLANVALID01 — exact serialized execution-plan construction closeout

Date: 2026-09-25

Status: `ADMITTED_EXACT_P0`

Repository: `abhedwig-cell/SWAP5`

Production parent: `work/f-pe-zero-waste01@f5ba657695156a936cb3dc8e14669f92d333753b`

Production-source change: `71e34668d15f828734ef7e477ffdf785b0675a43`

Current workunit head at closeout: `4d4e5d90b5933b9914ba1981d4b67b38f4d13d36`

PR: #610

## Problem

PROFILE02 identified one remaining large exact setup hotspot after repeated-runtime zero-waste cleanup.

`fmr_build_serialized_execution_plan()` used the generic construction route for the canonical production-bootstrap layout. That route contained:

- pairwise duplicate validation over templates;
- pairwise duplicate validation over column IDs and state handles;
- insertion-sort execution-order construction;
- per-column linear template lookup.

For the production bootstrap shape with one template record per column, this produced quadratic setup growth.

## Pre-patch baseline

Dedicated direct plan-build baseline, workflow run `36148222000`:

| N | plan-build time |
| ---: | ---: |
| 1 | ~0.095 us |
| 100 | ~8.77 us |
| 1,000 | ~0.881 ms |
| 10,000 | ~108 ms |

The N scaling is consistent with quadratic work.

This is an isolated operation measurement on a shared GitHub runner, not a portable machine-speed claim.

## Exact repair

The admitted repair adds a canonical identity proof before the generic construction route.

The fast path is used only if all of the following hold:

- `state_count >= 0`;
- number of columns equals number of templates;
- template IDs are positive and strictly increasing;
- column IDs are positive and strictly increasing;
- state handles are positive, in range and strictly increasing;
- each column template ID equals the same-position template ID.

Under those conditions:

- template uniqueness is proven linearly;
- column-ID uniqueness is proven linearly;
- state-handle uniqueness is proven linearly;
- sorted execution order is already the identity order;
- template index is exactly the same-position index.

The plan can therefore be materialized directly.

If any proof clause fails, execution falls back to the historical generic validation, sort and lookup path.

The generic path is not weakened or removed.

## Semantic qualification

Dedicated qualification workflow run `36148614461` PASS.

The gate confirms:

- canonical fast path accepted;
- identity execution order retained;
- identity template mapping retained;
- reverse/noncanonical valid columns retain generic sorting;
- reverse/noncanonical templates retain generic lookup;
- duplicate template rejected;
- duplicate column ID rejected;
- duplicate state handle rejected;
- out-of-range state handle rejected;
- nonpositive column/template IDs rejected;
- valid nonidentity column-template mapping remains accepted through generic fallback;
- existing F-PE-ZERO-WASTE01 execution-plan gate PASS;
- historical fallback/failure-timing gate PASS;
- PPA-WU01 O0 PASS;
- PPA-WU01 O2 PASS;
- PPA-WU01 O0/O2 output identity PASS;
- production application bootstrap ownership and fail-closed gates PASS.

The first qualification attempt failed before model execution because shallow checkout did not contain the frozen parent commit used for paired timing. The harness was repaired by explicitly fetching the parent authority. This was a harness failure, not a production or semantic failure.

## Paired direct runtime

Five paired measurements per scale on one runner:

| N | candidate/baseline median ratio | isolated reduction |
| ---: | ---: | ---: |
| 100 | 0.0570 | ~94.3% |
| 1,000 | 0.00835 | ~99.17% |
| 10,000 | 0.00216 | ~99.78% |

At N=10,000 the paired run observed approximately:

- baseline: 56.1 ms/build;
- candidate: 0.105–0.130 ms/build;
- median ratio: ~0.00216.

A separate unpaired candidate run observed ~0.218 ms/build versus ~108 ms in the earlier baseline run. Absolute values vary between shared runners; the paired ratio is the stronger authority.

## Application-level setup effect

Paired production-bootstrap timing workflow run `36148827318` PASS.

### N=1,000

- initialization mean ratio: 0.8053;
- initialization median ratio: 0.8006;
- approximately 20% lower application setup time;
- repeated interval median ratio: 0.9988.

### N=10,000

- initialization mean ratio: 0.3745;
- initialization median ratio: 0.3745;
- approximately 62.5% lower application setup time;
- repeated interval median ratio: 1.0094.

All paired application runs:

- completed every requested column;
- committed every requested column;
- retained identical solver-call, accepted-substep, nonlinear-iteration, Jacobian-build, linear-solve and HeadCalc counts;
- had zero internal retries on the fixture;
- retained zero reported maximum mass residual.

The ~0.9% repeated-runtime difference at N=10,000 is not admitted as a slowdown claim. It is within shared-runner variation and no repeated-path production logic was changed.

## Classification

`A + F`: exact removal of avoidable quadratic structural setup work.

This is not:

- a physics change;
- a solver-policy change;
- a tolerance change;
- a transaction change;
- a coupling-window algorithm change;
- an approximate/practical-mode change.

## Scope

The speedup applies to canonical production-bootstrap execution-plan construction.

Noncanonical registries deliberately retain the generic route. No speed claim is made for those layouts.

The application-level gain is a startup/reinitialization gain. Persistent applications amortize it over many coupling windows.

## Admission

`F-PE-PLANVALID01 = ADMITTED_EXACT_P0_CANONICAL_LINEAR_EXECUTION_PLAN_CONSTRUCTION`

The old quadratic canonical setup path is no longer a priority hotspot.

## Next performance authority

With PLANVALID01 closed, the next selected exact repeated-runtime workunit from PROFILE02 is:

`F-PE-NEWTON-CANDIDATE01`

Its target is the Reference candidate/backtracking compound:

`candidate hydraulic demand -> residual recomputation -> backtracking control`

Any alternative hydraulic representation remains owned by F-AHL.
