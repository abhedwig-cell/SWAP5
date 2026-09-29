# F-HYDROFIT02 P-LSAFE03 — content-defined independent BRO validation preregistration

## Trigger

P-LSAFE02 found 61 BRO objects independent of the frozen 31-record training corpus but zero eligible records because none carried surveyPurpose `bodemfysischOnderzoek`.

P-LSAFE02A then audited those same 61 frozen objects before any estimator evaluation and showed that every one of them has:
- modelling method `mualemVanGenuchten`;
- modelling procedure `WENRHydrofysicav1`;
- hydraulic observation arrays;
- conductivity-shape arrays;
- at least one InvestigatedInterval where both arrays are colocated.

Their surveyPurpose values are `hydrologischOnderzoek` or `onbekend`.

This suggests that the P-LSAFE02 evidence gap was caused by an administrative purpose label rather than missing or different hydraulic modelling content.

P-LSAFE03 therefore defines a new study population by actual hydraulic content and modelling semantics. It does not reopen or alter P-LSAFE02.

## Frozen independent object set

Use only:

`integration/research/data/F-HYDROFIT02_LSAFE02_INDEPENDENT_BRO_IDS.json`

No new object discovery is permitted in this workunit.

These 61 BRO objects are already independent at object level from the frozen 31-record training corpus.

## Content-defined record eligibility

An InvestigatedInterval is eligible when all of the following hold:

1. parent BRO object modelling method contains `mualemVanGenuchten`;
2. parent BRO object modelling procedure contains `WENRHydrofysicav1`;
3. the interval contains a non-empty `WaterContentAndConductivityAtSpecificSoilWaterPotential` DataArray;
4. the same interval contains a non-empty `ShapeHydraulicConductivityCurve` DataArray;
5. the interval contains the source fields needed by the existing frozen fitting implementation:
   - residualVolumetricWaterContent;
   - volumetricWaterContentAtSaturation;
   - modelledSaturatedHydraulicConductivity.

SurveyPurpose is recorded as provenance but is not an eligibility criterion.

No record may be excluded because of:
- source lambda value;
- observation count;
- hydraulic potential range;
- objective value;
- conditioning;
- eventual primary/fallback outcome.

Hydraulic record identity remains:

BRO id + begin depth + end depth + SHA-256 of the raw hydraulic values string.

Source lambda is an audit field only.

## Frozen estimator

Carry forward P-LSAFE01 unchanged.

Training-derived constants are frozen before this validation:

- lambda center: `-1.51057`;
- primary soft-prior width: `sigma_lambda = 1.5`;
- SEVERE threshold: condition number >= `1e8` or non-finite;
- same hydraulic objective, family weighting, bounds, transformations and optimizer;
- same scale-aware alpha/n/Ks boundary gate;
- same fixed-lambda fallback at lambda = `-1.51057`;
- same discrete Jbest reference grid:
  `[-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,0.5,1,2,5,10]`.

No validation source lambda, descriptor or outcome may alter any estimator component.

## Evaluation

Evaluate every eligible interval from all 61 frozen independent objects.

For each record report:

- exact hydraulic hash;
- surveyPurpose provenance;
- source lambda;
- hydraulic tuple count and hydraulic-potential span;
- Jbest on the frozen grid;
- primary fitted lambda;
- primary conditioning class and boundary status;
- whether fallback is triggered;
- final conditioning class and boundary status;
- final J/Jbest.

Report all-record aggregates:

- eligible records;
- contributing BRO objects;
- primary accepted;
- fallback count;
- final unqualified;
- final boundary blocks;
- median, mean and maximum J/Jbest;
- identifiability-class counts.

Report descriptive strata only, without using them for tuning:

- surveyPurpose: hydrologischOnderzoek, onbekend, other;
- observation count: 1-20, 21-100, >100;
- hydraulic-potential span: <1e3, 1e3..<1e4, >=1e4;
- source-lambda sign: negative, zero, positive.

## Evidence-size gate

Before replication inference:

- fewer than 30 eligible records or fewer than 5 contributing independent BRO objects:
  `INSUFFICIENT_CONTENT_DEFINED_INDEPENDENT_EVIDENCE`.

Otherwise apply the external replication gate.

## External replication gate

If the evidence-size gate is met, P-LSAFE03 is externally research-replicated only if:

- zero final SEVERE or non-finite fits;
- zero final alpha/n/Ks boundary blocks;
- zero hydraulic-hash mismatch;
- zero silent record loss;
- every eligible interval receives an explicit final disposition;
- final maximum J/Jbest <= `4.13247088`.

Fallback frequency is descriptive and is not a qualification threshold.

## Governance

Any failure is retained.

Do not:
- reintroduce surveyPurpose filtering after seeing results;
- tune sigma;
- change the lambda center;
- change the condition threshold;
- add another fallback;
- alter the Jbest grid;
- discard difficult records.

A positive result would support external research replication for a content-defined independent BRO hydraulic population. It would still not by itself authorize a production default.

A negative or evidence-insufficient result is a valid closure outcome.
