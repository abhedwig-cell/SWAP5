# PPA-WU05-A4 Richards coupling stabilization characterization

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_CHARACTERIZATION / OUTER_CONTROLLER_STABILIZATION_SUPPORTED`

Workflow run: `36766340685`

Head: `68edacae500359c2caf3b1db957cb300efd4a9e7`

## Purpose

Test whether the two adversarial coupling failures found in the previous A4 matrix can be handled outside the Richards Newton solver by:

1. physical timestep retry/reduction when a frozen-exchange Richards corrector advises retry;
2. bounded outer under-relaxation when the macropore/Richards exchange map oscillates.

No production policy or solver ABI is changed.

## Wet/fresh stiffness — timestep characterization

Adversarial setup:

- B01 hydraulics;
- initial head `-20 cm`;
- fresh sorptivity event;
- research sorptivity scale `2.0`.

Observed first-corrector behavior:

| dt [d] | exchange [cm d-1] | solve status | nonlinear | backtrack |
| ---: | ---: | --- | ---: | ---: |
| 0.100 | 2.3660 | RETRY_ADVISED | 64 | 1116 |
| 0.050 | 3.0455 | CONVERGED | 17 | 31 |
| 0.020 | predictor RETRY | — | — | — |
| 0.010 | 5.4885 | CONVERGED | 52 | 52 |
| 0.005 | 7.2143 | CONVERGED | 24 | 24 |
| 0.001 | 14.6410 | CONVERGED | 13 | 13 |

### Interpretation

Reducing the physical timestep can recover a case that fails at `dt=0.1 d`.

However, convergence difficulty is **not monotone in dt** for this synthetic adversarial setup: the `0.02 d` predictor itself requested retry while both larger `0.05 d` and smaller `0.01 d` cases converged.

Therefore A4 must not encode a claim such as “halving always resolves the coupling.” The correct ownership is:

- Richards reports convergence/retry;
- the outer transaction/timestep controller chooses a permitted retry;
- success is established from the actual rerun, not inferred from dt alone.

## Dry/fresh period-two oscillation — under-relaxation

Adversarial setup:

- initial head `-200 cm`;
- fresh sorptivity event;
- `dt=0.1 d`;
- research sorptivity scale `2.0`.

Undamped outer iteration previously alternated:

`3.9382 -> 0 -> 3.9382 -> 0 -> ... cm d-1`.

With exchange under-relaxation

`q_new = 0.5 q_old + 0.5 q_raw`

the sequence becomes:

1. 3.93818
2. 1.96909
3. 2.27806
4. 2.23252
5. 2.24206
6. 2.24015
7. 2.24054
8. 2.24046
9. 2.24048
10. 2.24047 cm d-1

Relative change falls to:

- ~0.085% by iteration 6;
- ~0.017% by iteration 7;
- ~0.0035% by iteration 8;
- ~0.00014% by iteration 10.

Every damped frozen-exchange Richards corrector converged and combined matrix+macropore mass remained closed.

### Interpretation

The observed period-two coupling oscillation does not require embedding macropore exchange into the Richards Newton Jacobian.

A simple outer damping mechanism is sufficient for this tested adversarial case.

## Research conclusion

The evidence now supports an outer coupling controller with three outcomes:

1. **converged exchange** -> return coupled candidate;
2. **outer oscillation / poor contraction** -> apply bounded damping and continue;
3. **Richards retry/failure** -> reject the coupled attempt and hand control back to the timestep policy.

This preserves solver/execution-policy separation.

## What is not yet fixed

A4 has not yet selected:

- a production damping factor;
- a universal exchange convergence tolerance;
- a fixed maximum corrector count;
- a mandatory timestep reduction factor.

Those belong to subsequent qualification after broader coupled-state impact is measured.

## Provisional controller principle

The strict research reference should use a bounded outer fixed-point loop with:

- convergence assessed on change in the exchange vector;
- optional damping owned by the outer coupling controller;
- solver RETRY propagated outward rather than hidden;
- atomic matrix+macropore candidate publication only after convergence and mass reconciliation.

The practical mode may later stop earlier, but only after its state/flux error has been quantified against the strict route.
