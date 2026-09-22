# GC-RZM06E01 zero-divergence state-space expansion

Date: 2026-09-22  
Machine-readable preregistration: `c11c08282a3abc9b1beee3002f5a9a01df58d95f`  
Production changes: none

## Purpose

D03 exhausted the existing strict DISCOVERY library without finding an origin pair that satisfies the unchanged H2 state gate. E01 therefore creates new accepted states prospectively rather than relaxing the gate or unblinding held-out data.

## Construction

The carrier is the qualified C01 16 x 10 cm B01 pure-hydraulics Reference column.

Two fresh histories start from the same `Se=0.85` physical state:

1. **EQ**: one mode-2 interval with `q_top = q_bottom = -K0`, the natural equilibrium throughflow of the uniform-pressure-head profile.
2. **CLOSED**: up to 64 mode-2 intervals with `q_top = q_bottom = 0`.

Within each family the prescribed top and bottom native fluxes are identical. The integrated external flux divergence is therefore zero by construction. Total profile water should consequently remain equal apart from numerical mass closure, while the CLOSED column is free to develop an internal gravity-driven vertical redistribution.

The interval is the representation-safe dyadic duration already qualified in D02R1:

`dt = 3435974 / 2^32 d ≈ 0.000800000037997961 d`.

## Transaction rules

Every interval is a strict Reference-floor sample:

- one physical advance;
- no automatic temporal subdivision;
- hard mass gate `1e-12 cm`;
- explicit candidate commit only after the gate;
- no research fallback;
- no tolerance, retry-budget or forcing retuning after execution.

If a CLOSED interval fails, the family stops at the latest accepted state after proving the failed sample did not mutate that committed origin.

## Response firewall

The generator emits only family/step/time provenance and committed node pressure head and water content.

The selector reconstructs:

- `W_profile = Σ(theta_i * 10 cm)`;
- `M1 = Σ(theta_i * 10 cm * z_i) / W_profile`;
- upper-30-cm water for description only.

It does not receive bottom exchange, terminal flux or any future-response quantity.

The physical H2 state gate remains:

- `|delta W_profile| <= 1e-4 cm`;
- `|delta M1| >= 1e-2 cm`.

If a pair is selected it is persisted before any mode-5 fixed-Hc response experiment. Selection alone does not test H2.
