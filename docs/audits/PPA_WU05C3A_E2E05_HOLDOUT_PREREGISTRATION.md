# PPA-WU05-C3A E2E05 holdout preregistration

Date: 2026-10-03
Branch: research/ppa-wu05c3a-e2e05-bofek-eligibility

## Screening-derived hypothesis before holdout

The corrected screening uses the existing 16 BOFEK01 screening trajectories, leaves the hydraulic solver and timestep policy unchanged, derives the waterfilm capacity term according to the admitted Bartholomeus MVG construction, and scales both independent root-demand carriers (current w_root and z0 w_root_z0).

Persisted screening authority: run 37125694920.

Across 142 accepted states per demand scale:
- 0.001x: 80 PERF02 hits (56.34%)
- 0.01x: 80 hits (56.34%)
- 0.1x: 46 hits (32.39%)
- 1.0x: 0 hits

Observed relation:
- eligibility decreases as root demand increases;
- within a material, wetter regimes lose eligibility before dry/transition regimes;
- O05 remains ineligible at all scales because its MVG n=2.887502 is outside the admitted PERF02 n<=2 analytical bound;
- the relationship is not a production-frequency estimate.

The PERF02 boundary qualification sampled independent current and z0 root carriers from about 0.002 to 2.002. Therefore 0.01 and 0.1 are inside the already falsified carrier range. The typed production application fixture uses root density [1.0,0.8,0.6], so scale 1.0 is an existing stress-oriented fixture point. This does not establish how frequently lower root demand occurs in production.

## Independent holdout expectation

Holdouts remain B12/POND, O14/MOIST, O14/WET, O14/POND.

Before executing them:
- 1.0x is expected to remain ineligible in all four holdouts;
- 0.1x is expected to have little or no eligibility because all holdouts are at least as wet as the screening states where 0.1x eligibility was already strongly reduced;
- 0.001x and 0.01x may retain eligibility, especially O14/MOIST, but eligibility should decrease toward WET/POND;
- no exact holdout hit fraction is preregistered.

Falsification criterion: a broad reversal in which wetter holdouts become more eligible than the corresponding drier screening trajectory at equal material/demand, or substantial 1.0x eligibility, falsifies the screening-derived relation.

The holdouts must not be used to tune parameters or thresholds.
