# DATAQUAL15: original Hupsel micro demand cap and wetting continuation

Scientific source: `1b75b5502f613edb60bcbd405e99a7422dfc066c`, based on `fac0d3d8cb98d0d874e5ebc1f3c1fa5c28441d21`.
Experimental. No canonical admission or full original-project/scientific-equivalence claim.

## Demonstrated causes and repairs

At original day 537.87014773115573, both unconstrained and coupled microscopic root uptake published 0.18549769260151808 cm/day against potential demand 0.18549769260151805. Every retry rejected before Richards: the existing producer's proportional demand cap rounded its positive nodal sum one ulp above demand. The strict stress-attribution contract correctly rejected it; reducing dt cannot repair it.

Commits `6976a75` and `0bdd3e9` enforce the existing producer cap on the actual nodal vector. Only a remainder within the positive floating-point gamma(n+2) accumulation/division/multiplication bound is corrected on the largest donor. The published total is recomputed from that same vector. Larger post-cap excess still rejects; downstream strict attribution and exact water/chemical sink accounting are unchanged.

At day 548, after canopy filling, microscopic roots, oxygen, salinity, Richards, numeric heat, trace publication and reactive chemistry all succeeded. Hydraulic full/half error was 2.22e-9 while Black LDWET differed by dt versus dt/2, forcing dt about 6.243e-7 days repeatedly. The existing outer free-throughfall certificate did not recognize the newly filled canopy.

Commit `1b75b55` adds a private numerical certificate: the incumbent Rutter full-canopy predicate holds in BOTH actual full/half candidates, covered inflow is at least EIC, and gross inflow minus EIC exceeds the original RSIGNI. This regime remains full under the unchanged forcing and resets Black before its dry memory is used again. The existing forcing-end LDWET bound, hydraulic/storage/Darcy/canopy errors, solver settings, mass tests and tolerances remain unchanged. The promise is conservatively bounded by the backend outer interval: Rutter binds its own parameters over a source window, but Black RSIGNI is not in that typed immutable record. No unproved extension of RSIGNI constancy is assumed.

## Completed checks

- GNU gfortran 13.3, checked builds with invalid/zero/overflow traps.
- Existing standalone microscopic owner O0/O2 identity: PASS.
- Existing corrected literal B1.11 microscopic source oracle O0/O2 identity: PASS, including exact stress partition, saved zero-demand factor and invalid-optimum controls.
- Fresh original day537 checkpoint to day539: O0 microscopic owner versus O2 owner, other providers exact inherited O2; budget.csv, crop.csv and checkpoint.bin byte-identical.
- Fresh original day548 checkpoint to day550: O0 backend versus O2 backend, other providers exact inherited O2; the same three outputs byte-identical. This is component optimization preservation, not an all-provider O0 build.
- Actual O2 continuation day548 to day566: 18 complete days, 73,976 accepted substeps, 56.8466 native seconds. Maximum water residual 1.75415e-14 cm; reactive chemical residual 6.69991e-12 mg/cm2; observed heat residual 1.29601e-12 J/cm2.
- Existing MICRO03 runtime regression runner failed before execution because its baseline source closure omits `mod_drainage_dramet3_response`. This gate is not claimed as passed and was not expanded here.

The original incoming day537 checkpoint is used literally, without rebinding. Day548 is an exact endpoint produced by the corrected microscopic owner. Historical input files are unchanged. Full physical equivalence remains unqualified: the next diagnosis exposed missing original surface-parameter binding, described below, which requires a fresh original run after correction.

## Next reproducible blocker

The day566 checkpoint reproduces `HeadCalc: dynamic top-boundary provider unavailable`. An ABI-identical diagnostic adapter reports `active-runoff-outside-profile`, status3. The original swap.swp specifies PONDMX=0.2 cm, RSRO=0.5 day, RSROEXP=1.0. The potato application never assigns these values to the Rutter forcing's surface fields; the Rutter provider therefore sees default pond threshold/resistance zero even though the Black forcing has the original values. Bind the existing original surface controls into the Rutter forcing; this is an application composition omission, not missing runoff physics or a reason to change tolerances.

The parent application owner is implementing that disjoint binding and the full-source qualification. No application source was edited here.

## Recovery

Branch `work/dataqual15-micro-demand-cap`, isolated worktree `SWAP5-hupsel-backend-diagnosis`. Cherry-pick `6976a75`, `0bdd3e9`, `1b75b55` onto the corresponding parent application baseline. Neither public physical state layout nor disk schema changed. Diagnostics are archive-only; production sources contain only the bounded producer correction and private numerical certificate.

Publication packaging preserves every source, compile/run record and physical output. Reproducible old default/diagnostic executable build artifacts are represented by their exact original hashes in `BUILD_ARTIFACT_OMISSIONS.json`; the current closed-union and clean-build capsules retain the original-history replay executables and TTUTIL. This changes archive packaging only, not the executed qualification or scientific claims.
