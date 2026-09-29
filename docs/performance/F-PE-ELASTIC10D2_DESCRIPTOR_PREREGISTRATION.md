# F-PE-ELASTIC10D2 — source-bound mechanical descriptor extension preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_DESCRIPTOR_EXTENSION_RESULTS

Parent:
`F-PE-ELASTIC10D_CORPUS_RESULT.md`.

## Purpose

Audit additional source-bound specimen descriptors relevant to mechanical
specific storage before selecting any physical predictor model.

This phase operates only on the already fetched Phase-D calibration artifact.

No new BHR-GT object may be fetched.

The 18 frozen holdout objects remain unopened.

## Frozen evidence input

GitHub Actions run:
`36540905498`.

Artifact:
- id `11021065518`;
- digest
  `sha256:0c0a6c44367966e291cf15177989d2abe8f25f6192259f0e6029bd4aabd3a903`.

Object population:
the exact 36 Phase-D calibration objects only.

## Source motivation

Current official BHR-GT catalogue semantics expose specimen-level fields
relevant to settlement/compression mechanics that were not in the original
Phase-D descriptor list.

In particular, made specimens for loading may expose:

- `dryVolumetricMassDensity`;
- `volumetricMassDensity`;
- `waterContent`.

The catalogue also exposes contextual specimen fields including:

- `sampleMoistness`;
- `saturated`;
- `underLoad`;
- `verticalStrain`.

This phase audits these fields as **reported source values** only.

## Frozen fields

For every settlement determination and every valid unload/reload target, audit:

1. `dryVolumetricMassDensity`
2. `volumetricMassDensity`
3. `volumetricMassDensitySolids`
4. `waterContent`
5. `sampleMoistness`
6. `saturated`
7. `underLoad`
8. `verticalStrain`
9. `geotechnicalSoilName`
10. `organicMatterContent`
11. `organicMatterContentClass`
12. `sandMedianClass`
13. `specialMaterial`

For every value preserve:
- XML local-name;
- raw textual value;
- unit attribute when present;
- nearest containing settlement determination or investigated interval;
- BRO ID and interval depth.

## No derivation in D2

Do not calculate:

- dry density from wet density + water content;
- porosity;
- void ratio;
- saturation degree;
- effective overburden stress;
- transformed predictor variables.

Even if such derivations are physically obvious, their use in model selection
must be separately frozen after source coverage is known.

## Coverage gates

Report coverage separately for valid unload and valid reload targets, and by
unique object.

### Dry-density predictor eligibility

`dryVolumetricMassDensity` becomes eligible for Phase-E candidate models only
if it is source-bound for at least:

- 50% of valid unload targets; and
- 15 distinct calibration objects.

### Solids-density / porosity research eligibility

A later porosity derivation may be preregistered only if both source-bound
`dryVolumetricMassDensity` and `volumetricMassDensitySolids` are jointly
available for at least:

- 25% of valid unload targets; and
- 10 distinct calibration objects.

This gate does not itself authorize the porosity formula.

### Categorical descriptor eligibility

A categorical descriptor is eligible only if:
- present for at least 15 calibration objects; and
- at least two categories each occur in at least 5 objects.

Otherwise retain it as descriptive provenance only.

## Outcome

F-PE-ELASTIC10D2 selects no statistical model.

It only freezes which source-bound variables have enough coverage to enter the
subsequent Phase-E model preregistration.
