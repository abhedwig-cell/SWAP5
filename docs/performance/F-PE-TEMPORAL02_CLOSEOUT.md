# F-PE-TEMPORAL02 closeout — difficult corrector temporal-certificate / retry-policy frontier

Date: 2026-09-26

Status: `CLOSED_CHARACTERIZED_NO_POLICY_ADMISSION`

## Question

How does the temporal model-certificate budget control exact difficult same-origin corrector completion, retry behavior and runtime after REPRO02 established a temporal-rejection-initiated retry cascade?

## Scope

TEMPORAL02 is research-only.

The characterized fixture class is:

- difficult PROFILE06 hydraulic materials;
- equilibrium uniform-head origins;
- predecessor right-derivative seeded to zero by the FGC44 test fixture;
- mode-5 prescribed-head same-origin correctors;
- 1e-4 day requested window;
- exact Reference solver;
- fixed retry scale 0.5 and max retries 8.

This scope is important. It is a valid stationary-origin coupling regime, but it is not a proof for arbitrary dynamically evolving production origins.

## Main findings

### P0: budget frontier at +/-0.001 cm

Completion changes sharply with temporal budget:

| budget (cm) | completed |
| ---: | ---: |
| 1e-5 | 1/12 |
| 2e-5 | 4/12 |
| 5e-5 | 4/12 |
| 1e-4 | 4/12 |
| 2e-4 | 8/12 |
| 5e-4 | 12/12 |
| 1e-3 | 12/12 |

At 5e-4 cm, all points complete and aggregate solver rejections fall to zero, though O14-wet still retries temporally.

At 1e-3 cm, all 12 points accept directly with no temporal or solver rejection.

### P1: accepted-path divergence

Relative to the 1e-3 full-step reference arm:

- 5e-4 completes 12/12;
- max terminal |dh| difference = 6.2953412e-5 cm;
- max |dtheta| = 5.9334571e-9;
- max |dq| = 1.1937858e-11 m/s;
- max |d bottom exchange| = 1.0314309e-8 cm.

Thus the completion transition is not accompanied by a large accepted-state discontinuity in this short-window fixture.

### P2/P2R: runtime

Paired/interleaved timing shows:

- ten DIRECT/DIRECT points: median 5e-4 / 1e-3 runtime ratio = 1.00300;
- two O14-wet RETRY/DIRECT points: median ratio = 2.29587.

The larger budget has no material cost where the accepted path is identical. Its speed advantage comes specifically from removing temporal retries.

### P3A/P3B: signed displacement frontier

Confirmed common completing temporal budget:

| |dh| (cm) | common completing budget (cm) |
| ---: | ---: |
| 0.001 | 5e-4 |
| 0.01 | 5e-3 |
| 0.05 | 5e-2 |
| 0.10 | 5e-2 |
| 0.25 | none through 5e-2 |

The immediately stricter tested budget fails at least one signed point for every confirmed frontier.

At +/-0.25 cm, 5e-2 cm completes only 6/12 points.

## Scientific interpretation

The current 1e-5 cm temporal head budget is the controlling cause of the tiny exact participant frontier for these stationary difficult origins.

Relaxing the budget can prevent the temporal-to-nonlinear retry cascade and can materially reduce runtime.

However, the required budget scales strongly with corrector displacement and depends on material, regime and sign. A single larger fixed budget is therefore not justified from these tests.

The 1e-3 cm arm is a useful small-displacement performance candidate, not an accuracy-qualified production setting.

## Why no production admission

TEMPORAL02 does not supply the two pieces of authority needed for a production policy change:

1. **dynamic-history representativeness**
   - the current fixture uses a stationary origin with zero predecessor right-derivative;
   - production origins can carry nonzero temporal history;
   - the budget frontier may shift with that history.

2. **independent refined temporal oracle**
   - 1e-3 accepts the full physical step, but that is not itself a refined temporal truth standard;
   - a fixed-substep or otherwise independently converged Reference oracle is still required to quantify actual temporal state/flux error.

## Decision

TEMPORAL02 closes as a characterization workunit.

No production `src/**` change is admitted.

No new default temporal budget is admitted.

No APPROX04 response surrogate is reopened from this evidence.

## Recommended successor

`F-PE-TEMPORAL03 — dynamic-history and refined-oracle qualification`

That workunit should:

- construct accepted dynamic origins with nonzero predecessor right-derivative;
- preserve production transaction semantics;
- define an independent fixed-substep Reference oracle before candidate evaluation;
- test candidate budget scaling against physical state, flux, mass and runtime error;
- determine whether a fixed, scaled or coupling-specific temporal policy is scientifically defensible.
