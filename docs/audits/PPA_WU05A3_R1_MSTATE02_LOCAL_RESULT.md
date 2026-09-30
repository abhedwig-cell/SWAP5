# PPA-WU05-A3 R1-MSTATE02 local result

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / CONSERVATIVE_QTOP_RECONSTRUCTION_SUPPORTED / NOT_YET_R1_FROZEN`

## Purpose

Compare two standard-route compartment-flux reconstructions:

1. historical B1.11 `MACROSTATE` reconstruction with corrected/refined interface index;
2. a universal local-conservation reconstruction applied top-to-bottom after accepted storage is known.

No physical storage equation, exchange law, rapid-drain law or parameter is changed in this experiment.

## Universal reconstruction

For each compartment:

`Q_bottom = Q_top - Q_exchange - DeltaW/dt`.

This is the same conservation identity used explicitly in the kinematic-wave source path.

## Stationary-interface case

When the macropore water interface remains in the same compartment:

- historical standard-route reconstruction and universal reconstruction agree to machine precision;
- every local compartment mass residual is near zero.

Thus the universal reconstruction preserves historical output semantics in this regime.

## Moving-interface case

When the interface rises by one compartment:

Historical reconstructed top fluxes:

- 0.600;
- 0.590;
- 0.070;
- 0.040;
- 0.000 cm d-1.

Universal conservative reconstruction:

- 0.600;
- 0.590;
- 0.470;
- 0.040;
- approximately 0.000 cm d-1.

Historical local residuals:

- ~0;
- +0.400;
- -0.400;
- 0 cm d-1.

Universal local residuals:

- machine zero in every compartment.

Whole-domain mass remains identical in both routes.

## Interpretation

The historical standard-route split reconstruction is locally inconsistent only when a compartment changes saturation class across the accepted step.

A universal post-acceptance top-down reconstruction:

- exactly preserves the full-domain mass balance;
- exactly enforces local compartment mass balance;
- agrees with historical reconstruction when the interface is stationary;
- avoids dependence on `icgwl` for diagnostic vertical-flux reconstruction.

This suggests the cleanest R1 handling may be:

- retain the corrected/refined interface rule where the physical rate/state code requires an interface index;
- do **not** use that interface to split post-acceptance `QTop` reconstruction;
- reconstruct accepted `QTop` from one universal local conservation identity.

## PEARL/ANIMO scope refinement

Exact-source review shows compartment-resolved `IQTopMpDm1CpNew` is written/exported only when `swmbf == 2`, the kinematic-wave route.

That route already computes compartment fluxes directly in `MACRORATE` and performs explicit local mass-balance checks.

Therefore the standard-route local reconstruction issue is currently classified as:

`STANDARD_ROUTE DIAGNOSTIC/OUTPUT CONSISTENCY`

rather than a demonstrated PEARL/ANIMO transport-coupling defect.

CSV diagnostics may still expose the standard-route reconstructed fluxes and should be checked later.

## R1 candidate policy

Candidate policy for research implementation:

1. physical/rate state remains source-bound;
2. accepted compartment storage is authoritative;
3. accepted vertical diagnostic flux is reconstructed top-to-bottom from local conservation;
4. rapid drainage is included exactly once as an external compartment sink where active;
5. whole-domain and local residuals must both close.

## Next step

Proceed to E9 extreme-rainfall stress and then freeze an A3 interim R1 process map before any coupled Richards implementation.
