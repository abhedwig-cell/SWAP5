# F-ROM0TA1 temporal-authority adjudication

## Decision

**HEAD_BUDGET_AUTHORITY_REQUIRED_BEFORE_ACCEPTED_TRANSIENT_QUALIFICATION**

The existing Reference-Richards model temporal certificate survives the first ROM-specific measurement test, but ROM-0 cannot yet promote it to accepted transient trajectory authority.

The missing item is no longer the estimator implementation or its FMR lifecycle. It is an independently justified scientific/application head-error budget.

## What is now qualified

Run 35365703235 executed the complete preregistered 8-row B01/B14 matrix. All direct principal and refined Reference solves converged, all F-SI38 temporal indicators were available, and every row satisfied the frozen hard mass gate.

For all eight rows, the production `B_inf` value exceeded the actually observed maximum pressure-head difference between one full step and two half steps. No row showed empirical underestimation.

The largest actual head difference was about `8.16e-6 cm`; the largest `B_inf` was about `1.13e-3 cm`. Across the matrix, `B_inf / max|h_full-h_2half|` ranged from about 138 to 3620.

This is useful evidence, but it is deliberately a finite-matrix empirical statement. It is not promoted to a mathematical error bound.

## Refinement behavior

The relation is not a calibrated one-to-one proxy.

For B01, halving the step from 0.0016 d to 0.0008 d reduced the actual full-versus-two-half head difference with observed order about 1.91, while `B_inf` decreased with order about 0.98.

For B14, the corresponding observed orders were about 2.00 for the actual refinement difference and about 1.00 for `B_inf`.

So the certificate becomes more conservative relative to the observed refinement error as the timestep is refined. That behavior is consistent with its construction as a derivative-change defect indicator, but it means an application budget cannot be inferred by treating `B_inf` as an estimate equal to the actual step-doubling error.

## What the existing authority does and does not provide

F-SI38 qualifies how `B_inf` is computed. FMR44R qualifies the accepted predecessor-derivative lifecycle and model-certificate transaction wiring. F-VQ75 independently qualifies that runtime composition, and F-CI62/F-CI62P canonically admit it.

None of those authorities defines an application or ROM head-error budget. In particular, the FMR44R value of `2.5e-11 cm` is fixture-specific qualification evidence and is explicitly forbidden as a general default.

The older F-CI14 material likewise records that there is no qualified numeric Reference temporal profile and explicitly rejects reusing nonlinear solver tolerances as temporal-accuracy limits.

The ROM-0 preregistration says the Reference floor is measured before an accuracy threshold is derived. It does not itself specify the scientific rule by which an acceptable pressure-head temporal error is chosen.

## Why execution stops here

Selecting `H_budget` from the measured `B_inf` values would be post-result threshold tuning.

Selecting it from the observed full-versus-two-half differences would collapse two separate questions into one: numerical Reference refinement behavior versus scientifically acceptable temporal error.

Selecting it from the 1e-12 nonlinear/mass controls would reuse solver policy as application accuracy policy, which existing authority explicitly forbids.

Therefore the repository currently contains no authority that determines the next numeric budget without a new scientific/governance choice.

## State of the main question

The answer to “can the existing model temporal certificate be used?” is now conditional:

- **mechanism:** yes, the indicator, history lifecycle, normalization seam, rollback/retry behavior and canonical admission exist;
- **local estimator behavior:** yes, it is empirically conservative for the preregistered B01/B14 perturbation matrix;
- **accepted transient trajectory authority:** not yet, because the head-error budget is scientifically undefined;
- **numerical Reference floor:** the direct refinement diagnostic is measured locally, but it is not yet the authoritative accepted-trajectory floor required by ROM-0;
- **ROM-1A:** remains blocked.

## Required next authority decision

Before another trajectory-acceptance execution, define the scientific basis for a ROM Reference pressure-head temporal budget independently of these measured results.

That decision may be based on an application-relevant head accuracy requirement or on another pre-existing scientific requirement with explicit units and scope. It must be preregistered before applying the model-certificate transaction to B01/B14.

No production physics, Reference source, solver iteration budget, retry budget, perturbation amplitude or temporal tolerance was changed in F-ROM0TA1.
