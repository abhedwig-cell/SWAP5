# F-PE-ELASTIC72B — NOBV reversible saturated-peat deformation identifiability preregistration

Date: 2026-09-30

Status: PREREGISTERED_IDENTIFIABILITY_ONLY

Baseline:
`research/f-pe-elastic72-peat-physical-storage@970b3f589bf20fcfd75726344d34b5266e3db1d1`

Canonical reconciliation:
`integration/f-ci-canonical@f133e47f8f7899f3d70db79f9ea63fbb730b2da0`

Parent result:
`F-PE-ELASTIC72A_PEAT_SOURCE_RESULT.md`

## Purpose

Determine whether NOBV/Deltares high-frequency extensometer and groundwater
observations can identify the reversible saturated-soil skeleton specific
storage term needed by SWAP ELAS for peat/high-organic soils.

This work unit does not fit a production peat model and changes no production
source.

## Physical relation

ELASTIC10 defined the skeleton contribution as

`Ss_skeleton = gamma_w * mv`

with one-dimensional constrained compressibility

`mv = d(epsilon_z) / d(sigma'_v)`.

For a saturated layer under approximately constant total vertical stress and a
hydrostatic pore-pressure perturbation driven by hydraulic-head change `dH`:

`d(sigma'_v) ~= -gamma_w * dH`.

Therefore:

`Ss_skeleton ~= -d(epsilon_z)/dH`.

This is the primary identifiability relation.

For two extensometer anchors bounding a layer of reference thickness `L`:

`epsilon_z(t) = (Delta z_upper(t) - Delta z_lower(t)) / L`.

No fluid-compressibility term is inferred in this work unit. The target is the
same skeleton-specific storage family used in ELASTIC10/11.

## External observational authority

Primary candidate source:
van Asselen et al. (2025), Hydrology and Earth System Sciences 29, 1865-1894,
DOI 10.5194/hess-29-1865-2025.

The study reports:
- extensometer measurements recorded hourly;
- multiple anchor levels, with layer deformation obtainable from displacement
  differences between anchors;
- high-resolution local phreatic groundwater observations;
- millimeter-scale elevation measurement capability;
- groundwater-level changes of tens of centimeters;
- near-immediate deformation response at daily/weekly timescales;
- largely reversible deformation in saturated soil at most studied sites;
- explicit attribution to pore-pressure/effective-stress variation.

Raw data are not openly downloadable from the paper. The paper states that
raw data are stored at Deltares/NOBV and may be requested from the authors or
via info@nobveenweiden.nl.

## Identifiability requirements

A layer/cycle is eligible only if all are satisfied:

1. both bounding extensometer anchors are available at the same timestamps;
2. reference layer thickness is known;
3. the complete analyzed layer remains below the phreatic groundwater level
   throughout the selected cycle, with a conservative saturation margin;
4. local groundwater-head observations are available at sufficient temporal
   resolution and represent the extensometer location;
5. there is no documented intervention, sensor reset or reference-anchor issue
   during the selected interval;
6. a reversible loading/unloading cycle can be isolated without relying on a
   long-term subsidence trend as the target;
7. the groundwater-head excursion is materially larger than sensor uncertainty.

## Primary estimator

Within one accepted reversible cycle, estimate the slope of layer strain versus
hydraulic head.

Primary simple estimator:

`Ss_cycle = -slope(epsilon_z, H)`.

Units:
- with strain dimensionless and H in m: Ss in m^-1;
- convert to cm^-1 by division by 100.

The primary estimator is descriptive until hysteresis/time-lag checks pass.

## Reversibility and lag gates

A scalar local Ss candidate may advance only if:

- falling-head and rising-head branches have the same sign-consistent response;
- branch-specific slope magnitudes agree within a preregistered tolerance to be
  frozen after raw-data access but before examining site outcomes;
- residual long-term drift over the cycle is small relative to reversible
  excursion;
- the cross-correlation peak between head and deformation occurs at a lag
  physically compatible with a quasi-static layer response;
- a lagged model does not materially outperform the quasi-static slope solely
  because long-term creep is being absorbed.

If these gates fail systematically, the correct outcome is a state/history-aware
or no-static-scalar model, not a forced Ss value.

## Layer attribution

Use differential anchor displacement, not surface displacement alone.

The target layer must be bounded by actual anchors. Mixed peat/clay intervals
may not be labelled peat-specific unless lithological information supports the
bounded layer interpretation.

The 0.05 m surface anchor and approximately 0.80 m anchor used in the published
summary are not automatically sufficient for peat-specific attribution because
that interval can include unsaturated soil. Deeper anchor pairs are preferred
when they bound permanently saturated peat.

## Local synthetic preflight

Before any NOBV raw-data request is interpreted, an offline synthetic
identifiability audit is required.

Frozen illustrative scenario:
- 90 days;
- hourly sampling;
- 2.0 m layer;
- 0.20 m characteristic head amplitude;
- 500 Monte Carlo replicates;
- displacement noise scenarios 0.1, 0.5 and 1.0 mm;
- Ss test values spanning 1e-5 to 1e-3 m^-1.

This preflight is not peat calibration evidence. It establishes whether the
proposed estimator can resolve coefficients in the range relevant to the
existing ELAS work under plausible measurement precision.

## Advancement outcomes

Possible ELASTIC72B outcomes:

`NOBV_SS_IDENTIFIABLE_STATIC_LOCAL`
- multiple saturated peat layers/cycles support stable reversible slopes.

`NOBV_SS_IDENTIFIABLE_STATE_AWARE_ONLY`
- signal is real, but slopes depend materially on state, direction, stress
  history or lag.

`NOBV_SS_NOT_IDENTIFIABLE_FROM_AVAILABLE_DATA`
- data geometry, saturation state, precision or provenance do not support a
  defensible estimate.

No outcome authorizes automatic peat ELAS assignment by itself.

## GitHub Actions policy

No GitHub Action is created for ELASTIC72B preregistration or synthetic
preflight.

Offline derivation and synthetic tests run locally.

A remote workflow may be added later only if needed for immutable qualification
evidence after raw data are available and the method is already debugged.

## Production boundary

Unchanged:
- MINERAL generated ELAS remains qualified;
- PEAT and ORGANIC_RICH_NONPEAT remain RESEARCH_ONLY_NOT_AUTO_ASSIGNED;
- explicit/user ELAS remains possible;
- timestep and solver policy remain separate from physical parameterization.
