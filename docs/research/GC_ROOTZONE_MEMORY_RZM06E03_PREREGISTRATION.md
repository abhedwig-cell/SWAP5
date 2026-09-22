# GC-RZM06E03 preregistration

**Status:** preregistered diagnostic research experiment  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `e6543e57bed84ec22615ea68f14f66ec400362cd`

## Question

Can the qualified 16-node real-HeadCalc carrier produce two strict accepted origins that have, simultaneously:

- effectively identical total profile water,
- effectively identical upper-30-cm water,
- and a materially different deeper vertical distribution,

without using any interface-response information to construct or select the pair?

This is the next state-sufficiency rung after E02. E02 already showed that equal total water is insufficient, but the selected E02 origins also differed in upper-30-cm storage. E03 controls that additional quantity before any new fixed-`H_c` response probe.

## Frozen construction

The carrier remains the C01 16 x 10 cm homogeneous B01 Reference HeadCalc carrier. Each family starts from the same fresh `Se=0.85` state and uses the dyadic interval

`dt = 3435974 / 2^32 day`.

Let `K0` be the B01 conductivity reconstructed at the fresh uniform seed and `q_eq=-K0`.

Three zero-divergence histories are frozen:

1. **BASE_EQ:** one interval with `q_top=q_bottom=q_eq`.
2. **DRY_RECOVER:** 10 intervals with `q_top=q_bottom=0`, then at most 24 intervals with `q_top=q_bottom=-2 K0`.
3. **WET_RECOVER:** 10 intervals with `q_top=q_bottom=-2 K0`, then at most 24 intervals with `q_top=q_bottom=0`.

Every interval therefore has equal top and bottom boundary flux. The construction changes internal throughflow history while imposing zero boundary-flux divergence.

A failed strict sample terminates that family. No retry, fallback, tolerance change or post-hoc forcing adjustment is allowed.

## Response firewall

The generator may emit only family, phase, accepted step, time, and committed node `H/theta`. The selector must not receive bottom exchange, terminal bottom flux, tangent, predictor or any future-response quantity.

For every emitted origin the selector reconstructs:

- `W_profile = sum(theta_i * 10 cm)`,
- `W_root30 = sum(theta_i * 10 cm)` for nodes 1 to 3,
- `M1 = sum(theta_i * 10 cm * z_i) / W_profile`, with `z=[-5,-15,...,-155] cm`.

Eligible comparisons are BASE_EQ versus recovery-stage states, plus DRY_RECOVER recovery versus WET_RECOVER recovery.

The frozen pair gate is:

- `|ΔW_profile| <= 1e-4 cm`,
- `|ΔW_root30| <= 1e-4 cm`,
- `|ΔM1| >= 1e-2 cm`.

Ranking is largest `|ΔM1|`, then smallest `|ΔW_root30|`, then smallest `|ΔW_profile|`, then smallest combined accepted-step count.

If no pair passes, E03 closes NO_MATCH without retuning amplitudes, stage lengths, `dt`, or thresholds.

## Qualification

Qualification requires exact 16 x 10 cm geometry, a strict accepted BASE_EQ control, strict mass-complete accepted prefixes, transaction-safe fail-closed behavior, and byte-identical O0/O2 observable output. Any selected pair must be persisted with all 16 node states before a response experiment is preregistered.

If a pair is selected, E04 is the only authorized next response step: common-time reconstruction followed by an identical forcing-free fixed-`H_c` probe with both total-water and upper-30-cm-water gates enforced.

## Boundaries

E03 is research evidence only. It does not admit production coupling changes, a second MODFLOW hydraulic state, or a universal root-zone state definition. It does not touch H5/RZM06B.
