# F-HYDROFIT02 P-LSAFE02A — independent BRO availability audit preregistration

## Trigger

P-LSAFE02 completed a national deterministic BRO search and found 61 BRO objects that are object-independent of the frozen 31-record training corpus, but zero eligible validation records under the frozen hydrophysical Mualem-van Genuchten eligibility contract.

P-LSAFE02 is already closed as `INSUFFICIENT_INDEPENDENT_BRO_EVIDENCE`.

This audit is diagnostic only. It must not retroactively change P-LSAFE02 membership or estimator qualification.

## Frozen object set

Use only:

`integration/research/data/F-HYDROFIT02_LSAFE02_INDEPENDENT_BRO_IDS.json`

This contains the 61 independent BRO ids from authority run `36523469252`.

Do not add, remove or replace objects during this audit.

## Purpose

For every one of the 61 objects, determine why it did not produce an eligible P-LSAFE02 record.

Classify independently:

1. survey purpose:
   - contains `bodemfysischOnderzoek`;
   - does not contain `bodemfysischOnderzoek`;

2. object modelling method:
   - contains `mualemVanGenuchten`;
   - another modelling method is present;
   - no modelling method is present;

3. hydrophysical arrays:
   - number of InvestigatedInterval elements containing `WaterContentAndConductivityAtSpecificSoilWaterPotential`;
   - number containing `ShapeHydraulicConductivityCurve`;
   - number containing both in the same InvestigatedInterval;

4. source modelling procedure values, descriptively only.

For each object assign the first applicable exclusion class in this fixed precedence:

- `NO_BODEMFYSISCH_SURVEY_PURPOSE`;
- `NO_MVG_MODELLING_METHOD`;
- `NO_HYDRAULIC_OBSERVATION_ARRAY`;
- `NO_CONDUCTIVITY_SHAPE_ARRAY`;
- `NO_COLOCATED_HYD_AND_SHAPE`;
- `WOULD_BE_ELIGIBLE`.

If any object is `WOULD_BE_ELIGIBLE`, this contradicts the P-LSAFE02 acquisition result and must be treated as an implementation/reproducibility defect before further inference.

## Acquisition integrity

Use the existing bounded BRO fetch retry behavior.

Every frozen object must receive an explicit disposition.

Any persistent fetch failure makes the diagnostic audit incomplete; do not infer population availability from a partial audit.

## Output

Report:

- counts by exclusion class;
- counts by survey-purpose presence;
- counts by modelling-method state;
- counts of objects with hydraulic arrays, shape arrays and colocated hydraulic+shape arrays;
- distinct modelling procedures and methods;
- per-object disposition.

Do not fit hydraulic parameters and do not compute lambda estimator results in this audit.

## Interpretation

The audit may explain why external validation evidence is unavailable in the current BRO service.

It may not justify broadening P-LSAFE02 after the fact. Any alternative population, for example accepting other survey purposes or another modelling method, requires a separately preregistered study.
