# F-PE-ELASTIC72 — peat / high-organic physical-storage source audit preregistration

Date: 2026-09-30

Status: PREREGISTERED_BEFORE_SOURCE_AUDIT

Baseline:
`integration/f-ci-canonical@f9133b92cd7d128838029a162ee607bb8ba69689`

Branch:
`research/f-pe-elastic72-peat-physical-storage`

Parent authorities:
- F-PE-ELASTIC11 physical predictor closeout;
- F-PE-ELASTIC13 physical parameter-policy result;
- F-PE-ELASTIC46 production-shaped OFF / FIXED_1E6 / GENERATED characterization;
- F-PE-ELASTIC_PHYSICAL_PARAMETERIZATION_CLOSURE_2026-09-30.md.

## Purpose

Resolve the remaining physical parameterization gap for PEAT and
ORGANIC_RICH_NONPEAT.

This phase does not fit a peat model. It tests whether official Dutch BHR-GT
settlement data contain enough source-bound peat/high-organic mechanical
evidence to justify a separate constitutive calibration campaign.

Solver runtime, timestep behavior, convergence counts, MultiSWAP timing and
performance metrics are excluded from the physical decision.

## Scientific premise

PEAT is not assumed to be a continuation of the mineral ELASTIC11 M1 relation.

Candidate peat mechanisms include pore-structure change, reversible
compression/swelling, stress history, decomposition state, water content and
delayed/viscous compression. A static scalar Ss can advance only as a bounded
small-strain/recompression representation supported by direct evidence.

## Frozen search population

Use the ELASTIC10 BHR-GT settlement query over the Netherlands bounding box,
with `analysisType=zetting`.

ELASTIC10 reference:
- 692 unique IDs;
- SHA-256 `606a4785a5bea70e443a8729bfd132b9ddebe1ea799e78585ed3ba2f54f54667`.

Any population drift is reported explicitly.

## Independent discovery sample

Exclude every earlier ELASTIC10/11 pilot, calibration and holdout ID.

Rank remaining IDs by:
`sha256("F-PE-ELASTIC72A|" + broId)`.

Fetch only the first 160 IDs.

All remaining eligible IDs stay unopened in ELASTIC72A and are reserved for a
later independent validation or expansion phase.

## Evidence classification

PEAT-EVIDENCE:
the same investigatedInterval that owns a settlement analysis contains a
non-empty `peatType`.

HIGH_ORGANIC_EVIDENCE:
no `peatType` and finite `organicMatterContent > 15%` in that same interval.

The 15% boundary is inherited from ELASTIC13 as an operational separator.

Free-text soil names are descriptive only and may not create the primary class.

## Required co-located descriptors

Record direct interval presence of:
- peatType;
- organicMatterContent;
- organicMatterContentClass;
- organicMatterContentClassNEN5104;
- organicSoilTexture;
- organicSoilConsistency;
- peatTensileStrength;
- volumetricMassDensity;
- volumetricMassDensitySolids;
- waterContent;
- geotechnicalSoilName;
- soilNameNEN5104.

No cross-depth borrowing is allowed.

## Primary feasibility gate

`DIRECT_BHRGT_PEAT_ROUTE_FEASIBLE` requires:
- at least 10 distinct objects with PEAT-EVIDENCE;
- at least 20 PEAT-EVIDENCE settlement intervals.

If either 3-9 objects or 5-19 intervals are observed:
`DIRECT_BHRGT_PEAT_ROUTE_SPARSE`.

Below those bounds:
`DIRECT_BHRGT_PEAT_ROUTE_INSUFFICIENT`.

This is source feasibility, not model qualification.

## Descriptor-readiness gate

For PEAT-EVIDENCE intervals, wet volumetric density and water content must each
have at least 80% direct coverage, and at least one peat-specific structural
descriptor among peatType, organicSoilTexture or organicSoilConsistency must
have at least 80% coverage.

Result:
- `PEAT_DESCRIPTOR_READY`, or
- `PEAT_DESCRIPTOR_NOT_READY`.

## No scalar assumption

If the source route is feasible, the next preregistered phase must compare:
1. bounded small-strain static Ss;
2. stress/state-aware Ss;
3. an explicit no-scalar-static-model outcome.

No coefficients may be fitted in ELASTIC72A.

## Production boundary

No production source changes.

PEAT and ORGANIC_RICH_NONPEAT remain RESEARCH_ONLY_NOT_AUTO_ASSIGNED until a
later physical model is independently qualified. Mineral generated ELAS,
explicit/user ownership and solver/timestep policy remain unchanged.
