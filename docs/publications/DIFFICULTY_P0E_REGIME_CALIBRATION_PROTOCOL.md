# DIFFICULTY Phase-0 regime calibration and freeze protocol

Status: PREREGISTERED BEFORE SCIENTIFIC OUTCOME INSPECTION

## Purpose

DIF-P0E has executable outcome-blind classification logic for R1-R6. Its numerical thresholds are not yet scientific thresholds. This protocol governs their calibration without using solver difficulty outcomes.

## Firewall

Calibration may inspect only immutable pre-trial state, forcing, soil hydraulic parameters, grid descriptors and descriptors computed from them.

Forbidden during calibration:
- convergence/failure;
- nonlinear/linear iteration counts;
- retry/rejection;
- fallback;
- residual/update trajectories;
- wall time;
- mass-balance outcome;
- solver identity when selecting thresholds.

The calibration dataset must therefore be exported before joining any outcome table.

## Calibration population

Use the intended Phase-0 physical state population across all four soil parameterizations and all intended forcing/boundary families. Sampling is performed in pre-trial descriptor space, not from rows selected by solver behaviour.

Adjacent time states must be thinned/clustered so that a single trajectory cannot dominate a threshold.

## Threshold principle

Thresholds are not optimized for predictive accuracy and are not chosen to equalize solver failure counts.

For each regime, calibration may use physical semantics plus the marginal distribution of its prospective descriptors to obtain enough support for sampling. The target is distinguishable physical transitions, not balanced classes.

If a regime cannot obtain adequate physical support without outcome information, mark it UNDER_SUPPORTED. Do not move the threshold toward failures.

## R1-R6 authority

R1 quasi-equilibrium drainage control:
- low hydraulic-head gradient;
- low atmospheric-flux demand relative to surface conductivity where that ratio is available.

R2 dry-soil infiltration:
- dry pre-state;
- inward top forcing;
- forcing large relative to surface conductivity.

R3 strong wetting-front propagation:
- strong prospective hydraulic contrast, operationalized initially by the maximum spatial log-conductivity gradient.
- Directionality must additionally be checked in the sampled forcing/state metadata before the final freeze; a strong drying front must not be relabelled wetting merely because the gradient is large.

R4 near-saturation/capillary-fringe interaction:
- at least part of the profile close to zero pressure head and/or an independently prospective groundwater/capillary-fringe proximity descriptor once available.

R5 strong drying/evaporative front:
- outward atmospheric forcing with a prospective drying state/gradient.

R6 atmospheric boundary transition:
- only where the admitted boundary provider supplies a physically meaningful prospective distance-to-switch quantity.
- absence of that quantity is NOT equivalent to being far from switching.

## Freeze artifact

DIF-P0E-FREEZE must contain:
- source canonical SHA;
- source research SHA;
- exact soil/forcing population definition;
- descriptor definitions and units;
- sample counts before/after thinning;
- marginal descriptor quantiles by soil;
- final threshold values and rationale;
- regime counts and overlap counts;
- UNDER_SUPPORTED flags;
- hash of the outcome-blind calibration table;
- explicit statement that no difficulty outcomes were accessible to threshold selection.

Once committed, the freeze artifact is immutable for the held-out Phase-0 analysis. Corrections require a new protocol/version and cannot silently replace the frozen thresholds.

## Important correction to executable prototype

The current executable selector is a mechanism test, not yet the scientific freeze. In particular, R3 and R5 require directionality refinement before freeze, and R4/R6 should incorporate groundwater/boundary-provider-specific prospective descriptors when authority permits.

Therefore DIF-P0F may test recording and data plumbing using prototype labels, but no pilot result may be used to tune these thresholds.

## Admission condition

DIF-P0E scientific freeze is admitted only when:
1. P0C replay qualification is green;
2. calibration table is demonstrably outcome-blind;
3. R1-R6 have explicit physical semantics;
4. overlap/priority behaviour is reported;
5. unsupported regimes remain explicit rather than being forced into existence.
