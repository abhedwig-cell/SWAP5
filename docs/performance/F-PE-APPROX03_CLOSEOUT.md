# F-PE-APPROX03_CLOSEOUT — practical temporal-effort frontier

Date: 2026-09-26

Status: `CLOSED_NO_TEMPORAL_OPT_IN`

PR:
`#631 — F-PE-APPROX03: practical temporal-effort frontier`

Branch:
`work/f-pe-approx03-temporal-effort`

Parent:
`F-PE-APPROX02`

## Purpose

APPROX03 tested whether relaxing the model-owned temporal acceptance budget could provide another practical performance mode after A1 and A2C.

The approximation axis was kept one-dimensional:

`model_temporal_indicator_budget`

Local Richards convergence tolerances, retry policy, mass tolerance and constitutive physics were held fixed.

## T1 — work-screen result

A prescribed-qbot certificate workload established that temporal acceptance can dominate work in a deliberately refinement-heavy case.

Relative to the exact budget:

- 2x reduced accepted substeps 20 -> 14 and gave about 33% speedup;
- 4x reduced accepted substeps 20 -> 10 and gave about 54% speedup;
- 8x reduced accepted substeps 20 -> 7 and gave about 68% speedup.

T1 was not an admission test because the prescribed lower flux made hydrological exchange error insufficiently informative.

Decision:

`SCREEN_POSITIVE_NOT_ADVANCED`

## T2 — production-relevant prescribed-head frontier

The next line used a state-dependent mode-5 lower boundary, with bottom-face head materialized from the same B1.10 Darcy mapping used by the production coupling route.

Initial frontier cases showed substantial possible work reduction, but increasing temporal budget also increased physical exchange deviation.

## T2A — 2x candidate

The 2x budget was strongly speed-positive on initial selected cases.

However, on a reference-stable B01-wet workload:

- exact/reference committed;
- 2x failed to commit.

Decision:

`REJECTED_REFERENCE_ENVELOPE_ROBUSTNESS`

## T2B — intermediate screen

On the controlling B01-wet workload:

- 1.25x committed 9/9;
- 1.50x, 1.75x and 2.00x failed 9/9;
- 1.25x reduced accepted substeps 3 -> 2;
- nonlinear iterations 21 -> 12;
- HeadCalc calls 6 -> 4;
- runtime gain was of order 10-16% across the observed runs;
- pressure-head and water-content deviations remained very small;
- terminal bottom-flux deviation was about 10.45%;
- storage-change deviation was about 1.35%.

Only 1.25x advanced to the broad qualification matrix.

## T2C — calibrated cross-material qualification

A fixed interval across all materials was rejected as a methodology because some exact/reference arms were themselves unstable.

The final qualification therefore used reference-only workload calibration.

Across 24 material/regime/orientation combinations:

- 5 had a stable exact multi-substep temporal workload in the preregistered interval grid;
- 19 had no usable temporal workload in that grid.

On the five eligible cases, 1.25x:

- committed successfully in all five;
- introduced no candidate-only robustness failure;
- preserved hard mass accounting;
- reduced solve/substep work in only one case;
- was speed-positive in only one case;
- was speed-negative in three cases;
- had median speedup approximately `-0.85%`;
- had minimum observed speedup approximately `-4.0%`.

The one positive case, B01 wet minus, showed:

- accepted substeps 7 -> 6;
- nonlinear iterations 82 -> 63;
- HeadCalc calls 28 -> 21;
- speedup about 16.67%;
- terminal bottom-flux deviation about 0.196%;
- storage-change deviation about 0.252%;
- very small pressure-head and water-content deviations.

The remaining eligible cases did not change their accepted temporal trajectory.

## Scientific interpretation

Temporal acceptance is a potentially large lever only when the exact reference actually performs substantial temporal refinement.

That condition is sparse in the tested production-shaped material/regime space.

Aggressive budget relaxation can be fast but is not transactionally robust.

A conservative 1.25x relaxation is robust on the calibrated reference domain, but usually does not reduce actual work and therefore does not deliver a general runtime benefit.

The apparent large T1 and early T2 speedups must not be generalized to production-wide performance.

## APPROX03 decision

APPROX03 closes without adding a temporal production opt-in.

Reasons:

1. 2x and larger candidates fail robustness;
2. 1.25x survives robustness but fails the broad material-benefit criterion;
3. exact temporal refinement is absent in most tested material/regime cases;
4. application-shaped and coupled qualification is not justified without broad local benefit.

The exact current temporal policy remains production authority.

## Practical performance stack after APPROX03

Retained practical modes remain:

- A1: bounded same-origin tangent cache;
- A2C: strict-practical Richards convergence envelope.

No A3 temporal-budget mode is retained.

## Next performance direction

Further performance work should not continue by simply relaxing the same temporal budget.

A new workunit should first re-profile the combined A1 + A2C practical postimage and identify whether the remaining cost is dominated by:

- unavoidable Richards solves;
- coupling/corrector repetition;
- constitutive work;
- process preparation;
- or external MODFLOW execution.

Any new approximation lever must be separately preregistered.
