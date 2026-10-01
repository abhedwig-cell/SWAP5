# F-PE-MIQUAL11 closeout — zero-source/sink invariant optimization

Date: 2026-10-01

Final status:

`MIQUAL11_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`

Candidate B is semantically clean and materially reduces runtime overhead.

Progress across the production-shaped equilibrium benchmark:

- original manager penalty: about +5.5%;
- after candidate A: about +4.7%;
- after candidate B: about +3.1%.

Deterministic nonlinear work remains 18.75% lower than LEGACY.

The remaining gap is now small enough that further optimization must be evidence-driven.

Direct successor:

`F-PE-MIQUAL12 — serialized manager component-cost attribution`.

Do not add another optimization candidate before component timing identifies the dominant remaining cost.

Production default remains `LEGACY_NUMERICS`.
