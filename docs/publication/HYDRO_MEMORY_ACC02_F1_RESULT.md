# HYDRO-MEMORY ACC02-F1 result

**Decision:** `ACC02_F1_PASS_LIVE_ROOT_ACTIVE_SINGLE_WINDOW`

The first live root-active SWAP-MODFLOW6 coupling window passes under the prospectively governed HYDRO-MEMORY accuracy contract.

Qualification authority:

- head: `ea5ecd1cae5435b017373f034eb91a3a0455e0ca`
- workflow: **35439142243**
- job: **105886820595**
- MODFLOW6: **6.8.0**, pinned asset and SHA-256 verified

The frozen numerical policy remained:

- application head-error requirement: 0.4 cm;
- temporal budget: 0.1 cm;
- interface head-residual tolerance: 0.001 m;
- root extraction: 0.02 cm d-1;
- maximum fixed-point iterations: 6;
- flux iteration criterion: 1e-15 m s-1;
- hard SWAP mass tolerance: 1e-12 cm.

## Observed live coupled result

The coupled fixed point converged in **2 iterations**.

Iteration 1 already satisfied the governed head tolerance with a head residual of approximately -9.85e-10 m, while its flux residual was about -3.88e-15 and therefore still outside the frozen 1e-15 flux criterion.

Iteration 2 produced:

- SWAP coupling head: -0.71500506773736627 m;
- live MODFLOW groundwater head: -0.71500506773736783 m;
- canonical head residual: 1.55e-15 m;
- package-flux residual: 6.11e-21;
- accepted predictor substeps: 1;
- predictor retries: 0;
- maximum temporal indicator: 0.00895386;
- interface ledger exchange: -1.16797e-12 m.

The prescribed-root accepted-trajectory tangent remained authoritative. Hard SWAP mass, publication order, live MODFLOW lifecycle, exact-once SWAP/ledger commit and O0/O2 behavior all passed.

## Intermediate-iterate interpretation

An initial implementation additionally required every intermediate MODFLOW prepared-solve iterate to report `modflow_converged=true`. That requirement was not part of the preregistered scientific convergence rule. The governed object is the **coupled fixed point**, which had to converge within six iterations under unchanged MODFLOW IMS, head, flux, temporal and mass criteria.

The final green gate therefore permits intermediate prepared-solve iterations when the prepared-solve API itself succeeds and the iterate is finite, while preserving all frozen coupled-convergence criteria. No tolerance, root sink, iteration ceiling, solver setting or production physics was changed.

## Consequence

Single-window root-active two-way feasibility is closed.

This still does not authorize the 90-day Stage 0 drought-recovery experiment. The next gate is **ACC02-F2**, which must demonstrate preservation over multiple consecutive accepted live coupling windows under the same governed accuracy contract.
