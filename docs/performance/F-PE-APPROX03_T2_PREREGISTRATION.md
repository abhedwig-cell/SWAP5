# F-PE-APPROX03 T2 preregistration — prescribed-head temporal-budget frontier

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Parent:
`F-PE-APPROX03`

Predecessor:
`F-PE-APPROX03 T1`

## Rationale

T1 established large temporal-work headroom, but its prescribed-qbot boundary made the lower exchange non-emergent and therefore too weak as a hydrological error test.

T2 moves to the production-relevant state-dependent prescribed-head lower boundary:

- B1.10 Reference Richards;
- serialized transaction execution;
- bottom mode 5;
- model-certificate temporal acceptance;
- non-equilibrium forcing over a finite coupling-style window.

This keeps the approximation axis unchanged while making the physical response informative.

## Fixed numerical policy

T2 varies only:

`model_temporal_indicator_budget`

Reference budget:

`B = 1e-5 cm`

This is the current production mode-5 FGC44 model-certificate budget authority. The earlier `2.5e-11 cm` value was specific to the prescribed-qbot qualification fixture and is not transferred to mode 5.

Research multipliers:

- 1x;
- 2x;
- 4x;
- 8x.

Held fixed:

- local head convergence tolerances;
- compartment and total balance tolerances;
- retry scale;
- max retries;
- nonlinear iteration cap;
- backtracking cap;
- constitutive physics;
- top-boundary forcing for each case;
- bottom prescribed head for each case;
- initial state.

A2C remains OFF during the first T2 frontier so temporal and nonlinear approximations are not confounded.

## Workload discovery

First find a small, physically interpretable set of converged mode-5 cases with actual temporal refinement under the 1x budget.

Search dimensions:

- requested interval: `1e-4`, `5e-4`, `1e-3`, `5e-3`, `1e-2 day`;
- top flux: zero and modest infiltration/evaporation contrasts already inside the Reference solver's stable range;
- prescribed bottom pressure heads close to the hydrostatic lower-node initial head (`-72 cm` in this four-node fixture), using small finite perturbations rather than large artificial jumps.

Do not force refinement with physically extreme boundary jumps.

A discovery case advances only if the 1x arm:

- commits successfully;
- has complete mass accounting;
- has at least 2 accepted substeps;
- has no retry pathology;
- produces finite state and bottom-flux observations.

Prefer several regimes with different temporal difficulty.

## Required frontier metrics

For each selected workload and each budget arm:

### Runtime and work
- wall-clock runtime;
- accepted substeps;
- internal retries;
- nonlinear iterations;
- HeadCalc calls.

### Hydrology
- maximum and final pressure-head difference versus 1x;
- maximum and final water-content difference;
- emergent bottom flux;
- interval bottom exchange;
- storage end and storage change.

### Accounting
- canonical mass residual;
- cumulative net-flow difference where available.

## Advancement rule

A budget multiplier can advance only if:

1. accepted solve/substep work is materially reduced;
2. replicated runtime is lower;
3. transient and endpoint state errors remain bounded;
4. emergent bottom-exchange bias remains bounded;
5. canonical mass accounting remains inside the unchanged hard gate;
6. no new failure or retry pathology occurs.

## Rejection rule

Reject an arm if:

- it gains speed mainly by creating retries elsewhere;
- endpoint agreement hides large transient or exchange error;
- exchange error grows systematically with budget;
- or coupled robustness later deteriorates.

## Production status

T2 is research-only.

No production default or practical temporal mode is admitted by this preregistration.
