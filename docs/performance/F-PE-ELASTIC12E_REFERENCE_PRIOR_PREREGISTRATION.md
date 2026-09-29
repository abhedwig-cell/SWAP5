# F-PE-ELASTIC12E — 20 kPa root-zone reference-stress ELAS prior

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_REFERENCE_PRIOR_EXTRACTION

Parents:
- F-PE-ELASTIC11D deep-mechanical holdout;
- F-PE-ELASTIC12A root-zone water-content transfer;
- F-PE-ELASTIC12C direct <=25 kPa mechanical targets;
- F-PE-ELASTIC12D frozen M5 low-stress falsification.

## Purpose

Construct a first physically interpretable **constant soil-layer ELAS prior**
without pretending that the constant equals the instantaneous tangent storage at
every root-zone effective stress.

The prior is defined at one declared reference stress and one declared wet
material state.

It is a parameter prior, not a production assignment.

## Why a reference stress is required

The qualified mechanical relation is approximately proportional to
`1 / sigma'`.

Actual root-zone effective stress approaches zero near the soil surface. A
literal state-dependent evaluation would therefore be singular and would no
longer represent the legacy scalar ELAS material parameter.

A constant ELAS must consequently be tied to an explicit reference-stress
convention.

## Frozen reference stress

Use exactly:

`sigma_ref = 20 kPa`.

This value is not selected after the F-PE-ELASTIC12C/D result.

It was one of the five fixed mechanical-stress scenarios preregistered in
F-PE-ELASTIC12A before the low-stress target search.

New evidence now changes its qualification status:

- F-PE-ELASTIC12C contains explicit R3 unload observations spanning below and
  above 20 kPa;
- lowest direct unload stress in the qualified target set: ~18.76 kPa;
- F-PE-ELASTIC12D shows the frozen M5 relation survives independent low-stress
  falsification in this regime.

Thus 20 kPa is retained as a declared **reference stress**, not inferred as the
actual stress of every root-zone layer.

## Frozen material state

Use only:

`WET_MAX_THETA`

from the existing F-PE-ELASTIC12A source-bound BHR-P transfer.

Reason:
legacy ELAS is active on the saturated branch `h >= 0`. The material prior
should therefore use the wet/saturated end of the source hydraulic observation
set rather than an arbitrary transient SWAP water state.

No interpolation is introduced.

## Frozen source authority

F-PE-ELASTIC12A artifact:

- workflow run: `36536601142`;
- artifact: `f-pe-elastic12a-rootzone-transfer`;
- artifact id: `11018303280`;
- artifact digest:
  `sha256:d9a9b49ec23fef845afafe1c37ed65bbaf0b487357d73266b1ec149127d96296`.

Use the persisted scientific postimage `transfer-a.json`.

Required population:
- exactly 21 clean BHR-P intervals;
- exactly one `WET_MAX_THETA` row at `20 kPa` per interval.

## Frozen M5 relation

No refit:

`log10(Ssk_cm_inv) =
 -5.213084677584852
 + 1.0383403589566573 * log10(water_content_pct)
 - log10(20)`.

The existing F-PE-ELASTIC12A conversion remains unchanged:

`water_content_pct = 100 * theta * 0.9982 / rho_d`.

## Qualification classes per interval

### REFERENCE_PRIOR_SUPPORTED

Only when:
- exact clean BHR-P interval authority is preserved;
- dry bulk density is source-bound;
- wet theta is source-bound;
- converted water content is inside the frozen M5 calibration water domain;
- projected Ssk is finite and positive.

### WATER_DOMAIN_EXTRAPOLATION

When source/provenance is valid but converted wet water content lies outside the
formal M5 calibration water domain.

These values are reported as sensitivity only and are not included in the
qualified prior population.

No clipping to the domain is allowed.

## Required outputs

For all 21 intervals record:
- BRO ID;
- exact interval depths;
- horizon code where source-bound;
- organic matter where source-bound;
- dry bulk density;
- wet theta;
- converted gravimetric water content;
- water-domain classification;
- 20-kPa reference Ssk/ELAS prior;
- ratio relative to `1e-6 cm^-1`.

Report separately:
- supported interval count;
- extrapolative interval count;
- supported prior min/median/max;
- all-interval sensitivity min/median/max;
- count above/below/equal order of magnitude relative to `1e-6`.

## Interpretation rule

The output may be called:

`20-kPa wet-state physical ELAS reference prior`.

It may not be called:
- actual instantaneous root-zone specific storage;
- a calibrated BOFEK ELAS table;
- a universal default;
- a validated field-scale parameter.

## Scale-transfer boundary

Even a REFERENCE_PRIOR_SUPPORTED row remains a transfer from BHR-GT specimen
mechanics to BHR-P root-zone material descriptors.

F-PE-ELASTIC12E qualifies the **mechanical/predictor-domain construction**, not
field-scale representativeness.

## Prohibited

Do not:
- change 20 kPa after seeing the distribution;
- use actual SWAP head to alter the reference stress;
- fit a bias correction from F-PE-ELASTIC12D;
- use the five low-stress targets to refit M5;
- clip wet water content;
- impute missing descriptors;
- use solver performance;
- assign these values to Staringreeks/BOFEK production classes.

## Success criterion

The workunit succeeds if:
- all 21 frozen intervals are reproduced;
- exactly 16 intervals retain the previously recorded in-domain wet-water
  classification;
- the supported prior population is finite, deterministic and provenance
  complete.

Any population or domain-count drift is a failure.

## Downstream rule

Only after this reference-prior population is recorded may a successor study
how to generalize from the 21 source intervals to broader Dutch soil classes.

That successor must keep organic/peat and mineral applicability explicit and
must not fill unsupported classes by arbitrary averaging.
