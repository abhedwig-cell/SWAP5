# PPA-WU05-A26I — macropore-side head contract adjudication

Date: 2026-10-01
Status: QUALIFIED_CONCEPTUAL_CORRECTION
Baseline: integration/f-ci-canonical@f477f3fb7bf272757ac7a764bf9492883a521754

## Question

Define the macropore-side hydraulic head required by the A22A/A22B Darcy wall-exchange term without inventing a production default.

## Source authority

The SWAP macropore theory defines lateral Darcy exchange using the pressure-head difference between macropore water and matrix water. Macropore pressure head at depth z is derived from the macropore water-level elevation:

    h_mp(z) = phi_mp - z

and the lateral Darcy term uses h_mp - h_mt.

The same theory states that water flowing rapidly downward in macropores is treated as contracted films with small matrix contact area; lateral infiltration during that rapid downward passage is neglected. Water entering macropores is instead added to storage at the bottom, and stored water exchanges laterally over the wetted storage depth.

Supporting public sources:
- SWAP 3.2 theory, equations 6.32-6.34, pressure head h_mp from macropore water level phi_mp and depth z.
- Van Dam et al. (2008), Advances of Modeling Water Flow in Variably Saturated Soils with SWAP: rapid downward wall infiltration is neglected; trapped/stored macropore water exchanges with matrix.

## Adjudication

### Terminating IC endpoints

A22A remains physically compatible with the source concept because terminating IC water is stored.

For a terminating endpoint, the macro-side head must be hydrostatic and derived from the candidate/accepted endpoint water level and the explicit endpoint geometry. It must not be hard-coded to zero.

The current reduced RFM state stores endpoint areic water amount but the immutable configuration does not yet contain a macropore storage cross-sectional/volume mapping that converts that amount into water-column elevation phi_mp. Endpoint depth alone is insufficient.

Therefore a production Darcy head for IC storage cannot yet be numerically derived from the current reduced state.

Philip/sorptivity exchange remains independently defined, but the admitted A22A operator takes max(Philip,Darcy); silently setting Darcy Delta h to zero or to -h_matrix would change that operator.

### Fast-through MB

The leading A22B route has no persistent MB reservoir after the interval. Source authority says lateral exchange of the rapidly descending film is neglected.

Therefore applying the A22B full-contact-length Philip/Darcy wall exchange during fast-through passage is not source-consistent for the leading reduced production route.

The production-compatible leading MB fate is:

    MB input -> distinct deep receipt

with zero wall exchange during rapid passage.

This is a conceptual correction to the intended production composition of A22B, not a parameter adjustment. The standalone A22B operator remains a qualified callable primitive for a future mode with an explicit stored/wetted MB water column, but it is not the production owner for leading fast-through MB.

## Consequences for A26

A26 must not invent phi_mp from endpoint depth or assume h_mp=0.

Before live RFM backend admission, one of two bounded choices is required for IC:

1. add and qualify structural storage geometry sufficient to convert endpoint areic storage to phi_mp, then use h_mp(z)=phi_mp-z in the A22A Darcy term; or
2. qualify a narrower IC exchange operator that is explicitly Philip-only for the reduced model and no longer claims the A22A max(Philip,Darcy) law.

Choice 1 preserves the source-backed SWAP wall law and is the preferred continuation.

For MB, no new head owner is required in the leading fast-through route because wall exchange during passage is removed from that production route and MB input is published as distinct deep receipt.

## Decision

    IC_MACRO_HEAD = HYDROSTATIC_FROM_MACROPORE_WATER_LEVEL
    IC_ZERO_HEAD_SHORTCUT = REJECTED
    IC_CURRENT_STATE_SUFFICIENT_FOR_PHI_MP = NO
    MB_FAST_THROUGH_WALL_EXCHANGE = REJECTED_FOR_LEADING_PRODUCTION_ROUTE
    MB_FAST_THROUGH_FATE = DISTINCT_DEEP_RECEIPT
    A22B_STANDALONE_PRIMITIVE = RETAINED_BUT_NOT_LEADING_RUNTIME_OWNER
    NEXT = qualify minimal IC storage-geometry -> water-level mapping, then resume A26
