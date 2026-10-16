# F-PE-LIVE01 P0 result — exact live difficult-matrix rebaseline

Date: 2026-09-27

Status: `PASS_EXACT_LIVE_COUNTS_LOCALIZED`

PR:
`#656 — F-PE-LIVE01: required live-trial cost rebaseline`

Qualified workflow run:
`36302544440 — F-PE-LIVE01 required live-trial rebaseline`

Job:
`p0-exact-live-matrix`

## Scope

P0 rebaselines the frozen 12-group difficult live MODFLOW6 matrix on the current production-shaped temporal policy lineage.

The instrumented research bridge uses:

- real SWAP/FMR participant trials;
- MODFLOW6 6.8.0 prepared-solve coupling;
- frozen difficult PROFILE06/SOLVE01 material-regime origins;
- both +/-10% accepted-history directions;
- the TEMPORAL08 production policy:
  `budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`;
- BALTOL02 authority;
- exact coupling only;
- no discarded-trial approximation.

No production source is modified.

## Aggregate result

Across the 12 live groups:

- exact SWAP trials: `32`;
- aggregate median coupled-loop time: `9,298,718 ns`;
- transaction calls: `52`;
- accepted substeps: `52`;
- total attempts: `72`;
- retries: `20`;
- solver rejections: `0`;
- temporal rejections: `20`;
- nonlinear iterations: `236`;
- Jacobian builds: `236`;
- linear solves: `380`;
- headcalc calls: `72`;
- backtracking attempts: `236`;
- internal retries: `0`.

Thus all observed transaction retries on this admitted live matrix are temporal retries.

There are no solver-rejection or internal-retry events.

## Regime structure

The exact live demand remains the same structural pattern exposed by SOLVE01:

- B01 mid: 2 trials, no retries;
- B01 wet: 4 trials, 4 temporal retries per history direction;
- B12 wet: 2 trials, no retries;
- O05 wet: 4 trials, 4 temporal retries per history direction;
- O14 mid: 2 trials, no retries;
- O14 wet: 2 trials, 2 temporal retries per history direction.

The two history directions within a material/regime pair have the same discrete solver-work counts.

## Nonlinear work

Total nonlinear work over the 32 exact trials:

- `236` nonlinear iterations;
- `236` Jacobian builds;
- `380` linear solves;
- `236` backtracking attempts.

Mean counts per exact trial over the complete matrix are therefore approximately:

- nonlinear iterations: `7.38`;
- Jacobian builds: `7.38`;
- linear solves: `11.88`;
- headcalc calls: `2.25`;
- temporal retries: `0.625`.

These means describe the frozen matrix only and are not universal SWAP workload statistics.

## Timing boundary

P0 times the whole live coupled corrector loop.

It does not yet isolate:

- time inside `SWAP trial` versus MODFLOW/prepared-solve overhead;
- accepted-direction/tangent cost versus the base q/state solve;
- constitutive/headcalc wall-clock contribution;
- transaction/orchestration wall-clock contribution.

Therefore P0 does not rank those components by cost.

In particular, the fact that all 20 retries are temporal does not prove that temporal retry handling is the largest remaining runtime target.

## P0 interpretation

Three conclusions are justified.

First, the production c=0.65 stack has removed solver-instability noise from this matrix:

- zero solver rejections;
- zero internal retries.

Second, temporal rejection remains active on the wet difficult regimes:

- 20 temporal retries;
- 52 accepted substeps from 72 total attempts.

Third, every unavoidable exact trial still performs substantial nonlinear/directional work:

- 236 nonlinear/Jacobian events;
- 380 linear solves;
- fresh response information is required for the live relinearization path.

## Decision

`ADVANCE_COMPONENT_TIMING`

The next LIVE01 phase must directly time the current exact trial and bound the marginal cost of accepted-direction/tangent production on the same difficult state/head population.

No optimization is admitted or selected by P0 alone.
