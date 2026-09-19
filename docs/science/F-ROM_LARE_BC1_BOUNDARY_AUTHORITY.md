# F-ROM-LARE BC1 prescribed-head lower-boundary authority

## Status

**SOURCE BOUNDARY STRUCTURE AVAILABLE; GENERAL UNSATURATED FIXED-HEAD CONDUCTIVITY REQUIRES EXPLICIT QUALIFICATION**

This authority applies only to a **fixed lower boundary** with prescribed pressure head.

It does not authorize moving-water-table geometry, a saturated layer inside a reduced layer, production groundwater coupling, or application acceptance.

## Published LARE / two-layer source

He et al. (2021), DOI `10.1016/j.jhydrol.2021.126797`, use depth positive downward and flux positive downward.

Their bottom Darcy relation is

`q_b = K_b (d psi/dz |_b + 1)`  (Eq. 28)

and their first-order boundary-gradient reconstruction is

`d psi/dz |_b = 2 (psi_b - psi_bar_N) / L_N`  (Eq. 30)

for the lower layer of thickness `L_N`.

The explicitly derived pressure-controlled groundwater case then imposes a water-table / bubbling-suction boundary and therefore sets

`K_b = K_s`  (Eq. 29),

yielding their Eq. 31.

For free drainage they separately derive

`q_b = K_bar_N ~= K(theta_bar_N)`  (Eq. 32).

The paper reports flux- and pressure-controlled boundary conditions generally, but the explicit bottom formula that is directly source-visible is the saturated/water-table case. It does not directly validate an arbitrary unsaturated fixed pressure head with `K_b < K_s`.

The 2026 generalized LARE paper confirms treatment of dynamic water-table conditions but does not, in the source material inspected for this work unit, provide a separately verified formula for an arbitrary fixed unsaturated bottom pressure head.

## SWAP mode-5 comparator authority

Current SWAP5 canonical mode 5 prescribes pressure head at the lower boundary face.

The groundwater adapter maps groundwater hydraulic head to SWAP bottom pressure head through an explicit common datum.

The legacy/reference Richards residual uses

`gradient_b = (h_N - h_b) / d_face + 1`

with `d_face = 0.5 * dz_N` for the frozen uniform 10-cm fine grid.

For mode 5, current Reference sets the lower-face conductivity to the conductivity of the last soil node:

`K_face = K_N`.

Thus the Reference bottom outward Darcy flux is structurally equivalent to

`q_out = K_N [1 + 2 (h_N - h_b) / dz_N]`

up to the repository's native/public flux-sign conversion.

Using the He et al. capillary-head convention `psi = -h` in the unsaturated branch gives

`1 + 2(psi_b - psi_N)/dz_N = 1 + 2(h_N - h_b)/dz_N`.

Therefore the published Taylor gradient and SWAP mode-5 gradient are algebraically compatible.

## Executable Reference time-level and output semantics

The original structural statement `K_face = K_N` requires an explicit time-level qualifier for the current Stage-A authority.

The qualified B01 Stage-A Reference route uses `SWKIMPL=0`. In `headcalc` this means:

- nodal conductivity and `kmean` are initialized from the **start-of-step/base state** before Newton iteration;
- the pressure-head state and bottom head gradient are updated during nonlinear iteration;
- conductivity is not recomputed from the iterated candidate head when `SWKIMPL=0`.

Thus the accepted mode-5 residual uses

`K_face^n * [1 + (h_N^{n+1} - h_b)/(0.5*dz_N)]`

for the lower face.

After the solve, `mod_reference_richards_legacy_binding` does not publish this raw face product as mode-5 `qbot`. It materializes `qbot` with the exact legacy water-balance grouping from top flux, storage change and source/sink terms. The kernel's terminal bottom-outward flux is the sign-adapted value of that materialized `qbot`.

This was established executably by BC1-A2:

- 2108 auditable mode-5 intervals;
- lagged Reference face replay maximum absolute error `4.62e-11 cm/day`;
- projected lagged reduced-last-layer replay maximum absolute error `4.62e-11 cm/day`;
- zero sign mismatches.

Therefore:

1. same-state current-layer face flux is a physical LARE closure quantity;
2. lagged-`K` face flux is a Reference numerical-semantics diagnostic/control, not silently imported as LARE physics;
3. balance-materialized interval bottom exchange is the primary hydrological Reference observable for BC1-B.

## BC1 candidate closures

No fitted coefficient is introduced.

### BC1-SWAPFACE

`q_b = K(theta_bar_N) [1 + 2(psi_b - psi_bar_N)/L_N]`.

Role:

- comparator-aligned fixed-head closure;
- directly mirrors the current SWAP mode-5 face-conductivity convention;
- uses only the reduced last-layer state plus the prescribed external boundary head.

For D3 and D4 the last layer is exactly `150-160 cm`, identical to the last 10-cm fine Reference cell. On one common projected state, BC1-SWAPFACE reproduces the corresponding current-state face operator to numerical noise. It is not expected to equal the Stage-A balance-materialized terminal qbot because the qualified Reference route uses lagged start-of-step conductivity under SWKIMPL=0.

### BC1-SOURCEFACE

`q_b = K(psi_b) [1 + 2(psi_b - psi_bar_N)/L_N]`.

Role:

- physically direct Dirichlet extension of Eq. 28 plus Eq. 30 when the prescribed boundary itself is unsaturated;
- reduces to the published saturated-boundary conductivity when the boundary is saturated;
- is **not** claimed as a formula explicitly validated by He et al. for arbitrary unsaturated bottom head.

It is retained as a scientific sensitivity/control, not selected from response.

## Scientific separation

BC1 has two questions.

1. **Boundary-operator identity:** can the reduced bottom state plus prescribed head reproduce the current Reference mode-5 face flux?
2. **Reduced dynamics:** after that operator is bound, can standard LARE propagate D3/D4 storage and groundwater exchange under head rise/fall and flux reversals?

Question 1 must close before question 2.

BC1-A0 initially failed because it compared different time-level/output observables. That result is retained as blocked evidence, not interpreted as boundary-physics failure.

BC1-A2 and the repaired same-state audit now qualify the geometry/sign/constitutive binding. This authorizes BC1-B fixed-domain head-driven reduced dynamics. It does not imply LARE dynamics fidelity, because internal interface fluxes remain approximate.

## Flux conventions

For source equations, positive `q` is downward.

For the public SWAP-groundwater contract, `q_swap > 0` means water leaves SWAP through the bottom.

These are equivalent directions at the bottom of a vertical column.

Native SWAP `qbot` has the opposite sign and is not used without explicit conversion in BC1 evidence.

## Firewalls

- no moving-boundary water table in BC1;
- no saturated-fraction state;
- no empirical boundary coefficient;
- no fitting to mode-5 response;
- no change to Reference Richards;
- no production solver integration;
- no application acceptance;
- BC1-SOURCEFACE cannot be relabelled as published-LARE authority merely because it performs well.

## Primary source

He, J., Hantush, M. M., Kalin, L., Rezaeianzadeh, M. & Isik, S. (2021).
*A two-layer numerical model of soil moisture dynamics: Model development*.
Journal of Hydrology 602, 126797.
DOI 10.1016/j.jhydrol.2021.126797.