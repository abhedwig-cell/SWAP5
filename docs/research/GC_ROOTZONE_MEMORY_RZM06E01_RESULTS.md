# GC-RZM06E01 zero-divergence state expansion result

Date: 2026-09-22  
Preregistration: `c11c08282a3abc9b1beee3002f5a9a01df58d95f`  
Qualified workflow: `35740688388`, job `106789366648`  
Production changes: none

## Decision

E01 is qualified as:

`QUALIFIED_RESPONSE_BLIND_ZERO_DIVERGENCE_H2_ORIGIN_PAIR_SELECTED`.

This is the first 16-node real-HeadCalc pair in the RZM06 line that satisfies the frozen H2 state criteria before any interface-response quantity is inspected.

## Construction

Both families start from the same B01 hydrostatic physical origin and use the representation-safe dyadic interval

`dt = 3435974 / 2^32 d = 0.000800000037997961 d`.

The equilibrium control uses `q_top = q_bottom = -K0`.

The CLOSED family uses `q_top = q_bottom = 0`, so net imposed boundary-flux divergence is zero. It commits 14 strict Reference intervals. Step 15 fails solver convergence and is retained as fail-closed evidence; no fallback, retry policy change or tolerance relaxation is introduced.

## Selected pair

A is the accepted EQ control after step 1.

B is CLOSED after step 14.

State-only reconstruction gives:

- `W_profile(A) = 58.619184 cm`;
- `W_profile(B) = 58.619184 cm`;
- `|ΔW_profile| = 0 cm`;
- `M1(A) = -80.0 cm`;
- `M1(B) = -80.11123947403316 cm`;
- `|ΔM1| = 0.11123947403315526 cm`;
- frozen M1 requirement = `0.01 cm`;
- separation = 11.12 times the requirement.

Upper-30-cm water differs by `0.043931987299645314 cm`; this is descriptive and was not a selection gate.

All 16 pressure-head and water-content values for both selected origins are persisted in the machine-readable E01 result.

## Firewall

The selector reads only:

- family, step and time;
- node pressure head;
- node water content.

It does not parse bottom exchange, terminal flux, q_swap, predictor coefficients, tangents or any ROM held-out data.

## Consequence

E01 does not yet support or falsify H2. The selected pair is now immutable.

The next work unit must reconstruct these two origins at one common canonical time and only after successful reconstruction apply the same forcing-free mode-5 fixed-Hc Reference probe to both. No reselection is allowed after observing the response.
