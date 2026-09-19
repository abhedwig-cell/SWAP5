# F-ROM-LARE BC2 moving-water-table geometry authority

## Status

**RESEARCH AUTHORITY — MOVING-GEOMETRY SEMANTICS ONLY**

This document does not authorize production ROM integration, groundwater-coupler replacement, or application acceptance.

The predecessor fixed-domain boundary work is closed by:

- `integration/f-rom/LARE_BC1_STAGE_B_RESULT.json`;
- `integration/f-rom/LARE_BC1_RL1_RESULT.json` where available;
- `docs/science/F-ROM_LARE_BC1_BOUNDARY_AUTHORITY.md`.

BC1 established relative support for the no-fit `CURRENT_LAYER_FACE` closure under a fixed computational domain and arbitrary prescribed bottom head. BC2 addresses a different physical problem: a **moving water-table boundary changes the geometry of the unsaturated control volume itself**.

## Source authority

Primary literature:

1. He, Hantush, Kalin, Rezaeianzadeh & Isik (2021), *A two-layer numerical model of soil moisture dynamics: Model development*, Journal of Hydrology 602, 126797, DOI 10.1016/j.jhydrol.2021.126797.
2. He, Hantush, Kalin & Isik (2022), *Two-Layer numerical model of soil moisture dynamics: Model assessment and Bayesian uncertainty estimation*, Journal of Hydrology 613, 128327.
3. He (2021), *Modeling Soil Moisture Dynamics in Wetlands*, PhD dissertation, Auburn University.
4. He, Kalin, Hantush & Isik (2026), *A Numerical Model for Integrated Form of Richards Equation*, Hydrological Processes 40(1), e70396, DOI 10.1002/hyp.70396.

The 2026 paper states that LARE handles dynamic water-table conditions. Its Zenodo record 10.5281/zenodo.17613977 describes Fortran source code and scenario data, but the files are currently restricted. BC2 therefore does **not** claim executable inspection of the 2026 implementation.

## Coordinates and state

Use source convention:

- depth `z` positive downward;
- water flux `q` positive downward;
- fixed upper anchor `a`;
- prescribed water-table depth `H(t) > a`;
- moving unsaturated-layer thickness
  `L(t) = H(t) - a`.

The physically conserved state of the moving unsaturated layer is

`W_u(t) = integral_a^H(t) theta(z,t) dz = L(t) * theta_bar(t)`.

This storage state is preferred over `theta_bar` as the prognostic quantity because it exposes the moving-boundary mass term without algebraic ambiguity.

## Exact moving-control-volume balance

For one-dimensional continuity

`partial(theta)/partial(t) = -partial(q)/partial(z) - S`

and a moving lower boundary `H(t)`, Leibniz' rule gives

`dW_u/dt = q_a - q_H - S_u + theta_H * dH/dt`.

At a zero-pressure water table in a homogeneous material,

`theta_H = theta_s`.

Therefore

`dW_u/dt = q_a - q_H - S_u + theta_s * dH/dt`.

Equivalently,

`d[L * theta_bar]/dt - theta_s * dH/dt = q_a - q_H - S_u`.

For fixed `a`, expansion of the product gives

`L * d(theta_bar)/dt + (theta_bar - theta_s) * dH/dt = q_a - q_H - S_u`,

or

`L * d(theta_bar)/dt - (theta_s - theta_bar) * dH/dt = q_a - q_H - S_u`.

These forms are algebraically identical.

## Published-form discrepancy

He et al. (2021) define

`theta_bar_2 = [1/(H-h)] integral_h^H theta dz`

and subsequently print their Eq. 9 as

`(H-h) d(theta_bar_2)/dt - theta_2s dH/dt = q_h - q_H`

for the no-sink lower layer.

The 2022 assessment repeats the same displayed average-state equation.

Taken literally together with the preceding definition of `theta_bar_2`, that displayed equation is **not** the product-rule expansion of the moving-volume balance. The term
`+ theta_bar_2 dH/dt`
would also be present.

An earlier dissertation derivation in the same research lineage writes the moving-layer balance in the conservative product form

`d[(H-h) theta_bar_2]/dt - theta_s dH/dt = ...`,

which is consistent with Leibniz' rule.

BC2 classifies this as:

`SOURCE_ALGEBRA_DISCREPANCY_MOVING_AVERAGE_VS_CONSERVATIVE_STORAGE`.

This workstream does not infer author intent and does not silently rewrite the published equation.

## Frozen BC2 variants

Two variants are retained prospectively for scientific diagnosis:

### BC2-CONSERVATIVE

Prognostic state:

`W_u = L theta_bar`.

Evolution:

`dW_u/dt = q_a - q_H - S_u + theta_s dH/dt`.

Role:

- first-principles moving-control-volume balance;
- exact geometric water ledger;
- primary physical authority unless contradicted by a stronger executable/source authority.

### BC2-PUBLISHED-THETA

Prognostic state:

`theta_bar`.

Evolution exactly as printed in He et al. (2021) Eq. 9:

`L d(theta_bar)/dt - theta_s dH/dt = q_a - q_H - S_u`.

Role:

- publication-reproduction diagnostic only;
- not allowed to replace the conservative form because it fits SWAP better;
- retained so any consequence of the algebraic discrepancy is measurable rather than hidden.

No coefficient may be fitted in either route.

## Bottom water-table flux

The source two-layer formulation evaluates bottom flux at the moving water table using Darcy-Buckingham and a first-order layer-average gradient. For the water-table/bubbling-suction boundary it uses saturated conductivity at the boundary.

BC2 must distinguish two concepts:

1. **geometric water table**: zero pressure head crossing in SWAP convention;
2. **source bubbling/air-entry boundary**: the `psi_b` convention used in the two-layer source equations.

These are not silently equated.

For the first SWAP-oriented BC2 experiment, the boundary head convention must be frozen separately before dynamics. If a zero-pressure water table is selected, `psi_H = 0` is an explicit SWAP translation, not a claim that every source-paper `psi_b` definition is identical.

## SWAP comparator semantics

Current SWAP5 contains two distinct relevant mechanisms.

### Mode-5 fixed lower boundary

The groundwater-head forcing adapter maps a groundwater hydraulic head to pressure head at the **fixed SWAP bottom face**. Mode 5 therefore does not move the computational lower boundary.

BC1-A2 established the exact numerical semantics of that fixed face.

### Smooth freatic projection

`mod_b110_smooth_freatic_projection.f90` diagnoses a groundwater level from an **interior zero-pressure crossing** of a full pressure-head profile.

Current restrictions include:

- bottom mode 2 only;
- non-macropore;
- a strict smooth interior negative-to-positive pressure-head crossing;
- no fully saturated or zero-on-node branch.

This projection is diagnostic geometry, not a moving Richards computational boundary.

### Consequence

A source-paper moving-domain LARE state and a SWAP mode-5 fixed-domain prescribed-head solution are **not geometrically identical models**.

BC2 therefore forbids treating the mode-5 bottom pressure head as if it were the moving coordinate `H(t)`.

## Comparator hierarchy

BC2-A must establish a common geometry before BC2 dynamics.

Preferred order:

1. **Reference-profile projection experiment**
   - run/consume an accepted fixed-domain Richards profile with an interior water table;
   - diagnose `H(t)` from the zero-pressure crossing;
   - integrate full-order unsaturated storage only over `[a,H(t)]`;
   - evaluate the exact moving-volume ledger from full-order profile data.

2. **Reduced prescribed-geometry replay**
   - prescribe the diagnosed `H(t)` and `dH/dt` to BC2-CONSERVATIVE and BC2-PUBLISHED-THETA;
   - do not feed reduced fluxes back to groundwater;
   - compare moving unsaturated storage and flux response under identical geometry.

3. Only after that evidence may a two-way groundwater coupling experiment be proposed.

A dynamic-active-node or moving-mesh Richards comparator is not introduced unless separately authorized.

## First-domain restriction

BC2-B, if authorized, starts with one fixed upper anchor `a` and a water table that remains strictly inside one material and does not cross `a`.

Thus:

- no layer birth/death;
- no remapping across multiple fixed reduced layers;
- no material-boundary crossing by H;
- no root-zone boundary crossing;
- no macropore, frost, solute, heat or crop feedback.

This isolates the moving-volume term itself.

Crossing a reduced-layer or material boundary is deferred to BC2-C.

## Hard invariants

For BC2-CONSERVATIVE:

1. `W_u = L theta_bar` at every accepted state.
2. `theta_r < theta_bar <= theta_s` inside the declared unsaturated domain.
3. Water ledger uses the explicit geometry term `theta_s dH/dt`.
4. No clipping or mass-correction flux.
5. As `dH/dt -> 0`, BC2 reduces continuously to the corresponding fixed-geometry balance.
6. If `q_a = q_H`, `S_u=0`, and `dH/dt=0`, storage is stationary.
7. State and geometry are restartable: `(W_u,H)` is sufficient to reconstruct `theta_bar=W_u/(H-a)` in this bounded experiment.

## Scientific questions

BC2-A/B ask:

1. Does the moving-volume geometric term materially affect groundwater-driven storage response at the time scales relevant to SWAP-ROM?
2. Does the published average-state equation differ detectably from the conservative moving-storage equation under identical H(t)?
3. Can D4-like closure resolution preserve the relevant moving-water-table response without importing hidden full-profile state?
4. Does a fixed-domain prescribed-head approximation remain adequate for GW-R even when it is not geometrically equivalent for GW-D?

The last question is explicitly purpose dependent.

## Firewalls

- NO_PRODUCTION_ROM
- NO_MOVING_WATER_TABLE_COUPLER_INTEGRATION
- NO_COEFFICIENT_FIT
- NO_POST_RESPONSE_CHOICE_BETWEEN_CONSERVATIVE_AND_PUBLISHED_FORM
- NO_SILENT_EQUIVALENCE_OF_MODE5_HEAD_AND_MOVING_H
- NO_SILENT_EQUIVALENCE_OF_PSI_B_AND_ZERO_PRESSURE_HEAD
- NO_LAYER_BIRTH_DEATH_IN_BC2_B
- NO_MATERIAL_BOUNDARY_CROSSING_IN_BC2_B
- NO_APPLICATION_ACCEPTANCE
- NO_SPEED_CLAIM

## Current disposition

BC2-A is a geometry and conservation authority task.

BC2-B dynamics are authorized only after a full-order profile route can expose a smooth interior water-table trajectory and the corresponding moving unsaturated storage with a closed observational ledger.

If current SWAP authority cannot expose such a trajectory without changing production physics, the valid result is

`BC2_REFERENCE_GEOMETRY_NOT_YET_AUTHORITATIVE`

rather than substituting mode-5 bottom head for H.
