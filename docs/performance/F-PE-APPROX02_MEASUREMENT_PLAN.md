# F-PE-APPROX02 measurement plan

Date: 2026-09-26

Status: `OBSERVATION_AND_CONTROLLED_EXPERIMENTS`

Parent:
`F-PE-APPROX01@f3f28542859c0fceb2fc2b80dafd47b1a39049e3`

## Objective

Map the runtime/error frontier of reduced Richards solve effort while preserving exact default behavior.

## First axis

Vary only the nonlinear head convergence tolerance around the current production setting.

Do not change timestep policy, balance tolerances or iteration caps in the same first experiment.

## Initial tolerance sweep

For the existing strict reference value `T`, test research-only multipliers:

- `1x` reference;
- `10x`;
- `100x`;
- `1000x`.

If the fixture's exact default is so strict that all four settings converge identically in one Newton iteration, broaden the workload before broadening the parameter sweep.

## Workloads

Use the production hydraulic material matrix where practical:

- B01;
- B12;
- O05;
- O14;
- wet / mid / dry.

The sweep must include at least one nontrivial transient forcing case where nonlinear iteration count is greater than one under the exact reference. An equilibrium-only fixture is insufficient for admission evidence.

## Metrics

For each candidate record:

- runtime;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- accepted substeps / retries where the transaction layer is used;
- terminal pressure-head profile;
- terminal water-content profile;
- bottom flux;
- storage change;
- mass residual.

Report both absolute and relative deviations against the exact reference.

## Admission boundary

This phase is research only.

No production configuration is changed until a tolerance setting shows:

1. repeatable material runtime gain;
2. bounded hydrological state/flux deviation;
3. acceptable mass-balance behavior;
4. no material failure-rate increase;
5. a clearly documented intended use envelope.

## Default behavior

Exact current behavior remains default and authority.
