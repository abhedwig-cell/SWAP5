# F-HYDROFIT01 — modern soil-hydraulic parameter estimation

Status: PREREGISTERED  
Canonical authority: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`  
Scope: research tooling only; no production SWAP change.

## Decision

Historical RETC reproduction is not the product objective. F-RETC01 remains bounded provenance/reference evidence. F-HYDROFIT01 develops a modern estimator whose scientific contract is explicit and whose forward hydraulic semantics can be mapped to qualified SWAP5 model families.

Historical RETC behaviour is retained only where useful as a benchmark. It is not a compatibility requirement.

## Primary objective

Estimate physically admissible soil-hydraulic parameter sets from retention and, where available, conductivity observations while exposing uncertainty, non-identifiability and parameter correlation rather than returning an unexplained single optimum.

Initial target: Mualem-Van Genuchten family compatible with the selected SWAP5 default hydraulic route. Broader SWAP hydraulic families require separate gates.

## Separation of objectives

Three quantities must remain distinct.

### F — data fit

Agreement with observed retention and conductivity data.

### I — identifiability

Whether the data actually constrain the fitted parameters. A low residual alone does not establish this.

### N — numerical behaviour in SWAP

Richards-solver effort and robustness when a fitted parameter set is used in a controlled SWAP case.

F-HYDROFIT01 first establishes F and I. N is measured only after fit semantics and uncertainty are frozen. N must not be hidden inside the fitting objective until a separate multi-objective experiment is preregistered.

This prevents choosing a numerically convenient soil and then calling it the best physical fit.

## H1 — modern bounded estimation

A bounded nonlinear least-squares estimator can recover known synthetic MvG parameters from noise-free observations and provide stable estimates under realistic perturbations.

## H2 — joint theta/K information

Adding conductivity observations can reduce otherwise weakly constrained parameter directions, but only when the weighting/noise model prevents one observation family from dominating through scale or sample count.

## H3 — near-equivalent parameter families

For realistic sparse hydraulic observations, multiple parameter sets can be statistically near-equivalent. Reporting only the optimizer minimum therefore understates uncertainty.

## H4 — SWAP numerical differentiation

Among statistically near-equivalent fitted sets, measurable differences may exist in constitutive stiffness and SWAP solver effort. This is a later falsifiable hypothesis, not an assumption used to select the initial fit.

## Parameterization

First model family:

- residual water content `theta_r`;
- saturated water content `theta_s`;
- positive `alpha`;
- `n > 1`;
- `m = 1 - 1/n` for the initial Mualem restriction;
- saturated conductivity `Ks > 0`;
- pore-connectivity/tortuosity exponent `l`, fixed or fitted by explicit configuration.

Optimization coordinates should enforce hard domains by transformation or bounds. The physical result must always be reported in ordinary units.

No universal bounds are to be invented from convenience. Dataset-specific or model-wide bounds must carry provenance.

## Observation model

Retention and conductivity observations are separate data families.

Default residual candidates to test before freeze:

- retention: residual in volumetric water content, optionally scaled by declared measurement sigma;
- conductivity: residual in `log(K)` when all K observations are positive, optionally scaled by declared log-space sigma.

Joint fitting must not depend accidentally on the number or units of observations. Family scaling must be explicit, reported and sensitivity-tested.

If measurement uncertainties are known, standardized residuals are preferred. If they are unknown, equal-family and empirically scaled alternatives must be compared and the choice documented.

## Optimizer architecture

The first implementation may use a mature bounded least-squares algorithm rather than reproduce RETC's optimizer.

Required properties:

- deterministic result for fixed data, bounds, initial point and configuration;
- explicit termination reason;
- objective and residual vector exposed;
- bounds respected at every reported solution;
- multiple-start support outside the single optimizer call;
- no silent repair of invalid observations.

The estimator interface must be independent of a particular optimization library.

## Identifiability outputs

At minimum report:

- optimum and objective;
- residuals by observation family;
- local Jacobian at the solution;
- scaled sensitivity/correlation information;
- condition/singular-value diagnostics;
- bound-active parameters;
- multi-start solution spread.

Local covariance/confidence intervals may be reported only with their assumptions.

A later stage should add profile likelihood or another nonlinear identifiability method because local covariance can be misleading for strongly correlated hydraulic parameters.

## Validation ladder

### V0 — forward identity

The estimator's forward MvG evaluator is compared against the selected SWAP5 constitutive authority over a preregistered h-domain.

### V1 — synthetic exact recovery

Generate noise-free observations from an interior parameter set. Fit from multiple displaced initial points. Require recovery to a declared numerical tolerance.

### V2 — noise perturbation

Apply reproducible perturbations consistent with a declared observation-error model. Evaluate bias, spread and coverage diagnostics.

### V3 — sparse/partial observations

Remove strategically informative portions of the retention/K domain and verify that the diagnostics reveal degraded identifiability rather than merely returning a precise-looking optimum.

### V4 — near-equivalent ensemble

Retain parameter sets within a preregistered fit-quality envelope around the optimum and characterize parameter and constitutive-function spread.

### V5 — SWAP numerical probe

Run the near-equivalent ensemble through one frozen SWAP forcing/profile configuration and measure accepted/rejected steps, nonlinear iterations, minimum/mean timestep and mass-balance diagnostics.

V5 may establish association between fitted constitutive shape and numerical effort. It must not redefine the fit optimum without a later preregistration.

## Success criteria for F-HYDROFIT01

- V0 forward agreement established;
- V1 exact synthetic recovery;
- multi-start reproducibility characterized;
- uncertainty/identifiability diagnostics demonstrably respond to information loss in V3;
- no production source changes;
- full configuration and observations sufficient to reproduce every reported fit.

## Nonclaims

F-HYDROFIT01 does not initially claim:

- equivalence to RETC;
- a uniquely correct weighting scheme for every dataset;
- that the global optimum has been proven;
- that local confidence intervals fully describe nonlinear uncertainty;
- that numerically easier SWAP behaviour implies greater physical truth;
- BOFEK-wide validity;
- support for every historical SWAP hydraulic model.

## Planned continuation

P1: implement SWAP-bound forward evaluator and typed observation/config/result contracts.  
P2: bounded single-fit estimator plus synthetic exact-recovery tests.  
P3: multi-start and identifiability diagnostics.  
P4: joint retention/K weighting experiment.  
P5: near-equivalent ensemble.  
P6: SWAP numerical probe.  
P7: only after P1-P6, decide whether a solver-aware Pareto selection is scientifically justified.
