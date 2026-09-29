# F-PE-ELASTIC06B — stress-dependent elastic storage interpretation

Date: 2026-09-29

Status: PHYSICAL_INTERPRETATION_RESULT_NO_PRODUCTION_RULE

## Purpose

Clarify whether a physically based SWAP ELAS can be a soil-only constant or whether
the elastic storage implied by soil-mechanical data is also state/stress dependent.

## Recompression mechanics

For an oedometer swelling/recompression line written in the conventional
`e - log10(sigma')` form, the recompression index `Cr` gives locally:

`de = -Cr * d(log10 sigma')`.

The one-dimensional coefficient of volume compressibility is:

`mv = -de / ((1+e) d sigma')`.

Therefore the local tangent relation is:

`mv = 0.434294... * Cr / ((1+e) * sigma')`.

The corresponding skeletal contribution to specific storage is approximately:

`Ss_skeleton = gamma_w * mv`

for fixed total stress, with water compressibility added separately when required.

Thus a constant `Cr` does **not** imply a constant `Ss`; `Ss` scales
approximately as `1/sigma'` within the simple log-stress recompression model.

This relation is standard oedometer mechanics and is consistent with published
stress-dependent groundwater-storage formulations.

## Literature anchors

- Standard oedometer mechanics defines constrained modulus `M=1/mv` and notes
  that it depends on current stress and stress history.
- Soil-mechanics references relate constrained modulus in the overconsolidated
  regime to recompression index `Cr` through the same `(1+e) sigma'/Cr`
  structure.
- Stress-dependent groundwater deformation models explicitly obtain
  `Ss(sigma') proportional to 1/sigma'` when the skeletal constitutive law is
  based on recompression/compression indices.

Useful sources:
- UWE Geocal, *Compression and swelling*, one-dimensional modulus/compressibility.
- Wisconsin DOT WHRP 0092-10-10, equations relating `Cr`, `mv` and constrained modulus.
- coupled stress-dependent groundwater-deformation formulation, Water 2019, 6(3), 78.

## Consequence for Pim Dik's 1e-6 cm^-1

`ELAS = 1e-6 cm^-1 = 1e-4 m^-1` corresponds to:

`mv ~= Ss/gamma_w ~= 1.02e-8 Pa^-1`

when the water-compressibility contribution is neglected.

That is equivalent to a one-dimensional constrained modulus of approximately:

`M ~= 98 MPa`.

This is a useful reference stiffness, not a universal material constant.

## Illustrative sensitivity

Using the tangent recompression relation only as an order-of-magnitude
illustration:

`Ss_skeleton = gamma_w * 0.4343 * Cr / ((1+e) sigma')`.

For a fixed `Cr` and void ratio:
- doubling effective stress halves `Ss`;
- shallow low-stress soil has a larger tangent elastic storage than the same
  material under larger effective overburden;
- stress history/preconsolidation determines whether the recompression relation
  is even the relevant branch.

Therefore assigning one ELAS solely from texture or MvG class discards a
first-order mechanical state variable.

## Relation to agricultural-soil decompression data

Agricultural-soil studies report decompression/swelling indices that vary with
bulk density, organic matter, clay and moisture. Those indices should not be
inserted directly into SWAP as ELAS.

A defensible conversion additionally requires:
- definition/base of the logarithmic stress measure;
- void ratio or porosity;
- representative current effective stress;
- confirmation that the response is on the elastic/recompression branch;
- distinction between one-dimensional constrained response and any alternative
  modulus definition.

## Architectural implication

Two model levels should be distinguished.

### Legacy-compatible scalar ELAS

Keep the now-admitted SWAP5 representation:
- explicit active flag;
- scalar per layer/node in `cm^-1`.

For this level, a soil-data generator may assign a representative ELAS using
soil class plus a declared reference-stress convention.

### Modern physical successor

A later research model may parameterize mechanical properties instead of ELAS
directly, for example:
- recompression/swelling index or constrained-modulus parameters;
- porosity/void ratio;
- preconsolidation/stress-history descriptor.

The runtime would then derive tangent `Ss` from current/reference effective
stress.

This is a separate constitutive-model development and must not be smuggled into
F-PE-ELASTIC05/08/09.

## Decision

The phrase “ELAS driven by soil parameters” remains correct for ownership, but a
physically modern generator likely needs both:

`soil mechanical parameters + effective-stress/state convention -> ELAS or tangent Ss`.

Classification:

`SOIL_OWNED_BUT_NOT_NECESSARILY_SOIL_ONLY_CONSTANT`.

No production default or stress-dependent implementation is admitted here.
