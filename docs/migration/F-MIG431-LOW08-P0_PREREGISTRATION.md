# F-MIG431-LOW08-P0 — typed lysimeter-plate active-set solver route

Status: CENTRALLY_PREREGISTERED_OFFICIAL_BRANCH_ISSUED

Baseline: `220810c42f330e1d2615332683a54c19381ef62d`

## Purpose

Migrate only the source-bound SWBOTB=8 lysimeter-plate solver semantics from corrected SWAP 4.3.1 B1.11 into the typed Reference Richards route.

## Frozen source law

At solve entry, legacy HeadCalc calls `vector_F(1)` once. For SWBOTB=8 it selects
`active = h(N) > Critdz - d_bottom + hplate`, with `Critdz = 1e-5 cm`.

If active, the bottom face is a prescribed pressure-head face with `hbot=hplate` and gradient
`(h(N)-hplate)/d_bottom + 1`. If inactive, `qbot=0`.

Subsequent Newton/backtracking residual evaluations use `vector_F(2)` and reuse the original `flboth`; the active set is not reselected from Newton candidates. The Jacobian includes `K_bottom/d_bottom` only for the active branch. LOW08-P0 initially admits only `SWKIMPL=0`.

## Typed representation

No new public boundary field is authorized. For mode 8, `bottom_head` carries hplate; the base-state bottom pressure head and existing geometry select the branch once at solve entry. Input bottom_flux must be zero and mode-3 resistance fields neutral. The selected branch is solve-local immutable scratch, never committed/restart state.

## Bounded scope

Reference SWKIMPL=0, bare homogeneous non-macropore profile, no sensitivity, groundwater ownership or RossFast. No application/bootstrap admission is part of P0.

## Qualification

Inactive/active branches, strict equality threshold, solve-entry immutability through Newton/backtracking, physical mass closure, fail-closed unsupported matrix, and preservation of admitted lower-boundary modes. No application claim.
