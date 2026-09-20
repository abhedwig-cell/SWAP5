# F-ROM-LARE BC2-C5B closeout

C5B diagnoses the single component that blocked the matched B14 dynamic-head C5A frontier. It does not change the C5A result or acceptance vector.

The authoritative run is 35499374653 at execution head e5cba46834e4e7178aaac30d9795fa479aa6681f. The exact C5B result SHA-256 is f6710fcf081320ea4aa654a8bf0c3f02a42b251d2cdc8cadfd7096a66bce6668.

The timestep explanation is effectively eliminated. Refining iterative Heun from dt=1e-4 to 5e-5 to 2.5e-5 changes the R16 current-face bottom-flux trajectory by only about 4.68e-6 of its remaining Reference RMSE. The pooled signed error converges with estimated order 2.00 to about -4.23448e-6 cm/d.

The ordinary lower-zone state-count explanation is also eliminated within the tested representation family. At dt=2.5e-5, R8 and R16 produce exactly the same bottom-flux series. R5 differs from R16 by only about 5.86e-6 of the current-face Reference residual. Adding layers upward therefore does not remove the C5A blocker.

The error is localized to prescribed-head operation. In every history, HOLD-phase bottom-flux error for current-face R16 is essentially machine zero. The residual appears only in PHASE1 and PHASE2, when the prescribed lower-boundary head is active.

Boundary formulation matters strongly, but the pre-existing BOUNDARY_FACE alternative is not the solution. At R16 and dt=2.5e-5 its flux-series difference from CURRENT_LAYER_FACE is more than 337 times the current-face Reference residual, and its pooled RMSE grows from about 2.97e-5 to about 1.00e-2 cm/d. CURRENT_LAYER_FACE therefore remains the supported BC1 closure of the two existing alternatives.

One spatial mechanism remains unresolved. R5, R8 and R16 all retain the same 10-cm bottom-adjacent layer. C5B can therefore reject insufficient refinement farther up the column, but it cannot distinguish a current-face closure-algebra floor from a boundary-adjacent spatial-discretization floor.

The next experiment is C5C: nested refinement of only the bottom 10 cm, with the exact C5A histories, B14 material, CURRENT_LAYER_FACE closure and fine diagnostic timestep held fixed.
