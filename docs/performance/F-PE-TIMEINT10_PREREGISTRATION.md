# F-PE-TIMEINT10 preregistration — embedded BDF2/BE endpoint pair

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@3aab0ac589766f409911b06c28ff081c8e68a69b`

Parent authority:

- TIMEINT05: variable-step fully implicit BDF2 qualified for adjacent accepted ratio 0.5 <= r <= 2.0;
- TIMEINT09: exact final-Newton LTE response remains strongly predictive but fails blind conservative classification with five false-safe points;
- TIMEINT09 stop rule requires an embedded integrator-pair study rather than another response approximation.

## Purpose

Test whether a lower-order Backward Euler endpoint can be embedded cheaply around the converged BDF2 endpoint using the same final Newton factorization.

The target is a direct discretization-order difference, not another fitted LTE-response model.

## Candidate construction

At a converged fully implicit variable-step BDF2 endpoint:

1. retain the exact final normal TRIDAG factorization already captured in TIMEINT09;
2. evaluate no new flux/operator model;
3. form the BE residual at the same endpoint from the storage-term difference only.

Because BDF2 and BE share the same fully implicit endpoint flux/operator terms, the residual difference is exactly:

`R_BE - R_BDF2 = M_depth * [ (theta_np1-theta_n) - (a0*theta_np1+a1*theta_n+a2*theta_nm1) ] / h`

where `M_depth` is the compartment depth/matrix fraction factor used by the fixture.

Since `R_BDF2=0` at the converged endpoint, this is the BE residual there.

4. apply one backsolve through the exact final BDF2 Newton factorization;
5. obtain one correction `delta_BE`;
6. define the raw embedded estimate:

`E10 = max_i |delta_BE_i|`.

No empirical multiplier, intercept, material term, forcing term or ratio correction is allowed.

## Cost envelope

Estimator cost:

- zero additional nonlinear solves;
- zero additional Jacobian assemblies;
- exactly one additional tridiagonal backsolve.

## Research authority

Actual local temporal error remains the full BDF2 versus two-half BDF2 endpoint difference used by TIMEINT07-09.

## P0 calibration bank

Same exposed B01/O05 mechanism bank as TIMEINT09:

- B01 and O05;
- infiltration 2 and 4 cm/day;
- R1, R1P5 and R2;
- base mean dt 0.010 and 0.005 d;
- horizon 0.04 d.

## Frozen P0 gates

E10 advances only if:

1. all full BDF2 trajectories complete;
2. at least 80 complete local labels;
3. backsolve succeeds for every complete labelled point;
4. no estimator-authority alternative-solver use;
5. E10 is finite and nonnegative;
6. overall Spearman(E10,E_HEAD) >= 0.85;
7. per-pattern Spearman >= 0.80;
8. at threshold E10 <= 0.01 cm: false-safe count = 0;
9. safe coverage >= 30%;
10. exactly one extra backsolve and zero extra nonlinear solves.

Unlike TIMEINT07-09, no tight scale-ratio gate is imposed because BDF2-BE is a mixed-order embedded difference and is expected to be conservative rather than scale-identical.

## Blind holdout

If P0 passes, freeze E10 unchanged and evaluate on the prior blind B12/O14 envelope:

- B12 and O14;
- infiltration 1, 3 and 5 cm/day;
- R1, R1P5 and R2;
- base mean dt 0.010 and 0.005 d;
- horizon 0.04 d.

Holdout qualification requires:

1. all 36 full trajectories complete;
2. at least 130 complete labels;
3. no more than 2 trajectories with unavailable two-half research labels;
4. no estimator-authority alternative-solver use;
5. overall Spearman >= 0.80;
6. per-pattern Spearman >= 0.75;
7. zero false-safe at E10 <= 0.01 cm;
8. safe coverage >= 30%.

## Stop rule

If P0 fails, stop this embedded-BE construction.

If P0 passes but blind holdout fails, stop this construction.

Do not fit a scalar multiplier after exposure.

A failure means a useful embedded pair likely requires a genuinely co-designed implicit pair rather than one BE correction through the BDF2 Jacobian.

## Production boundary

No production source change.

Variable-step BDF2 remains research authority only.
