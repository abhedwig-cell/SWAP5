# F-HYDROFIT02 closeout — BRO hydraulic fitting, lambda identifiability and regularization

Status: **RESEARCH_CLOSED_WITH_QUALIFIED_GATED_ESTIMATOR**

Research branch at closeout:
`research/f-hydrofit02-bro-acquisition`

No production admission is requested from this workunit.

## Question

How should Mualem lambda be treated when reconstructing/fitting BRO hydrophysical retention and conductivity observations, given that hard lambda=0.5 can be inaccurate and free lambda can become poorly identifiable?

## Data authority correction

The work established that `(BRO id, begin depth, end depth)` is not a unique hydrophysical record identity.

Final semantic record identity is:
- BRO id;
- begin depth;
- end depth;
- SHA-256 of the raw `WaterContentAndConductivityAtSpecificSoilWaterPotential` values string.

InvestigatedInterval document ordinal is retained as provenance.

Source lambda is an audit field and is never a matching key.

The frozen identity-corrected corpus contains:
- 31 records;
- 31 non-empty hydraulic hashes;
- 31 unique hashes;
- zero duplicate hydraulic hashes.

Three repeated depth keys are genuine pairs of different hydrophysical records, not extractor duplicates.

## Main falsifications

### Hard lambda=0.5

Rejected as a general estimator because objective losses are materially larger than data-informed alternatives.

### Hard conditional KNN lambda

Not qualified. KNN5/KNN5K can improve objective behavior but can steer fits into severe parameter-conditioning regions.

### Soft lambda shrinkage alone

LOO-median soft shrinkage with sigma 0.5 and 1.5 is strong on the deterministic 12, but P-LSHRINK02 remains NOT_REPLICATED on the independent 19-case complement.

The unique failure is BHR000000378532 0.65-0.75 m.

P-LID02 demonstrates that this record has a localized severe identifiability valley around the low-objective lambda region. The problem is not duplicate identity, general optimizer failure or broad bad conditioning.

## Qualified research estimator

P-LSAFE01 composes only previously preregistered components:

1. primary: LOO-median soft shrinkage, sigma 1.5;
2. existing scale-aware bound gate;
3. existing SEVERE identifiability gate at condition number >= 1e8/non-finite;
4. hard fallback to the same LOO-median lambda target only when the primary fit fails a gate.

Authority run: `36521846452`.

Frozen-31 result:
- primary accepted: 30/31;
- fallback used: 1/31;
- final SEVERE: 0;
- final formal alpha/n/Ks boundary blocks: 0;
- median J/Jbest: 1.00011;
- mean: 1.06802;
- max: 3.28216.

The sole fallback is BHR000000378532 0.65-0.75 m:
- soft primary condition number: about 1.73e17, SEVERE;
- hard LOO fallback condition number: about 1.71e4, MODERATE;
- fallback J/Jbest: 3.28216.

P-LSAFE01 is classified:

**QUALIFIED_RESEARCH_ESTIMATOR_ON_FROZEN_31**

## Scientific interpretation

The evidence supports treating lambda as a regularized empirical constitutive parameter rather than either:
- a universal hard constant; or
- an unconstrained free parameter accepted solely because the objective is low.

For this corpus, the defensible estimator structure is:
- allow lambda to move under a broad robust empirical prior;
- explicitly diagnose identifiability after fitting;
- replace only failed fits with a harder robust fallback.

This preserves flexible fitting for the large majority of records while preventing acceptance of a low-objective but locally singular solution.

The literature is consistent with this interpretation: Mualem-van Genuchten inverse problems are nonlinear and parameter-interdependent, fixed pore-connectivity values are conventional assumptions rather than universal empirical truths, and explicit identifiability analysis is methodologically appropriate. See `F-HYDROFIT02_LITERATURE_RECONCILIATION.md`.

## What remains outside this closure

Before any production default or BRO-wide fitting policy:
- replicate P-LSAFE01 on a substantially larger independent BRO corpus;
- characterize sensitivity to corpus composition and leave-one-object center estimation;
- test robustness across observation-density and hydraulic-range strata;
- decide whether the empirical lambda parameter should remain exposed as a fitted constitutive parameter or be hidden behind an estimator policy;
- define production failure/reporting semantics for records that remain unqualified even after fallback.

Do not tune sigma, condition thresholds, KNN hyperparameters or alternate fallback values from the current 31-record result.

## Governance disposition

RECONCILE: complete.

PREREGISTER: complete for identity correction, shrinkage replication, severe-case characterization and gated estimator.

EXECUTE: complete.

QUALIFY: complete at research level.

RECORD/CLOSE: complete.

Production admission: **NOT_REQUESTED**.
