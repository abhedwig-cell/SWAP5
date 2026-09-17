# P2 E0 experiment design

## Purpose

PUB-P2E01 turns the admitted restricted RossFast E0 envelope into a controlled Reference-versus-RossFast experiment without broadening solver physics.

The objective is not to prove equivalence. It is to establish a reproducible comparison protocol, expose confounding before broad sampling, and freeze the scientific rules before any admissibility conclusion is allowed.

## Experimental principle

A scientific pair must hold the physical problem fixed. The treatment variable is solver identity.

```text
same typed parameter set
same grid and material
same initial physical state
same constitutive/source/boundary providers
same boundary values
same requested step duration
        |
        +--> Reference Richards solver
        |
        +--> RossFast D3R solver
```

If another scientific or numerical acceptance mechanism differs between routes, the result is not a pure solver comparison and must be classified separately.

## Fixed E0 pilot condition

The first case reproduces the admitted F-ROSS12 B01 physical envelope:

- material `B01`;
- 16 active cells;
- 10 cm cell thickness;
- uniform initial pressure head `-101 cm`;
- initial water content from the common B1.10 constitutive provider;
- prescribed top flux `0.01 * K(h0)`;
- prescribed bottom flux `-0.004 * K(h0)`;
- no root extraction, distributed sources/sinks, drainage response, macropores, snow, frost, soil temperature, hysteresis, tabulated hydraulics or elasticity;
- step duration `ROSSFAST_D3R_OUTER_HORIZON_DAY`.

This pilot does not introduce a new RossFast physical domain.

## Stage 0a: solver-seam paired extraction

Stage 0a compares the two concrete `soil_water_solver_t` implementations using one identical `soil_water_solve_request_t`. This removes the transaction controller as a confounder.

The publication test is:

- `tests/publication/test_pub_p2e01_solver_seam_paired_pilot.f90`
- runner: `tests/publication/run_pub_p2e01_e0_paired_pilot.sh`
- workflow: `.github/workflows/pub-p2e01-e0-paired-pilot.yml`

No production source is modified by this experiment.

### Stage 0a result

The paired solver-seam pilot passed under both `-O0` and `-O2`, with identical textual output between optimization levels.

Observed raw B01 pilot quantities:

```text
Reference route                 legacy-reference-bound
RossFast route                  rossfast-d3r
Reference nonlinear iterations  3
Reference linear solves         3
RossFast linear solves          24
Reference mass residual        -4.73913226370359375E-013 cm
RossFast mass residual          -3.03421813024830518E-015 cm
D_h_inf                          2.00796959859417257E-005 cm
D_h_rms                          8.55848056071812140E-006 cm
D_theta_inf                      2.41824979207994062E-008
D_theta_rms                      1.03052868157011792E-008
D_storage                        0.0 cm
```

The O0/O2 output SHA-256 is:

`bf854934b47e3e060f20a86f2b1c49601aae58f8be332f68d9963e13335be3c5`

These are observations, not an admissibility verdict. The head, water-content and storage tolerances remain deliberately unset.

## Stage 0b: transaction-level pair is currently blocked

An earlier Stage 0 probe attempted to run both selections through the same production transaction configuration copied from F-ROSS12. That probe failed for the Reference route before commit.

The cause is structural rather than a solver convergence failure:

- F-ROSS12 uses `TX_TEMPORAL_MODEL_CERTIFICATE`;
- that transaction mode requires every accepted trial to publish a valid model temporal certificate;
- RossFast publishes its admitted `rossfast-model-certificate`;
- the simple Reference selection in this E0 composition does not publish the same certificate because the Reference temporal-history service is not active in this layout;
- RossFast E0 preflight simultaneously requires its current no-continuation layout and model-certificate policy.

Therefore a transaction-level run under the current F-ROSS12 policy would vary both solver implementation and temporal-acceptance mechanism, or reject one route. It is not a clean solver experiment.

Current Stage 0b status:

`BLOCKED_TEMPORAL_POLICY_ASYMMETRY`

This blocker must not be hidden by silently giving each solver a different transaction acceptance rule and calling the result paired.

## Identifiability boundary for prescribed fluxes

Both E0 boundaries are prescribed fluxes. Agreement of top and bottom flux values is therefore mostly imposed by construction, not predicted independently by the solvers.

Within E0:

- endpoint pressure head and water content are discriminating responses;
- profile storage is a discriminating aggregate response;
- each route's mass residual is an independent validity check;
- prescribed boundary-transfer identity is an experimental-control check only.

A claim about equivalence of **predicted** boundary fluxes requires a later independently qualified envelope in which at least one relevant flux is a model outcome, for example a head-controlled, groundwater-interacting or dynamic surface boundary.

## Frozen Stage 0 metrics

For endpoint heads and water contents:

```text
D_h_inf     = max_i |h_A(i) - h_R(i)|
D_h_rms     = sqrt(mean_i((h_A(i) - h_R(i))^2))
D_theta_inf = max_i |theta_A(i) - theta_R(i)|
D_theta_rms = sqrt(mean_i((theta_A(i) - theta_R(i))^2))
D_storage   = |S_A - S_R|
```

Each route's conservation residual is evaluated independently. Pairwise similarity of mass residuals is not sufficient.

## Scientific tolerances

PUB-P2E01 does not choose admissibility limits from the observed pilot discrepancy.

Current status:

```text
head tolerance           TO_BE_PREDECLARED_BEFORE_STAGE1
water-content tolerance  TO_BE_PREDECLARED_BEFORE_STAGE1
storage tolerance        TO_BE_PREDECLARED_BEFORE_STAGE1
predicted-flux tolerance NOT_APPLICABLE_WITHIN_PRESCRIBED-FLUX E0
mass requirement         existing independent hard route requirement
```

A defensible tolerance basis may come from an existing qualified SWAP tolerance with the same physical interpretation, a discretization-derived bound, a scientifically meaningful application-resolution threshold, or a preregistered sensitivity analysis. The observed B01 discrepancy itself may not be used to tune the threshold after the fact.

## Stage 1 E0 design

Stage 1 may start only after scientific state/storage tolerances are preregistered.

The broader E0 matrix remains restricted to:

- materials `B01`, `B12`, `O01`, `O05`, `O14`, `O18`;
- 16 cells of 10 cm;
- homogeneous material per column;
- qualified uniform initial hydraulic states;
- prescribed top and bottom fluxes within the admitted envelope;
- no roots, distributed sources, groundwater head boundary, energy coupling, heterogeneous profile or automatic solver fallback.

Initial states should preferably be parameterized by a material-normalized hydraulic descriptor such as effective saturation `Se0`, with pressure head derived from the exact admitted material authority. The levels must be frozen before broad execution.

A stratified or space-filling design is preferred over an indiscriminate full factorial. Refinement should target regions where preregistered state/storage discrepancy thresholds are approached.

## Performance boundary

Iteration and solve counts may be retained as diagnostics, but the Stage 0 workflow is not a controlled performance experiment. No speedup claim follows from this pilot. Any performance result requires the repository's separate controlled performance-measurement discipline.

## Negative-result policy

All failures and exclusions remain in the evidence set. Classification must distinguish unsupported contract, implementation defect candidate, conservation failure, temporal-policy incompatibility, scientifically material discrepancy and observation gap.

## Next permitted action

1. persist the Stage 0a run, metrics and Stage 0b blocker as immutable publication evidence;
2. predeclare the scientific head/water-content/storage tolerance rationale without using the observed B01 discrepancy to fit it;
3. only then freeze and execute the broader six-material E0 matrix;
4. treat transaction-level solver comparison as a separate later qualification problem until a common temporal acceptance policy is available.
