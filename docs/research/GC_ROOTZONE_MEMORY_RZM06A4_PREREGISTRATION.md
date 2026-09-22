# GC-RZM06A4 stronger top-forcing H2 preregistration

Date: 2026-09-22  
Machine-readable authority: `67e6cf09aa870c77cbb5059a834c2c6e14632a93`  
Production changes: none

## Rationale

RZM06A3 showed that small fixed-head perturbations can be locally admissible while sign reversal from an evolved committed state is not. More importantly, the largest pre-reversal separation in the distribution moment was only about `2.27e-7`, roughly 441 times below the unchanged H2 requirement `1e-4`.

RZM06A4 therefore targets a physically stronger source of vertical redistribution: atmospheric/top-boundary flux, while keeping the groundwater interface head fixed at

`H* = -0.7149999706136307 m`.

## Top-flux sign

The fixed-flux provider copies the requested `top_flux` directly into the legacy `qtop` coordinate. In the legacy rainfall route, a positive rainfall supply enters the soil as `q1 = -q0`. Accordingly:

- negative `top_flux`: into the SWAP profile, infiltration direction;
- positive `top_flux`: outward through the top boundary.

RZM06A4 uses these explicit directions rather than the historical WET/DRY labels.

## Stage 1: symmetric forcing admissibility

Fresh-baseline read-only trials are run at H* for both signs of each frozen amplitude:

`0.1, 0.05, 0.02, 0.01, 0.005, 0.002, 0.001 cm d^-1`.

Frozen durations are:

`0.01, 0.005, 0.002 d`.

The selector receives only transaction, retry, temporal and mass evidence. It cannot see endpoint water observables or E_c.

The selected point is the two-sided accepted point maximizing `|q_top| × duration`. Ties use larger amplitude, then longer duration.

## Stage 2: equal-integral opposite-order histories

Using only the selected symmetric forcing, construct:

- NEG repeated N, POS repeated N, ZERO repeated R;
- POS repeated N, NEG repeated N, ZERO repeated R.

The frozen orders are:

- `N = 10, 5, 2, 1`;
- `R = 0, 1, 5, 20`.

Both members of every pair use the same H*, the same endpoint time and zero net prescribed top forcing. Failed trajectories remain evidence.

Only after both trajectories are accepted are the endpoint observables compared. The unchanged H2 criteria are:

- `|ΔW_profile| <= 1e-6`;
- `|ΔM1| >= 1e-4`.

The first pair satisfying both criteria is selected. E_c is still hidden at this stage.

## H2 probe

Only a selected pair is replayed from fresh initialization and subjected to the same forcing-free read-only probe:

- H_c = H*;
- top flux = 0;
- duration = `1e-4 d`.

H2 is supported only when the origins and probes replay exactly, remain mass-complete and read-only, and

`|ΔE_c| > 1e-18`

in native whole-window bottom outward exchange.

No retry budget, temporal budget, solver tolerance, mass gate, H2 threshold or production coupling is changed.
