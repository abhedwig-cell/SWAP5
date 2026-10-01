# F-MACRO-ALT29 — derive wall-exchange length from measurable structure

Date: 2026-10-01

Status: QUALIFIED_RESEARCH_RESULT / ELL_EX_DERIVABLE / DEFAULT_CALIBRATION_ROLE_REJECTED

Baseline: integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b

## Result

SWAP's macropore geometry defines an effective matrix polygon diameter d_pol. The effective wall area per bulk volume is 4/d_pol, and the lateral distance from macropore wall to matrix-polygon centre is x_pol = 0.5 d_pol. The reduced RFM exchange length is therefore the existing geometric role ell_ex = x_pol, not a new calibration concept.

For cylindrical macropores, published SWAP/HYDRUS geometry work gives:

    d_pol = 2 r_m / w_f

with r_m the macropore radius and w_f the relative macropore area/volume fraction. Therefore:

    ell_ex = r_m / w_f

If r_m and w_f are measured, ell_ex is directly derived and should not be calibrated by default.

## Mixed cracks and holes

SWAP also provides an equivalent polygon diameter for mixed cracks and hole-shaped macropores:

    1/d_pol = 1/d_pf + pi*sum(N_h,i*d_hf,i)/(4*A_h)

so crack/ped spacing and counts/diameters of hole-shaped macropores can be reduced to the same effective exchange length:

    ell_ex = 0.5 d_pol

## Independent physical support

Dual-permeability literature commonly uses an exchange distance approximated by half the average matrix-block width. Experimental solute-diffusion work has found effective diffusion radii comparable to half-spacing of aggregate fissures. This supports treating ell_ex as measurable structural geometry rather than an unconstrained transfer coefficient.

## Uncertainty propagation

For cylindrical macropores ell_ex = r_m/w_f, hence to first order:

    d ln ell = d ln r_m - d ln w_f

For independent equal relative standard uncertainties u in r_m and w_f:

    sigma_rel(ell) ~= sqrt(2) u

With 10% uncertainty in both, ell_ex has about 14% independent 1-sigma uncertainty. Worst-case ell_ex ranges from 0.818 to 1.222 of nominal. Philip exchange, scaling as ell_ex^-1, varies over the reciprocal range; Darcy exchange, scaling as ell_ex^-2, varies roughly from 0.67 to 1.49 of nominal.

With 20% uncertainty in both, worst-case ell_ex ranges from 0.667 to 1.50 of nominal. The corresponding Philip exchange scale spans 0.667 to 1.50, while the Darcy scale spans about 0.444 to 2.25.

Thus wet Darcy exchange is much more sensitive to structural measurement uncertainty than dry Philip exchange.

## Consequence

The uncertainty is material but does not justify blind calibration. Preferred ownership is:

    measured/derived structure -> ell_ex -> propagated uncertainty

rather than:

    unknown structure -> freely fitted ell_ex

Recommended hierarchy:

1. image/CT-derived macropore radius and area fraction;
2. measured crack/ped spacing;
3. explicit structural-class pedotransfer relation;
4. bounded calibration only when structural information is unavailable.

Field studies also warn that image-derived aggregate spacing can overpredict exchange when interpreted too literally. Geometric ell_ex is therefore a strong prior/derived input with uncertainty and validation, not an exact continuum truth.

## Parameter consequence

After ALT29, the default RFM free core becomes:

    sigma_B
    f_MB
    p
    optional chi_wall

while ell_ex is measured/derived. If there is no evidence for wall repellency/contact inefficiency, chi_wall = 1 and the free core reduces to:

    sigma_B, f_MB, p

## Decision

ELL_EX_AS_DEFAULT_FREE_PARAMETER = REJECT
ELL_EX_FROM_STRUCTURAL_GEOMETRY = QUALIFIED RESEARCH ROUTE
UNCERTAINTY_PROPAGATION = REQUIRED
WET_DARCY_EXCHANGE = MOST SENSITIVE TO GEOMETRY ERROR

## Next

ALT30 should consolidate the final reduced parameter contract into two levels: RFM-minimal with sigma_B, f_MB and p, and RFM-wall-corrected with optional chi_wall. Then compare that contract directly with current SWAP input burden and define the minimum empirical qualification data for each parameter.
