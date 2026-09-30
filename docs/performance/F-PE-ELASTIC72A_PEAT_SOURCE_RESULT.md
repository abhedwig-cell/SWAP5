# F-PE-ELASTIC72A — peat / high-organic physical-storage source audit result

Date: 2026-09-30

Status: QUALIFIED_NEGATIVE_SOURCE_FEASIBILITY_RESULT

Branch:
`research/f-pe-elastic72-peat-physical-storage`

Baseline:
`integration/f-ci-canonical@f9133b92cd7d128838029a162ee607bb8ba69689`

Workflow run:
`36760261048`

Job:
`110040720986`

Artifact:
`11118119672`

Artifact digest:
`sha256:44c9567859ae67d84fb05df651a860195a6f1944ef6a14460fdc825cb01ea992`

## Local preflight

Before interpreting the remote source audit, the parser/classification kernel was
compiled and exercised in a local runtime on synthetic BHR-GT XML.

The local checks covered:
- explicit `peatType` -> PEAT-EVIDENCE;
- `organicMatterContent > 15%` without peatType -> HIGH_ORGANIC_EVIDENCE;
- <=15% organic matter -> negative control;
- non-settlement interval -> excluded;
- direct volumetric density and water-content field extraction.

Result:
PASS.

The local runtime had no outbound DNS/network access, so official BRO retrieval
could not be performed locally. GitHub Actions was therefore used only for the
network-dependent bounded acquisition/evidence run, not as the development
environment.

## Population

The live BHR-GT settlement query returned:
- 693 unique object IDs;
- SHA-256:
  `7383c26e22b3f5dfaf717f7780a362edea4d508a60916b7fda122860944269d1`.

This differs from ELASTIC10:
- previous count: 692;
- previous SHA:
  `606a4785a5bea70e443a8729bfd132b9ddebe1ea799e78585ed3ba2f54f54667`.

The drift was reported rather than silently coerced.

After excluding all earlier ELASTIC10/11 pilot, calibration and holdout IDs, the
preregistered deterministic discovery sample contained 160 objects.

Discovery sample SHA-256:
`42adb7c372126bf0833618f4050597a79c2f0f3c938c758120c30fc68346496f`.

## Source yield

Across the 160-object discovery sample:
- settlement-bearing investigated intervals: 420;
- explicit PEAT-EVIDENCE objects: 0;
- explicit PEAT-EVIDENCE intervals: 0;
- HIGH_ORGANIC_EVIDENCE objects: 4;
- HIGH_ORGANIC_EVIDENCE intervals: 5.

Preregistered classification:

`DIRECT_BHRGT_PEAT_ROUTE_INSUFFICIENT`.

Descriptor classification:

`PEAT_DESCRIPTOR_NOT_READY`.

The primary peat feasibility gate therefore fails by a large margin, not
marginally.

## High-organic observations

The five high-organic non-peat intervals are:

1. `BHR000000376818`, 3.08-3.13 m:
   - organic matter 42.2%;
   - volumetric mass density 1.076;
   - water content 300.0.

2. `BHR000000376819`, 2.47-2.52 m:
   - organic matter 86.9%;
   - volumetric mass density 1.429;
   - water content 112.9.

3. `BHR000000376819`, 3.29-3.34 m:
   - organic matter 32.6%;
   - volumetric mass density 1.069;
   - volumetric mass density solids 1.9990;
   - water content 403.8.

4. `BHR000000376811`, 3.28-3.33 m:
   - organic matter 91.6%;
   - volumetric mass density 0.997;
   - volumetric mass density solids 1.4220;
   - water content 540.9.

5. `BHR000000376816`, 6.86-6.91 m:
   - organic matter 73.5%;
   - volumetric mass density 1.128;
   - volumetric mass density solids 1.4080;
   - water content 271.3.

All five have direct wet volumetric density and water-content observations.

However, none has direct `peatType`, `organicSoilTexture`, or
`organicSoilConsistency` in the same investigated interval.

Under the preregistration they therefore cannot be upgraded post hoc to
PEAT-EVIDENCE.

## Interpretation

This is a qualified negative source-feasibility result, not evidence that peat
cannot have an ELAS representation.

It establishes that the current official BHR-GT settlement route, under strict
same-interval source binding, does not provide enough explicit peat-labelled
mechanical observations for a peat-specific calibration campaign.

The five high-organic intervals are physically interesting but do not satisfy
the preregistered peat structural-provenance requirement.

Therefore the correct next step is not:
- relax the peat definition after seeing the result;
- extrapolate the mineral ELASTIC11 relation;
- fit a peat scalar from five high-organic intervals;
- use solver behavior as a peat calibration target.

## External source reconnaissance

Independent Dutch peat-monitoring evidence supports a different source strategy.

NOBV/Deltares field studies report substantial reversible vertical movement in
saturated peat layers that is strongly related to groundwater dynamics.
The 2025 HESS study on Dutch peat meadows reports that deformation of the
saturated subsurface contributes materially to seasonal vertical movement and
describes the saturated deformation as reversible in the studied period.

A separate open Zegveld dataset provides long-term depth-resolved peat
subsidence, groundwater levels, meteorology and layer-thickness information.
That dataset is particularly strong for separating long-term irreversible
subsidence/consolidation from profile depth, but its annual temporal resolution
is not by itself sufficient to estimate fast reversible poroelastic storage.

The NOBV extensometer route is therefore more promising for the SWAP ELAS
question because it combines:
- groundwater dynamics;
- depth-resolved vertical deformation;
- saturated peat layers;
- seasonal/reversible behavior.

## Decision

Close the direct BHR-GT peat-labelled calibration route as:

`DIRECT_BHRGT_PEAT_ROUTE_INSUFFICIENT`.

Retain the five high-organic intervals as a small descriptive/mechanical
cross-check population only.

The next justified physical work unit is:

`F-PE-ELASTIC72B — NOBV reversible saturated-peat deformation source audit`.

Its first question should be data access and identifiability, not model fitting:
can groundwater-head changes and depth-resolved reversible strain be aligned
well enough to estimate a bounded layer-scale compressibility / Ss proxy while
excluding irreversible oxidation, shrinkage, consolidation and creep?

## Production boundary

No production change follows.

Unchanged:
- MINERAL generated ELAS remains qualified;
- PEAT remains RESEARCH_ONLY_NOT_AUTO_ASSIGNED;
- ORGANIC_RICH_NONPEAT remains RESEARCH_ONLY_NOT_AUTO_ASSIGNED;
- explicit/user ELAS remains allowed;
- no solver/timestep policy is altered.
