# TOP03 temporal route reassessment result

Date: 2026-10-01
Status: QUALIFIED_BOUNDED_RESEARCH__NO_PRODUCTION_ADMISSION
Source/test postimage: 7e53b14619183156efd5ebceeb6201a82ccdf03b
Canonical inspected: 19f09b818b1bb30c1428919074c00098dbd062bd

## Question and method

Does replacing the identity-only temporal gate with a finite full/half measure solve the actual inundation integration problem? Isolated fixed-grid research calls the same real Reference Richards and imposed-head provider; candidates advance only within the research integration. No production acceptance or receipt commit is changed. The synthetic FSI fixture is four nodes spanning only 3 cm. It is a mechanism probe, not a field column or live Ribasim model. All conclusions are bounded to its constitutive/boundary contract.

Both O0 and O2 completed the research runner. The analyzer compared all 80 result records and 34 retry diagnostics per build exactly, excluding CPU time. Hard soil mass and surface closure checks were retained. Maximum reported whole/partial-interval ledger residual was 1.33e-13 cm. Partial integrations are explicitly labelled and are not accuracy references.

## Observations

On the 0.001953125-day interval (168.75 seconds), all four cases complete at every subdivision from 1 through 512. Successive transfer differences decrease, with the final difference ratios near 1.99. Water-profile and pressure differences also decrease over the last four refinements. This is evidence of approximately first-order behavior in these short cases; it is not a general accuracy bound or proof that the finest grid is exact.

| Initial head (cm) | Initial pond (cm) | One-step signed transfer (cm) | 512-step signed transfer (cm) | Difference relative to finest |
| --- | --- | --- | --- | --- |
| -123 | 0 | -0.0853733 | -0.1403762 | 39.18% |
| -123 | 0.02 | -0.0653733 | -0.1203762 | 45.69% |
| -10 | 0 | -0.0358202 | -0.0409517 | 12.53% |
| -10 | 0.02 | -0.0158202 | -0.0209517 | 24.49% |

Initial ponding changes receipt by the expected 0.02 cm storage contribution. It does not change the soil solution in this maintained-head experiment. Thus pre-filling the pond alone cannot eliminate the nonlinear soil wetting transition. The continued-boundary cases are not pre-equilibrated wet profiles.

For 0.25 day (six hours), one large step completes in every case, while refined integrations stop after successful early steps. Dry cases first stop on the fourth solve of the four-step grid; wet cases stop on the second solve of the two-step grid. Even 512 subdivisions stop: dry cases after 36 completed steps, wet cases after 8. Every stop is SW_SOLVE_RETRY_ADVISED, legacy-reference-retry, at 80 nonlinear iterations. No positive-qtop rejection occurs.

The last valid states near the stops have a saturated upper node and almost saturated lower nodes. Terminal solver snapshots show sizeable pressure updates, e.g. 0.411 cm in the dry 512-grid failure, together with variable residuals. A small balance residual in some failed iterates is not proof of nonlinear convergence. The saturated constitutive capacity floor is timestep dependent in the existing provider. These observations locate a regime for further diagnosis; they do not yet establish whether the cause is Jacobian treatment, switching, bottom boundary, initialization, or another mechanism. The four-node/bottom-mode-7 fixture is too narrow to assert a general Richards defect.

## Decision

Do not implement a production full/half norm merely to make the original fixture pass. Keep full/half refinement as a research oracle. First obtain a complete, representative inundation reference and attribute the near-saturation nonlinear failure. Short-onset accuracy needs explicit attention: mass closure alone permits substantial temporal transfer differences. Event boundaries and smaller initial steps may be useful, but are not selected or qualified by this experiment.

The next investigation should separate initial boundary incompatibility, soil wetting, saturated transition and bottom-boundary effects on a deeper representative column, then compare event-aligned initial refinement with maintained wet operation. Preserve the exact physical problem when comparing grids. Only after complete refinement behavior is established should a caller-owned accuracy budget and a production criterion be selected, with performance measured alongside transfer/profile error.

Existing transaction/materializer architecture remains valid within its earlier qualified scope. The top-active receipt/commit end-to-end gate still needs a numerically accepted candidate. TOP03 remains draft and unadmitted; no Actions were started.

## Reproduction

    PATH=/tmp/top03-bin:$PATH bash tests/fapp/run_sw_rib_top03_temporal_refinement.sh > refinement.log 2>&1
    python tests/fapp/analyze_sw_rib_top03_temporal_refinement.py refinement.log evidence

Any GNU Fortran 13.3.0 installation can replace the local wrapper PATH. Persisted raw O0/O2 CSV, terminal stop diagnostics and machine-readable differences are under integration/sw-rib-top03/. CPU times are descriptive local measurements only.
