# F-AHL47 — direct-retention provider research closeout

Date: 2026-09-25

Status: `READY_FOR_PRODUCTION_SHAPED_QUALIFICATION`

Parent production authority: F-PE-PLANVALID01 postimage `df664f56cf09ee8479701f15fe10ee02d31a9536`.

PR: #617.

## Architecture

F-AHL47 keeps the current analytical provider authoritative for:

- full hydraulic evaluation;
- conductivity demand;
- point conductivity;
- all unqualified demand masks.

Only `WATER_CONTENT` and `CAPACITY` demand use the direct-index derivative-consistent retention representation discovered in F-AHL46.

Representation:

- six physical-|h| decade segments over 1..1e6 cm;
- 256 uniform intervals per decade;
- direct threshold-based decade selection;
- direct interval index arithmetic;
- cubic Hermite theta interpolation;
- C is the exact derivative of the same interpolant;
- analytical fallback outside represented domain.

No K approximation is used.

## Single-fixture current-postimage result

The first B01 prescribed-head Reference Richards screen retained the same 4-iteration / 4-backtracking path and reduced paired solve runtime to about 0.69 of the analytical route.

This justified broader qualification.

## Fidelity matrix

Current-postimage 12-case matrix:

- B01, B12, O05, O14;
- wet, mid, dry;
- prescribed-head bottom mode 5;
- Reference Richards;
- explicit conductivity.

Result:

`12 / 12 PASS`

Every case retained:

- the same convergence status;
- identical nonlinear iteration count;
- identical backtracking count;
- mass residual within 1e-12 cm.

Observed maximum head differences ranged from machine-scale to about 1.53e-7 cm.

Observed maximum theta differences remained about 1e-12 or smaller.

Thus the direct-retention representation is path-identical across the bounded 12-case matrix.

## Paired timing matrix

Successful current-head timing workflow authority: run `36152945895`.

Five alternating analytical/candidate pairs per case.

Per-case median candidate/analytical ratios:

| case | ratio |
| --- | ---: |
| B01 wet | 0.738232 |
| B01 mid | 0.740030 |
| B01 dry | 0.701572 |
| B12 wet | 0.738153 |
| B12 mid | 0.705306 |
| B12 dry | 0.745126 |
| O05 wet | 0.736618 |
| O05 mid | 0.698715 |
| O05 dry | 0.740272 |
| O14 wet | 0.782335 |
| O14 mid | 0.734217 |
| O14 dry | 0.734636 |

Across the 12 case medians:

- median ratio: `0.737385476`;
- minimum ratio: `0.698715453`;
- maximum ratio: `0.782335329`;
- speed-positive cases (<0.98): `12/12`;
- speed-negative cases (>1.02): `0/12`.

Interpretation:

- median solver reduction is approximately 26.3%;
- bounded range is approximately 21.8% to 30.1% reduction;
- all reported ratios are shared-runner paired workload measurements, not portable hardware claims.

## Relation to F-AHL44

F-AHL44 showed that the old policy-4 architecture is slower than the current demand-specialized analytical provider.

F-AHL47 demonstrates that the negative result was architectural, not a general failure of representation acceleration.

The key difference is removal of:

- per-call log10 transformation;
- generic interval search;
- logistic reconstruction;
- adaptive K evaluation from the candidate-demand path.

The new representation attacks exactly the current solver demand structure.

## Relation to NEWTON-CANDIDATE01

NEWTON-CANDIDATE01 identified theta-only candidate demand as a major repeated cost under backtracking.

F-AHL47 now provides a current-postimage representation that is materially cheaper for theta/C demand and yields substantial end-to-end Reference-solver gains in the qualified prescribed-head matrix.

This closes the handoff loop from performance profiling to a new representation architecture.

## Why this is not yet a production admission

The current research provider owns a full theta and C table instance.

At 256 intervals per decade and six decades:

- 1,542 nodes per field;
- 2 fields;
- 8 bytes per real;
- about 24.7 kB raw theta/C table payload per hydraulic authority.

Duplicating that payload per column would be unacceptable at large MultiSWAP scale.

The next work must therefore qualify ownership/cache architecture before production admission.

## Next workunit

`F-AHL48 — direct-retention shared immutable representation ownership`

Required questions:

1. Can one immutable direct-retention table be shared per exact hydraulic authority?
2. Can providers hold only a compact handle/pointer without shared-cache sampling overhead in the solve loop?
3. Is build/bind cost amortized and bounded?
4. Is memory scaling proportional to unique hydraulic authorities rather than column count?
5. Can future parallel execution read shared representation state safely without concurrent mutation?
6. Do F-AHL47 fidelity and timing survive the ownership design?

No production routing should be admitted before those questions are closed.

## Verdict

`F-AHL47 = RESEARCH_QUALIFIED_DIRECT_RETENTION_ARCHITECTURE`

`FIDELITY = 12/12 PATH_IDENTICAL`

`TIMING = 12/12 SPEED_POSITIVE, MEDIAN_RATIO_0.737385476`

`NEXT = F-AHL48 OWNERSHIP/CACHE QUALIFICATION`
