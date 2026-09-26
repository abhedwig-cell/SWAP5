# F-PE-PROFILE06 — nonlinear-difficulty practical-stack characterization

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent:
`F-PE-PROFILE05R2`

## Trigger

PROFILE05R2 established that the repaired short FGC44 live workload is:

- robust;
- only two coupled iterations;
- speed-positive for A1;
- too easy for A2C to add measurable incremental benefit.

Repeated four-arm timing showed:

- A1 + A2C stack: 13/15 speed-positive, median +3.39%;
- A1 alone: 15/15 speed-positive, median +5.38%;
- A2C alone: median +0.57%;
- stack versus A1: median -3.00%.

The remaining application runtime is still approximately 90% Reference backend.

## Purpose

Find production-shaped Richards/coupled workloads with genuine nonlinear difficulty, then determine whether A2C produces real work reduction and becomes complementary to A1.

PROFILE06 is observation-only.

No `src/**` modification is permitted.

## D1 — exact workload discovery

Use exact/default Reference only.

Search the existing bounded material/regime space:

- B01, B12, O05, O14;
- wet `h0=-10 cm`;
- mid `h0=-75 cm`;
- dry `h0=-500 cm`;
- top forcing factors `-2, -1, 0, +1` relative to initial conductivity;
- durations `1e-4, 1e-3, 1e-2, 5e-2 day`.

The search is diagnostic, not an approximation.

Candidate workloads must:

- converge in exact mode;
- have finite state and flux;
- preserve the existing mass gate;
- require at least 4 nonlinear iterations in one solve, or demonstrate a repeated/multistep exact nonlinear burden materially above the trivial FGC44 route.

Prefer physically interpretable cases over extreme forcing.

## D2 — A2C work-effect screen

For selected exact-stable cases compare exact versus production A2C `1e-8`.

Measure:

- runtime;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking;
- endpoint pressure head;
- water content;
- bottom flux;
- cumulative exchange where multistep;
- mass residual.

A2C advances as a useful difficult-workload mechanism only when measured speedup is accompanied by actual solve-work reduction.

Timing gain without work-counter reduction is observation only.

## D3 — coupled mapping

Only after D2 identifies stable difficult cases with genuine A2C work reduction, map one or more cases into the live mode-5 SWAP + MODFLOW6 seam.

The coupled workload must remain production-shaped:

- finite physically plausible head perturbation;
- no artificial extreme forcing used only to manufacture iterations;
- exact arm stable and repeatable.

## D4 — four-arm difficult coupled comparison

For each admitted difficult coupled case compare:

- exact;
- A1;
- A2C;
- A1 + A2C.

Primary question:

Does A2C add incremental benefit on top of A1 when the Richards solve is genuinely difficult?

## Decision

PROFILE06 closes with a factual workload-dependent stack characterization.

Any newly identified optimization mechanism requires a separate preregistered implementation workunit.
