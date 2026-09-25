# F-AHL45 — derivative-consistent direct-index representation screen closeout

Date: 2026-09-25

Status: `CLOSED_NEGATIVE_SCREEN`

Parent: F-AHL44 current-postimage requalification.

## Question

Can the policy-4 scientific representation become performance-positive on the current demand-aware solver merely by replacing irregular-grid interval search with direct indexing?

## Candidate

The screen retained the derivative-consistent representation concept:

- x = log10(-h);
- z = logit(Se);
- cubic Hermite interpolation of z;
- theta reconstructed from z;
- C derived from the derivative of the same interpolant.

The only architectural change was a uniform x grid with direct interval indexing:

`idx = floor((x-xmin)/dx)+1`.

No binary search, shared registry lookup or production provider dispatch was included in the candidate loop.

## Accuracy and timing

Workflow run `36151509807` PASS.

Current analytical theta-only demand, N=60:

- ~2318.84 ns/call.

Direct-index candidates:

| table nodes | max abs theta error | max relative C error, C>=1e-13 | ns/call | ratio vs analytical |
| ---: | ---: | ---: | ---: | ---: |
| 257 | 3.29e-10 | 2.28e-7 | 2757.89 | 1.1893 |
| 513 | 2.06e-11 | 2.85e-8 | 2763.77 | 1.1919 |
| 1025 | 1.29e-12 | 3.56e-9 | 2759.57 | 1.1901 |
| 2049 | 8.04e-14 | 4.45e-10 | 2757.48 | 1.1892 |

All candidates greatly exceed the preregistered fidelity requirements.

None meets the speed requirement `ratio < 0.9`.

The runtime is essentially independent of table density over this range, showing that memory/table size is not the limiting cost in this screen.

## Interpretation

Removing interval search is insufficient.

The remaining direct-index evaluation still performs:

- log10 transform of head;
- Hermite basis arithmetic;
- logit-state reconstruction through exp/logistic;
- derivative reconstruction for C.

For current default-MvG theta-only demand this arithmetic remains more expensive than the analytical water-retention evaluation.

Therefore further densification, cache tuning or binary-search optimization cannot plausibly turn this representation into the desired theta-only acceleration.

## Decision

`F-AHL45 = CLOSED_NEGATIVE_DIRECT_INDEX_SCREEN`

Do not implement this direct-index architecture in production.

Do not reopen table density as a performance knob.

The derivative-consistent representation remains scientifically excellent, but the current MvG analytical theta path is already too cheap for this transform/interpolation architecture to beat.

## Consequence for performance strategy

The NEWTON-CANDIDATE01 hotspot cannot be solved by the current F-AHL table family:

- irregular adaptive table: slower;
- provider-local irregular table: slower;
- uniform direct-index derivative-consistent table: still slower.

The remaining major performance lever is therefore the **number of candidate evaluations**, not making each theta-only MvG evaluation table-based.

Any next exact work should examine solver/backtracking strategy or another generated approximant architecture that avoids the expensive transforms entirely.

A new representation design must first beat analytical theta-only demand in isolation before being integrated into Richards.
