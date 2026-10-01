# F-MACRO-EMP01 — North-China quantitative ponded-regime qualification

Date: 2026-10-01

Status: QUALIFIED_BOUNDARY-REGIME_RESULT / QUANTITATIVE_PF_FRACTION_AVAILABLE / SIGMA_B_CALIBRATION_REJECTED

Canonical authority:

    integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

## Source

Zhang, J., Sun, Q., Wen, N., Horton, R., Liu, G. (2022).

    Quantifying preferential flows on two farmlands in the North China
    plain using dual infiltration and dye tracer methods.

Geoderma 428, 116205.

    DOI: 10.1016/j.geoderma.2022.116205

The article is open access. Table 2 reports replicate-level steady infiltration
rate (SIR), matrix infiltration rate (MIR), preferential infiltration rate
(PFIR), and PFIR/SIR.

## Boundary condition

The field SIR experiment uses a double-ring infiltrometer with approximately:

    5 cm maintained water head

and evaluates steady infiltration.

The matrix comparison uses packed disturbed-soil columns under constant-head
conditions.

Therefore this is a ponded/head-controlled quantitative PF experiment.

It is not an unponded/source-controlled event.

## Replicate result

### LY site

Nine field locations:

    PFIR/SIR range = 0.97 to 0.99
    mean           = 0.9811
    median         = 0.98

Preferential infiltration therefore dominates almost completely at LY.

The paper associates LY with abundant visible wormholes.

### SZ site

Eight usable field locations:

    PFIR/SIR range = 0.00 to 0.77
    mean           = 0.3938
    median         = 0.445

The spread is much larger than at LY.

Two locations are reported as PFIR=0 after MIR exceeded measured SIR within
instrument/error limits and the authors set MIR=SIR.

## New empirical information

This is one of the strongest quantitative preferential-water partition datasets
identified in the RFM program because it directly estimates:

    preferential infiltration / total steady infiltration.

The contrast is large:

    LY mean PF fraction ~= 98%
    SZ mean PF fraction ~= 39%.

This shows that structural soil class can shift the quantitative PF partition
by a very large amount under otherwise comparable ponded infiltration concepts.

## Why this does not identify sigma_B

The frozen RFM sigma_B parameter belongs to:

    unponded/source-controlled activation

where the incoming source competes with distributed matrix intake capacity.

The North-China experiment imposes positive surface pressure/head and measures
steady ponded infiltration.

Using Table 2 to fit sigma_B would therefore mix two different boundary
problems.

EMP01 rejects that calibration even though the numeric target is attractive.

This preserves the ALT47/ALT54 regime boundary.

## What the dataset does qualify

The data become a strong future gate for an explicit ponded preferential-flow
owner.

Any future RFM-compatible ponded mode should be capable, without retuning
unponded sigma_B event by event, of representing at least the existence of:

    near-complete preferential partition in a wormhole-rich soil class
    and
    mixed matrix/preferential partition in another farmland soil class.

The dataset also reinforces that visible dye alone may underestimate water
partition in strongly macroporous soil: the paper reports much smaller
dye-derived preferential contribution at LY than the DI method.

That is independently consistent with ALT49's rejection of a naive direct
morphology-to-water-volume mapping.

## Decision

    DIRECT_QUANTITATIVE_PF_FRACTION = AVAILABLE
    PONDED_BOUNDARY_REGIME = CONFIRMED
    LY_PF_FRACTION_MEAN = 0.9811
    SZ_PF_FRACTION_MEAN = 0.3938
    LARGE_STRUCTURAL_CLASS_EFFECT = SUPPORTED
    CALIBRATE_UNPONDED_sigma_B_FROM_THIS_DATA = REJECTED
    FUTURE_PONDED_RFM_GATE = STRONG
    DYE_AS_DIRECT_WATER_PARTITION = FURTHER_WEAKENED
    RFM_PHYSICS_CHANGE = NONE

## Consequence for the empirical program

The remaining decisive gap for sigma_B is now exceptionally specific:

    quantitative matrix-versus-preferential source partition
    under unponded/source-controlled forcing
    with independently known hydraulic state.

NEON supplies event ordering but not amount.

North-China supplies amount but in the wrong boundary regime.

Spechtacker supplies conservative depth mass and held-out profile validation,
but not a direct matrix-versus-preferential source partition.

That gap should drive the next acquisition or controlled experiment.
