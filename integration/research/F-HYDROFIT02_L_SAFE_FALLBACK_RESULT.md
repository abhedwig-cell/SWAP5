# F-HYDROFIT02 P-LSAFE01 gated soft-lambda estimator result

Authority run: `36521846452`, head `7652cdfe6f20565510b3e801ccbc60be953078e4`.

Artifact: `11013324384`, digest `sha256:50a8d5ee2512ccdbfca85962a31033a5c7627bedaada48d539d8cd15267912aa`.

## Frozen estimator

Primary:
- leave-one-BRO-object-out median lambda center;
- soft shrinkage with `sigma_lambda = 1.5`;
- existing hydraulic objective, bounds, weighting and optimizer;
- existing hydraulic identifiability gate: SEVERE at condition number >= 1e8 or non-finite;
- existing scale-aware alpha/n/Ks boundary gate.

Fallback:
- triggered only when the primary fit fails either gate;
- lambda hard-fixed to the same LOO-median target;
- no alternate lambda center, sigma, threshold or second fallback.

## Result

### Deterministic 12

- primary accepted: 12/12;
- fallback used: 0;
- final unqualified: 0;
- boundary blocked: 0;
- median J/Jbest: 0.999734;
- mean: 1.018934;
- max: 1.254520;
- final classes: 6 WELL_CONDITIONED, 6 MODERATE.

This reproduces the P-LSHRINK01 LOO sigma=1.5 result.

### Independent complement 19

- primary accepted: 18/19;
- fallback used: 1;
- final unqualified: 0;
- boundary blocked: 0;
- median J/Jbest: 1.000709;
- mean: 1.099024;
- max: 3.282162;
- final classes: 7 WELL_CONDITIONED, 12 MODERATE.

The sole fallback-triggered record is:

`BHR000000378532 0.65-0.75 m`

hydraulic hash:

`19f7fe0532875070ff6049f98959a5ea57f2cc3b95724387fd74dbf68bc6df12`

Primary soft fit:
- lambda target: -1.4503;
- fitted lambda: -4.039153;
- hydraulic condition number: 1.728e17;
- class: SEVERE;
- no formal alpha/n/Ks boundary block.

Hard-LOO fallback:
- lambda fixed to -1.4503;
- final condition number: 1.714e4;
- class: MODERATE;
- no formal alpha/n/Ks boundary block;
- J/Jbest: 3.282162.

The fallback therefore moves the fit out of the localized low-objective severe ridge at a measurable but bounded objective cost.

### All 31

- primary accepted: 30/31;
- fallback used: 1;
- final unqualified: 0;
- boundary blocked: 0;
- median J/Jbest: 1.000110;
- mean: 1.068021;
- max: 3.282162;
- final classes: 13 WELL_CONDITIONED, 18 MODERATE.

## Qualification

P-LSAFE01 satisfies all preregistered research qualification criteria:

- zero final SEVERE fits;
- zero final alpha/n/Ks boundary blocks;
- zero record loss;
- exact hydraulic-hash binding throughout;
- final maximum J/Jbest 3.282, below the preregistered hard-LOO deterministic guardrail of 4.132.

P-LSAFE01 is therefore **QUALIFIED_RESEARCH_ESTIMATOR_ON_FROZEN_31**.

## Interpretation

The result supports a two-stage estimator rather than a single universal lambda rule:

1. use the LOO-median soft prior to retain flexibility where the data support an identifiable fit;
2. reject a primary fit when the existing identifiability/boundary gate fails;
3. fall back to the same robust empirical center as a hard fixed lambda only for those failed cases.

For the current frozen corpus this preserves the good objective behavior of soft shrinkage in 30/31 records and sacrifices objective fit only for the one record whose preferred lambda region is structurally ill-conditioned.

The result does not establish that sigma 1.5 is globally optimal, that the 1e8 threshold is universally transferable, or that the estimator is production-ready. No production admission follows from 31 records.
