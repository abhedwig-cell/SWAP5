# F-PE-ELASTIC59 — mode-7 defect-certificate cost result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic59-certificate-cost`

Qualified postimage:
`09f3c268f3ce7c48565c834d70ed6537a982d109`

Canonical baseline:
`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

Workflow run:
`36706314506`

Job:
`109857289292`

Conclusion:
SUCCESS.

## Question

What is the runtime cost of the mode-7 defect certificate relative to the full
Reference nonlinear solve, and does that cost erase the solver-work reduction
introduced by active ELAS?

## Frozen benchmark case

Profile:
`3030` / `gY30`.

State/forcing:
- h0 = +10 cm;
- delta = +0.05 cm/day;
- dt = 0.015625 day;
- bottom mode 7;
- swkimpl=0;
- explicit fixed-flux top boundary.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

The profile retention materialization, generated Ss, solver and research
mode-7 defect indicator are identical to the qualified ELASTIC55/58 path.

## Functional cost shape

For all three regimes the certificate adds:
- exactly one tridiagonal defect solve;
- zero additional nonlinear solves.

O0/O2 functional classifications and counters agree.

Untimed reference full-solve work:

### OFF

- nonlinear iterations: 11;
- Jacobian builds: 11;
- linear solves: 11;
- backtracking attempts: 38.

### FIXED_1E6

- nonlinear iterations: 3;
- Jacobian builds: 3;
- linear solves: 3;
- backtracking attempts: 3.

### GENERATED

- nonlinear iterations: 2;
- Jacobian builds: 2;
- linear solves: 2;
- backtracking attempts: 2.

This confirms that the difficult saturated case has a large ELAS-related
nonlinear-work reduction before certificate cost is considered.

## O2 timing

Seven replicas were used for each operation/regime.

Medians:

| regime | solve only ns | indicator only ns | solve + indicator ns |
|---|---:|---:|---:|
| OFF | 52,056.8 | 2,716.7 | 55,028.9 |
| FIXED_1E6 | 4,474.6 | 1,525.4 | 6,193.6 |
| GENERATED | 3,521.8 | 1,527.9 | 5,230.3 |

These are CI-local observations, not portable hardware benchmarks.

## Within-regime overhead

OFF:
- indicator / solve = `0.0522`;
- solve+indicator / solve = `1.0571`;
- measured combined overhead approximately `2.97 microseconds`.

FIXED_1E6:
- indicator / solve = `0.3409`;
- solve+indicator / solve = `1.3842`;
- measured combined overhead approximately `1.72 microseconds`.

GENERATED:
- indicator / solve = `0.4338`;
- solve+indicator / solve = `1.4851`;
- measured combined overhead approximately `1.71 microseconds`.

The relative percentage is larger for active ELAS because the nonlinear solve
itself becomes much cheaper. The absolute certificate cost remains small.

## Cross-regime result

Relative to OFF solve-only:

- FIXED_1E6 solve+certificate:
  `0.11898 x`.

- GENERATED solve+certificate:
  `0.10047 x`.

Thus, in this difficult saturated benchmark:

- FIXED_1E6 including the certificate is about 8.4 times cheaper than OFF
  solve-only;
- GENERATED including the certificate is about 10 times cheaper than OFF
  solve-only.

The extra defect tridiagonal therefore does not erase the large solver-work
benefit associated with active ELAS.

## Hypothesis assessment

H1, indicator cost is small relative to the full nonlinear solve:
SUPPORTED in absolute terms and strongly supported for OFF. Relative overhead is
larger after ELAS has already made the solve very cheap.

H2, indicator adds exactly one tridiagonal and zero nonlinear solves:
SUPPORTED.

H3, active-ELAS solve+indicator remains cheaper than OFF solve-only:
STRONGLY SUPPORTED in this benchmark.

H4, FIXED_1E6 and GENERATED certificate cost are similar:
SUPPORTED. Indicator-only medians are approximately 1.525 and 1.528 microseconds.

## Interpretation

The mode-7 defect certificate has a real but bounded cost.

The relevant production-shaped comparison is not certificate overhead as a
percentage of an already accelerated solve. It is whether the full
solve-plus-certificate path remains economically favorable relative to the
unregularized Reference route.

For this difficult saturated case it does by a wide margin.

Therefore certificate runtime is not the principal remaining blocker for the
active-ELAS temporal-control line.

The remaining blocker is still the missing independently governed physical
temporal budget identified by ELASTIC58.

## Decision

Classification:

`QUALIFIED_LOW_ABSOLUTE_CERTIFICATE_COST_WITH_ELAS_NET_RUNTIME_GAIN`.

No production admission is authorized.

A next production-shaped workunit may qualify fail-closed plumbing of the
mode-7 defect certificate and C-SAFE controller contract while retaining
"no numeric budget => not admitted" semantics.
