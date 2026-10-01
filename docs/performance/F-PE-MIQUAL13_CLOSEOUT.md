# F-PE-MIQUAL13 closeout — fused persistent serialized-manager fast path

Date: 2026-10-01

Final status:

`MIQUAL13_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`

Candidate C is semantically clean and further reduces the production-shaped N=16 equilibrium penalty.

Progress:

- original adapter: about +5.5%;
- candidate A: about +4.7%;
- candidate B: about +3.1%;
- candidate C: about +2.3% median wall.

Deterministic nonlinear work remains 18.75% lower.

The remaining N=16 gap is small and likely dominated by fixed composition cost relative to an extremely cheap solve.

Direct successor:

`F-PE-MIQUAL14 — serialized manager scale-crossover benchmark`.

Test N=16, N=32 and N=64 before any more micro-optimization.

Production default remains `LEGACY_NUMERICS`.
