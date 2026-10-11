# P2 admissibility envelope design

## Purpose

PUB-P2E02 defines how scientific admissibility thresholds will be established before the broader Reference-versus-RossFast experiment matrix is evaluated.

The central rule is deliberately strict:

> RossFast discrepancies may not determine the threshold used to judge RossFast.

The B01 Stage-0 pilot has already been observed. Its discrepancy values are therefore quarantined from threshold calibration. They remain valid as an extraction/reproducibility pilot, but cannot be used to choose a head, water-content or storage limit.

## Why a separate uncertainty envelope is needed

A solver comparison mixes at least three distinct questions if they are not separated explicitly:

1. does each route conserve water and satisfy its own numerical validity conditions;
2. how much does the accepted state change under ordinary numerical refinement of the Reference method;
3. is the alternative solver's discrepancy small relative to a threshold that was fixed independently of the alternative result.

Paper 2 will keep these questions separate.

OpenRE treats state accuracy, mass conservation, boundary-flux truncation and efficiency as distinct success criteria and shows that boundary-flux error can depend strongly on timestep even when water balance is good. This supports treating numerical uncertainty as a response-dependent quantity rather than collapsing everything into one score.

The 2026 GWSWEX dual-solver study likewise interprets RMSE relative to its own discretization and reports regime-dependent sensitivity to convergence controls. Its 2 cm scale is therefore study-specific and is not transferable as a SWAP5 acceptance threshold.

References:

- Ireson, A. M., Spiteri, R. J., Clark, M. P., and Mathias, S. A. (2023), *A simple, efficient, mass-conservative approach to solving Richards' equation (openRE, v1.0)*, Geoscientific Model Development 16, 659-677, https://doi.org/10.5194/gmd-16-659-2023.
- Kootanoor Sheshadrivasan, V. and Langhammer, J. (2026), *GWSWEX v1.0: a dual-solver 1D unsaturated zone model for mass-conservative groundwater recharge and runoff computation in distributed hydrological modelling*, Geoscientific Model Development 19, 8233-8267, https://doi.org/10.5194/gmd-19-8233-2026.

## Separation of validity and admissibility

### Hard validity gates

These are not statistical tolerances and are not relaxed to accommodate solver disagreement:

- the solver must execute the declared case through its admitted contract;
- state values must remain finite and physically representable under the common contract;
- each route must pass its own hard conservation requirement;
- there may be no silent fallback to another solver;
- case provenance, material, grid, boundary contract and forcing must match the preregistered experiment.

A case failing a hard validity gate is excluded or classified as a failure. It is not rescued by a small pairwise state difference.

### Scientific admissibility metrics

For cases passing the hard gates, the primary state metrics remain:

```text
D_h_inf
D_h_rms
D_theta_inf
D_theta_rms
D_storage_abs
```

Predicted-flux metrics are not part of the current prescribed-flux E0 scientific verdict because top and bottom fluxes are controlled inputs there.

## Calibration dataset firewall

The following data may **not** be used to calibrate the threshold:

- the observed B01 Stage-0 Reference-versus-RossFast differences;
- any later RossFast result produced before the threshold rule is frozen;
- a hand-selected subset chosen because RossFast happens to agree well;
- publication performance measurements.

The threshold-calibration dataset is Reference-only.

## Reference-only numerical uncertainty experiment

The intended calibration experiment compares the Reference solver with itself under preregistered numerical refinement while preserving the physical problem.

The preferred first design is temporal refinement on the solver seam:

```text
Reference coarse trajectory to T
versus
Reference refined trajectory to the same T
```

with the same:

- material and constitutive law;
- grid;
- initial physical state;
- boundary-condition type and forcing history;
- source/sink physics;
- final physical time.

The refinement changes only the numerical temporal resolution. For example, one accepted step of duration `dt` can be compared with two sequential Reference solves of `dt/2`, starting the second half from the first accepted half-state. The final states then define a Reference self-disagreement at the same physical time.

This is intentionally different from changing spatial resolution, because RossFast E0 is currently fixed to the admitted 16 x 10 cm grid. Spatial refinement may later be informative context, but it should not silently redefine the discrete problem used for solver admissibility.

## Reference self-disagreement metrics

For each calibration case `c`:

```text
U_h_inf(c)
U_h_rms(c)
U_theta_inf(c)
U_theta_rms(c)
U_storage(c)
```

are defined exactly like the paired solver discrepancy metrics, except that both states come from Reference trajectories at two preregistered temporal resolutions.

The calibration run also records:

- mass residual for each trajectory;
- nonlinear iterations;
- retries or nonconvergence;
- forcing/material identifiers;
- the exact coarse/refined temporal schedule.

A Reference refinement pair failing its own hard mass/convergence gates is not usable for threshold calibration and remains in the negative-results register.

## Threshold rule is not yet numerically fixed

PUB-P2E02 does not invent a multiplier before Reference-only data exist.

Candidate forms to assess after the Reference-only calibration dataset is generated include:

```text
T_metric = max(application_resolution_floor, preregistered_factor * robust_reference_uncertainty_scale)
```

or a material/state-normalized equivalent where the normalization has an independent physical basis.

The factor, aggregation statistic and any application-resolution floor must be chosen and documented **without inspecting new RossFast results**. The observed Stage-0 RossFast difference must not be used to decide whether a candidate factor is convenient.

## Material and state coverage

The Reference-only calibration set should precede the broad RossFast matrix and should span the same intended E0 domain as far as possible:

- B01, B12, O01, O05, O14 and O18;
- homogeneous 16-cell, 10 cm grid;
- several preregistered initial hydraulic states, preferably expressed through effective saturation `Se0` and transformed to pressure head with the admitted material relation;
- several prescribed-flux forcing intensities/signs that remain inside the admitted E0 contract.

The exact levels belong in a separate machine-readable calibration manifest. They should be selected for domain coverage, not from locations where RossFast is already known to differ.

## Regime dependence

A single global absolute head tolerance may be inappropriate if Reference self-disagreement varies strongly by hydraulic regime. PUB-P2E02 therefore permits the calibration data to test, before RossFast evaluation, whether a stratified threshold is scientifically better justified, for example by material family or normalized initial hydraulic state.

Any stratification must be frozen before the corresponding RossFast cases are revealed. Post-hoc slicing to convert failures into passes is forbidden.

## Mass remains separate

Mass conservation is a hard route-level condition and is not folded into a weighted composite admissibility score. A solver cannot compensate for a conservation failure by matching pressure head closely.

## Performance remains separate

Runtime, linear-solve count and nonlinear-iteration count are retained as diagnostics but do not influence the scientific admissibility threshold. Performance requires its own controlled measurement design.

## Transaction-level comparison remains out of E0 calibration

PUB-P2E01 established that the current Reference and RossFast production compositions do not share the same admitted temporal-certificate layout. The Reference-only uncertainty experiment therefore begins at the common solver seam, where the physical request can be held exactly fixed.

Transaction-level comparison is a separate future qualification problem. Its solution may not be smuggled into the solver threshold by assigning route-specific temporal controllers.

## Stage gates

### E2-A: design freeze

PASS when:

- calibration uses Reference only;
- B01 Stage-0 RossFast observations are explicitly excluded from threshold fitting;
- metrics and hard validity gates are fixed;
- physical-domain factors are declared;
- the temporal-refinement construction is executable on the common solver seam.

### E2-B: calibration dataset

PASS when the preregistered Reference-only matrix has been executed reproducibly and all usable/failed cases are retained.

### E2-C: threshold freeze

PASS only after the threshold formula, aggregation rule and any stratification are committed before broad RossFast evaluation.

### E2-D: RossFast evaluation

Only after E2-C may the broader paired matrix produce an admissibility result.

## Next permitted action

Create the machine-readable Reference-only calibration manifest and implement the smallest B01 Reference coarse-versus-two-half pilot to prove that the uncertainty-extraction method is executable. The pilot is for the uncertainty method only; its values do not yet set the final threshold.
