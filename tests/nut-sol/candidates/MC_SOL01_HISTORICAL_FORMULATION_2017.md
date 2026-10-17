# MC-SOL01 documented historical pond-concentration equation

Date: 2026-10-17. This is documentary scientific evidence, not proof of unchanged SWAP 4.3.1 implementation.

**Primary reference:** Kroes et al. (2017), *SWAP version 4: Theory description and user manual*, Wageningen Environmental Research, Report 2780, section 8.3, equation 8.17 and 8.18. Public full text: https://www.swap.alterra.nl/Documents/Kroes_etal_2017_SWAP_version_4_ESG_Report_2780.pdf

The documented surface-pond concentration is determined from preceding pond storage and incoming rain/irrigation solute mass, divided by the **end pond depth minus infiltrating top and crack-water exchanges integrated over the timestep**. The documented top solute flux then multiplies this concentration by the actual infiltration flux and non-crack area. The text explicitly states that evaporation does not remove solutes from the soil profile.

This denominator structure is consistent with admitted current SWAP5 `src/process/mod_b111_pond_solute_exchange.f90` where `denom=pond_end-qtop*dt` for infiltration with zero macropore lateral flow. The standalone PR1288 `mod_b111_surface_loss_budget.f90` instead divides by pre-loss water depth, which is **not** generally equivalent during evaporation (the observed 1.0 vs 0.5 mg/cm2 transfer discriminator). Therefore **do not promote or transplant the experimental mixing law**. Preserve incumbent zero-macro original formula and require source-exact SWAP 4.3.1 comparison before authorizing a changed physical law.

This manual does not establish the **actual SWAP 4.3.1 code behavior**, exact runoff solute routing, dry deposition, runon chemistry or event ordering. Those still require inspection of the 4.3.1 authority archive or source and real accepted substep hydraulic receipts. The final-converged HeadCalc gross receipt handoff is still missing in production. Historical equations are necessary but not sufficient for full admission.

Decision: PR1288 draft research only; avoid a known non-source-faithful production modification. Zero additional mastercoverage promotions; production and canonical remain untouched.
