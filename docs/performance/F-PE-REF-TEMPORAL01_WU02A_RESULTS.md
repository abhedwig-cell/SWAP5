# F-PE-REF-TEMPORAL01 WU02A — expanded stress matrix

Date: 2026-09-25

Status: `WU02A_PASS_WITH_ORACLE_LIMIT`

Source head: `0ae7762190574df9436027785fa67e30f20bc9d0`

Workflow run: `36127387499`

## Matrix

24 preregistered cases spanning:

- 2 repository-bound hydraulic parameter sets, including the F-SI39 Hupsel lower-layer authority;
- 2 initial profiles: uniform wet and vertical head gradient;
- flux factors -0.05 and +0.05 relative to local conductivity;
- principal dt: 5e-2, 1e-2 and 1e-4 day;
- prescribed-qbot mode 2;
- one warm-up interval to supply a non-artificial previous right derivative;
- 32-substep refined Reference oracle.

## Classification

- `BOUND_VALID_CONSERVATIVE`: 16
- `BOUND_VALID_NONCONSERVATIVE`: 0
- `REFINED_REFERENCE_INVALID`: 8
- all other preregistered failure classes: 0

The eight invalid cases are exactly all dt=1e-4 cases.

The principal Reference solve and indicator were valid there; the refined oracle failed when the outer interval was divided into 32 substeps. These rows therefore do not provide evidence for or against indicator conservativeness.

## Valid-case conservativeness

For all 16 cases with a valid refined Reference oracle:

- minimum bound/error ratio: 2.94139038;
- maximum bound/error ratio: 108.563803;
- no under-bound case occurred.

The minimum ratio occurred for:

- Hupsel material;
- vertical-gradient profile;
- downward forcing;
- dt=1e-2 day.

Representative lower-margin cases:

| case | material | profile | q factor | dt day | bound cm | refined head error cm | bound/error |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 20 | Hupsel | gradient | -0.05 | 1e-2 | 20.758411 | 7.057346 | 2.941 |
| 23 | Hupsel | gradient | +0.05 | 1e-2 | 21.059092 | 6.913951 | 3.046 |
| 8 | default B110 | gradient | -0.05 | 1e-2 | 17.261345 | 5.221034 | 3.306 |
| 11 | default B110 | gradient | +0.05 | 1e-2 | 17.345147 | 5.190275 | 3.342 |

At dt=5e-2 day the same gradient cases remained conservative with ratios around 4.1-5.2.

Uniform wet cases were much more conservative, with ratios ranging roughly 10-109.

## Interpretation

WU02A strengthens the WU01 result:

- the indicator remained conservative under stronger forcing;
- it remained conservative for nonuniform profiles;
- it remained conservative for a second, high-conductivity Hupsel material;
- the lower safety margin moved from ~2.23 in WU01 to ~2.94 in WU02A, not downward.

This still does not establish a production budget.

The most relevant next targets are now not broader random cases but the apparent lower-margin regime:

- nonuniform profiles;
- wet/intermediate states;
- dt around 1e-2 to 5e-2 day;
- groundwater-relevant prescribed-head mode 5.

## Oracle limitation

The dt=1e-4 rows expose a refined-oracle implementation limitation.

With 32 subdivisions the refined step is 3.125e-6 day. The current Reference solver/harness does not complete those rows under the frozen numerical policy.

Do not reinterpret these failures as temporal-indicator failures.

A future oracle refinement study may use convergence-by-refinement rather than a fixed 32-way split, but that must be preregistered before use.

## Decision

Proceed to WU02B, targeted at the lower-margin regime and mode 5.

Do not select a temporal budget yet.
