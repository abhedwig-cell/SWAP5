# F-HYDROFIT01 P5 — near-equivalent ensemble preregistration

Authority: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`

## Purpose

Characterize the set of hydraulic parameter vectors that fit an information-limited dataset almost as well as the optimum. The target is not posterior probability and not yet uncertainty coverage. It is an objective-envelope characterization.

## Dataset

Generate deterministic SWAP-native synthetic observations from an interior MvG parameter vector, then deliberately limit information by:

- retaining theta observations only over a restricted head range;
- retaining a sparse K subset;
- applying a fixed deterministic perturbation vector so the optimum objective is nonzero.

Use `family_mean` weighting so row count does not determine family importance.

## Envelope definition

Let `J*` be the minimum objective found by multi-start.

Primary near-equivalence envelope:

`J(p) <= J* + max(0.05 * J*, 0.25)`.

The additive floor prevents a vanishing envelope when J* is small in standardized-residual units. This is an engineering exploration threshold, not a confidence region.

A sensitivity report must also evaluate tighter and wider thresholds:

- tight: `J* + max(0.01 J*, 0.05)`;
- primary: `J* + max(0.05 J*, 0.25)`;
- wide: `J* + max(0.20 J*, 1.00)`.

No probabilistic confidence claim is allowed from these envelopes.

## Candidate generation

Generate candidates in optimizer coordinates using deterministic seeded sampling around the optimum, with scale directions informed by the local Jacobian SVD.

Candidate generation must include both:

- local singular-vector perturbations, emphasizing weak directions;
- broader bounded quasi-random/random coverage to detect nonlocal alternatives.

Every retained candidate must satisfy physical bounds and be evaluated by the same objective as the optimum.

## Required outputs

For each envelope:

- number of retained candidates;
- min/max and quantiles of each fitted parameter;
- parameter correlation matrix for retained candidates, if sample size permits;
- theta(h) spread on a fixed log-spaced head grid;
- K(h) spread on the same grid;
- heads at which predictive spread is largest;
- distance of retained candidates from the optimum in scaled parameter coordinates.

## Gates

E0. Deterministic seed gives byte-stable retained candidate count and summary on the CI platform.

E1. Tight ensemble is a subset of primary; primary is a subset of wide.

E2. Every retained candidate satisfies its envelope by direct objective re-evaluation.

E3. The information-limited dataset yields nontrivial spread in at least one parameter.

E4. Predictive function spread is not inferred from parameter spread; theta/K envelopes are computed explicitly.

E5. Adding the omitted informative observations shrinks at least one previously weak parameter direction or predictive envelope.

## Interpretation boundary

P5 maps objective near-equivalence. It does not establish Bayesian posterior probability, frequentist confidence coverage, or physical population variability.

Those require an explicit observation-error model and separate validation.

## Next step after qualification

Use selected diverse members of the primary envelope as the input set for P6 SWAP numerical probes. Selection must span the fitted-function envelope rather than simply picking extreme raw parameter values.
