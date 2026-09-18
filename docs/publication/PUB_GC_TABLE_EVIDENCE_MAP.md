# PUB-GC manuscript table evidence map

## Status

**T1–T5 BUILT_AND_LINKED**

Date: 2026-09-18.

This map binds the five journal-neutral manuscript tables to governed evidence. It prevents later formatting or journal adaptation from silently changing scientific content.

| Table | Manuscript role | Primary evidence | Scientific boundary |
| --- | --- | --- | --- |
| T1 | coupling quantities, units, time support and authority | F-GC39–F-GC44 method contracts; PUB_GC_E1_E2_RESULT.json; E4 response identity | definitions and authority, not broad process validity |
| T2 | experiment design and preregistered decision roles | E1–E7 preregistrations and governed result states | design/status overview only |
| T3 | E4 response identity B1–B5 | PUB_GC_E4_RESPONSE_IDENTITY_RESULT.json and E4 derivative evidence | no J_R shown where no symmetric head derivative exists |
| T4 | E5 information-value summary | PUB_GC_E5_INFORMATION_VALUE_RESULT.json / comparison CSV | only 18 cases where cold secant and oracle both converged; B3 excluded from ranking |
| T5 | E6 negative stress-extension summary | PUB_GC_E6_ACTIVE_DRAINAGE_RESULT.json; PUB_GC_E6A_STATE_SCREEN_RESULT.json | component-domain failure is not relabeled as coupling divergence |

## Frozen numerical checks

### T3

- B3 `|J_R|/u_A = 1.0811904795`;
- B5 `J_R` and `J_S` remain unavailable, not zero;
- all `u_A` and `u_FD` values are copied from admitted E4 summary evidence.

### T4

Across the 18 comparable converged E5 cases:

- oracle advantage 0 evaluations: 1 case;
- oracle advantage 1 evaluation: 16 cases;
- oracle advantage >=2 evaluations: 1 case;
- convergence-domain extension versus cold secant: 0 cases;
- supplied `u_A` and zero-cost oracle have identical work count in all 18 comparable cases.

### T5

- active-drainage predictor is mass-complete;
- prescribed-head corrector returns `KERNEL_STATUS_NOT_ADMITTED` before transaction execution;
- E6-A predictors ready: 8 / 20;
- higher-flux predictor failures: 12 / 20;
- symmetric corrector pairs: 4 at ±1e-6 m, 1 at ±1e-5 m, 0 at ±1e-4 m;
- E6-B candidate count: 0.

## Submission rule

Journal formatting may change table layout, significant-figure presentation and placement, but must not:

- convert unavailable values to zero;
- drop bounded-domain failures from denominators;
- broaden a restricted status;
- combine T4 non-comparable B3 cases into algorithm rankings;
- reinterpret the E6 component envelope as outer-coupling instability.
