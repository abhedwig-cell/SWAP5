# PUB-GC E6-A result — accepted-state and predictor-flux screen

## Status

**PREDICTOR_ONLY_OR_NO_USEFUL_EXPANSION**

Date: 2026-09-18.

Primary evidence:

- source head: `97dba8764ca85c7499cbb2402cf5309447621a66`;
- workflow run: `35360999577` — PASS;
- job: `105651945363` — PASS;
- artifact: `10554314676`;
- artifact digest: `sha256:79dba0e28c8966ae1b0611d0a94d3bc955eb32f61e5961643c6511e073e76ead`.

## Question

After the active-drainage route hit a distinct capability-envelope boundary, E6-A tested whether a stronger but still admitted coupling case could be obtained by changing only the accepted initial wetness state and predictor bottom flux of the existing prescribed-head-compatible fixture.

The selection rule was fixed before output: an E6-B candidate had to be predictor-ready, mass-complete, preserve zero authority under discarded probes, and admit **both** `H_ref - 1e-4 m` and `H_ref + 1e-4 m`. Only then could the highest-flux qualifying state proceed to live coupling.

## Matrix

The screen executed all 20 preregistered combinations:

```text
H0 = -150, -75, -25, -10 cm
q_bot = 1e-6, 1e-4, 1e-2, 1e-1, 1e0 cm/day
window = 1e-3 day
```

Eight cases were predictor-ready: the two lowest fluxes at each of the four initial states.

All twelve cases at `q_bot >= 1e-2 cm/day` failed before producing an accepted whole-window predictor. Their canonical result status was `CANONICAL_STATUS_TRANSACTION_FAILED`; each exhausted the configured retry sequence with mixtures of solver and temporal rejection. No mass-rejection mechanism was observed in these twelve failures.

## Corrector-domain result

No predictor-ready case admitted the required symmetric `±1e-4 m` prescribed-head corrector pair.

Number of predictor-ready cases with a symmetric corrector pair:

| perturbation | cases |
| --- | ---: |
| ±1e-6 m | 4 |
| ±1e-5 m | 1 |
| ±1e-4 m | 0 |
| ±1e-3 m | 0 |

The widest symmetric domain occurred for `H0=-150 cm, q_bot=1e-6 cm/day`, which remained valid through `±1e-5 m`. That is still an order of magnitude smaller than the preregistered E6-B admission requirement.

At the wetter states, the predictor response coefficient increased strongly. For example, at `q_bot=1e-6 cm/day`, `u_A` rose from approximately `6.42e-5` at `H0=-150 cm` to `1.16e-3` at `H0=-10 cm`. This larger predictor response did not translate into a sufficiently broad head-driven corrector domain.

## Deterministic E6-B decision

```text
qualifying_candidate_count = 0
selected_e6b_candidate = null
```

Therefore **no E6-B live-MODFLOW stress case is admitted from this screen**.

This is not a discretionary decision based on a visually disappointing matrix. It follows directly from the preregistered candidate rule.

## Interpretation

Changing accepted wetness state alone can substantially change the finite-window predictor response, but the present synthetic SWAP fixture does not retain enough prescribed-head response domain at the stronger predictor fluxes to support the intended non-trivial live-coupling experiment.

The higher-flux limit is reached in two stages:

1. at `1e-2 cm/day` and above, the predictor itself exhausts the transaction retry budget;
2. among the lower-flux predictor-ready cases, the prescribed-head corrector domain remains narrower than the preregistered `±1e-4 m` requirement.

The experiment therefore supports the same methodological distinction seen in E3 and E4: increasing local response strength is not equivalent to obtaining a valid stronger coupled problem. Component admissibility can become limiting first.

## Next disposition

Per preregistration, E6-B is not constructed from this route. The next scientific step must use a different already admitted hydrological application/profile rather than relax tolerances, widen retry budgets, or tune the state screen after observing the result.
