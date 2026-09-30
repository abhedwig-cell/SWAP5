# F-PE-ELASTIC63 — total-balance representation-floor aggregation result

Date: 2026-09-30

Status: QUALIFIED_NEGATIVE_RESEARCH_RESULT

Branch:
`research/f-pe-elastic63-total-floor-aggregation`

Qualified postimage:
`d153ef3de8799364b4686c4ebdeec6b00291d0e3`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36697783059`

Job:
`109829791759`

Conclusion:
SUCCESS.

## Question

How should node-local P2E07 representation floors be aggregated for diagnosing
the total-balance residual of a heterogeneous Reference Richards column?

ELASTIC63 compared three preregistered diagnostic aggregation rules without
changing any solver, physical or production tolerance:

- A_MAX: `max_i f_i`;
- A_RSS: `sqrt(sum_i f_i^2)`;
- A_SUM: `sum_i f_i`.

## Frozen bank

The complete ELASTIC55 four-profile bank was replayed with direct full and
half1 workspace diagnostics:

- profiles 11060, 10260, 8016, 3030;
- h0 = -75,-20,+2,+10 cm;
- delta = -0.05,-0.035,+0.035,+0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- nine-step dt ladder;
- configured compartment and total balance tolerances = 1e-12 cm/day.

Observed solve states:

- STRICT_SUCCESS: `2016`;
- TOTAL_ONLY_STRICT: `170`;
- LOCAL_ABOVE_STRICT: `1141`;
- OTHER_RETRY: `129`.

O0/O2 semantic identity passed.

The six ELASTIC62 parent cases reproduced their exact floor ratios.

No production source changed.

## A_MAX

Coverage:

### STRICT_SUCCESS

- n = `2016`;
- inside A_MAX floor = `1350`;
- fraction = `66.96%`;
- maximum total/floor ratio = `17.52`.

### TOTAL_ONLY_STRICT

- n = `170`;
- covered = `70`;
- fraction = `41.18%`;
- maximum ratio = `5.294`.

### LOCAL_ABOVE_STRICT

- n = `1141`;
- covered = `606`;
- fraction = `53.11%`.

Interpretation:

A_MAX is too small to explain most TOTAL_ONLY failures, while it still covers
more than half of LOCAL_ABOVE failures.

It therefore fails both sensitivity and discrimination.

## A_RSS

### STRICT_SUCCESS

- covered = `1970 / 2016 = 97.72%`.

### TOTAL_ONLY_STRICT

- covered = `160 / 170 = 94.12%`;
- maximum ratio = `1.464`.

### LOCAL_ABOVE_STRICT

- covered = `832 / 1141 = 72.92%`.

Interpretation:

A_RSS explains nearly all TOTAL_ONLY failures, but it also absorbs almost
three quarters of LOCAL_ABOVE failures.

It is therefore not a sufficiently selective total-balance representation
floor.

## A_SUM

### STRICT_SUCCESS

- covered = `2013 / 2016 = 99.85%`;
- maximum ratio = `1.168`.

### TOTAL_ONLY_STRICT

- covered = `170 / 170 = 100%`;
- maximum ratio = `0.367643`.

### LOCAL_ABOVE_STRICT

- covered = `835 / 1141 = 73.18%`.

### OTHER_RETRY

- covered = `129 / 129 = 100%`.

Interpretation:

A_SUM is a strong deterministic upper scale for representation noise.

It completely explains every TOTAL_ONLY_STRICT state.

However, it is far too permissive as a candidate total-balance convergence
criterion because it would also classify the large majority of
LOCAL_ABOVE_STRICT retries as lying inside the aggregate floor.

Thus A_SUM is useful diagnostically but is not a production tolerance
candidate.

## BALTOL02 diagnostic replay

Retry states:
`1440`.

Residual snapshots that would lie inside the existing BALTOL02 effective rate
based only on the final snapshot:
`602`.

This confirms that current BALTOL02 behavior and representation-floor
aggregation are not equivalent objects.

ELASTIC63 does not change BALTOL02.

## Core result

The three simple aggregation rules expose a structural trade-off:

- A_MAX is selective but misses most genuine total-only representation-floor
  cases;
- A_RSS explains most total-only cases but also swallows most local-residual
  failures;
- A_SUM explains all total-only cases but loses local-failure discrimination.

Therefore the problem is not solved by choosing a scalar profile aggregation of
node-local representation floors alone.

A useful total-balance convergence rule needs additional structure that
distinguishes:

1. signed cancellation of individually representation-scale node residuals;
2. genuine local compartment imbalance.

The local compartment criterion remains essential.

## Hypothesis / evaluation outcome

A_MAX explains TOTAL_ONLY without swallowing local failures:
NOT SUPPORTED.

A_RSS provides useful discrimination:
NOT SUPPORTED.

A_SUM is a valid worst-case diagnostic representation scale:
SUPPORTED.

A_SUM is suitable as a direct total-balance convergence tolerance:
NOT SUPPORTED.

ELASTIC62 parent floor ratios:
REPRODUCED EXACTLY.

## Decision

Classification:

`QUALIFIED_NEGATIVE_SIMPLE_TOTAL_FLOOR_AGGREGATION_RESULT`.

No production tolerance change is authorized.

The next bounded workunit should evaluate a cancellation-aware rule that
retains the strict local compartment gate and only relaxes the total criterion
when:

- every local residual is individually within an independently justified
  representation-scale bound;
- the remaining total residual is consistent with signed cancellation/
  accumulation of those bounded node-local residuals.

That work must remain distinct from the hard physical transaction mass gate.
