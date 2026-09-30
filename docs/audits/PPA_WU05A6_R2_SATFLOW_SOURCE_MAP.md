# PPA-WU05-A6 R2 source map — saturated matrix/macropore exchange

Date: 2026-09-30

Status: EXACT_SOURCE_MAP / TYPED_IMPLEMENTATION_IN_PROGRESS

## Exact source

Authority: B1.11 SATFLOW in macrorate.f90.

## Relevant vertical range

SATFLOW is active only where the active macropore domain overlaps the relevant saturated matrix zone.

## Head convention

Macropore head: HMp = max(0, RefLev-Z).

Matrix head: HMa = H.

DelH = HMp-HMa.

If HMa < 0, saturated exchange is disabled.

## Three flow situations

1. DelH > 0: macropore water infiltrates into saturated matrix by Darcy resistance.
2. DelH < 0 and HMp > 0: saturated matrix exfiltrates into macropores by Darcy resistance.
3. DelH < 0 and HMp = 0: matrix exfiltration uses seepage-face resistance.

## Darcy resistance

For ordinary saturated exchange, reciprocal resistance is CDarcy.

For macro-to-matrix flow, the partially saturated top macropore compartment is weighted by SatFr.

For matrix-to-macro flow, the top saturated matrix compartment is weighted by its saturated thickness fraction.

## Seepage face

SWSEP=1 uses horizontal + vertical + radial resistance.

Otherwise B1.11 uses the Youngs seepage-potential expression:

RecRes = ShapeFacMp * 16 / DiPo^2 * KSatHor * Dz.

## Signed amount

B1.11 stores an intermediate signed amount:

FlwMtxSatDmCp = -FrReduQ * RecRes * DelH * dt.

Positive intermediate amount means matrix -> macropore.

Negative intermediate amount means macropore -> matrix.

The later QExc convention is the opposite sign:

QExc_to_matrix = macro_to_matrix - matrix_to_macro.

## Local oracle

For dt=0.1 d, CDarcy=0.01 and representative geometry:

- macro->matrix Darcy: 0.008 cm;
- matrix->macro Darcy: 0.010 cm;
- Youngs seepage-face matrix->macro: 0.5 cm;
- negative matrix head: zero saturated exchange.