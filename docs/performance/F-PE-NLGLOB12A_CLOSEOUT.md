# F-PE-NLGLOB12A closeout — aggregate storage-representation floor

Date: 2026-09-29

Final status:

`NLGLOB12A_AGGREGATE_STORAGE_FLOOR_CONFIRMED`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@4e07091a5dec6e21ece2d7a57f62444a4c25834d`

Qualification authority:

- run `36553184850`;
- job `109356012043`;
- conclusion: SUCCESS.

## Closure

NLGLOB12A closes the observational stagnation-subset attribution positively.

All 8/8 stagnating above-floor endpoint states are already within both:

- aggregate storage-representation resolution;
- local storage-representation resolution.

All existing finite, route, head and ponding guards pass.

The evidence therefore supports a representation-aware exhaustion certificate as the next bounded experiment.

## What this does not mean

It does not mean:

- BALTOL02 should be increased;
- balance tolerances should be relaxed;
- every above-floor state is acceptable;
- the six NLGLOB12 descending cases are covered;
- the TG near-saturation temporal-admissibility failures are covered.

The result is restricted to the 8 stagnation trajectories.

## Direct successor

Open:

`F-PE-NLGLOB12A1 — representation-aware endpoint certificate and test-only replay`.

The certificate must be preregistered before replay and require all of:

1. `R_total_ulp <= 1`;
2. `R_local_ulp <= 1`;
3. existing head guard satisfied;
4. existing ponding guard satisfied when applicable;
5. finite route-consistent state;
6. no process/provider failure;
7. unchanged physical accepted-interval mass closure in replay.

No scalar tolerance multiplier is allowed.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB12A

BASELINE: `4e07091a5dec6e21ece2d7a57f62444a4c25834d`

BRANCH: `research/f-pe-nlglob12a-aggregate-storage-floor-current`

STATUS: closed positive

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `NLGLOB12A_AGGREGATE_STORAGE_FLOOR_CONFIRMED`

NEXT SAFE STEP: preregister NLGLOB12A1 representation-aware replay certificate

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
