# F-MACRO-ALT27/28 — wall-exchange parameter reduction and identifiability

Date: 2026-10-01

Status: QUALIFIED_RESEARCH_RESULT / EMPIRICAL_SORPTIVITY_PAIR_REMOVED / TWO-PARAMETER_WALL_CORE_SUPPORTED

Baseline: integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b

## Source/theory result

SWAP uses the larger of two unsaturated lateral exchange rates: Philip/sorptivity absorption under dry conditions and Darcy exchange under wet conditions. The recovered source also shows the Darcy term scaling with ShapeFacMp, matrix K and inverse polygon-size squared.

The user-facing sorptivity controls separate two alternative parameterisations. SWSORP chooses hydraulic-derived Parlange sorptivity or an empirical curve. SORPMAX and SORPALFA belong only to the empirical curve. The leading RFM therefore removes SWSORP, SORPMAX and SORPALFA and keeps the hydraulic-derived route.

SORPFACPARL carries different information: it modifies the hydraulic-derived wall sorptivity and can represent wall coatings or reduced contact efficiency. RFM keeps this information role as an optional dimensionless chi_wall, neutral value 1.

## Geometry scale

The reduced vertical connectivity parameter p does not determine horizontal matrix-block size. Lateral exchange therefore still needs one characteristic exchange length ell_ex unless ped/crack spacing is independently measured or derived.

ShapeFacMp is a narrow theoretical geometry correction for Darcy exchange. Because theory places it roughly between 1 and 2, the leading RFM fixes or derives it rather than treating it as another calibration degree of freedom.

## Identifiability screen

For parameter information only, the screen uses the theory-aligned dependencies:

    q_philip ~ chi_wall * (4/ell_ex) * S_wall * Delta sqrt(t)
    q_darcy  ~ f_shape * 8*K*|Delta h|/ell_ex^2 * Delta t
    q_wall   = max(q_philip, q_darcy)

Across dry-to-wet regimes the two-parameter core chi_wall + ell_ex has singular values about 3.17 and 0.51 and condition number about 6.24. Both directions are identifiable because dry cases constrain chi_wall/ell_ex while wet Darcy cases constrain 1/ell_ex^2.

With dry Philip-dominated cases only, the sensitivity columns are perfectly anti-correlated and the second singular value collapses to numerical zero. Thus dry exchange data alone cannot separate wall efficiency from exchange length.

If chi_wall, ell_ex and f_shape are all free, the third singular value is about 4e-15: only two independent scale combinations are observable. A freely calibrated ShapeFacMp is therefore not supported without independent geometry evidence.

## Leading wall core

Derived/state quantities:

    raw wall sorptivity from matrix hydraulics
    matrix K and lateral head gradient
    wall-event sorptivity and wall-event age

Candidate free wall parameters:

    chi_wall  — wall/contact efficiency
    ell_ex    — effective lateral matrix exchange length

Removed/fixed from the leading candidate:

    SWSORP
    SORPMAX
    SORPALFA
    free ShapeFacMp

## Complete reduced parameter core after ALT28

Surface/connectivity:

    sigma_B
    f_MB
    p

Wall exchange:

    ell_ex
    chi_wall

So the leading RFM is currently a five-high-level-parameter model before independent structural derivation of ell_ex. If ell_ex is supplied from ped/crack geometry and wall repellency is absent, the operational free core can fall back toward three parameters.

## Decision

EMPIRICAL SORPTIVITY PAIR: remove from leading RFM.
SWSORP switch: remove from leading RFM.
ShapeFacMp: fix or derive, not calibrate jointly.
chi_wall + ell_ex: structurally supported two-parameter wall core.

## Next

ALT29 should test whether ell_ex can be obtained from measurable ped/crack spacing with acceptable uncertainty. No new wall-transfer coefficient should be introduced.
