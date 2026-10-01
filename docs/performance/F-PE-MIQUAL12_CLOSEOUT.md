# F-PE-MIQUAL12 closeout — serialized manager component-cost attribution

Date: 2026-10-01

Final status:

`MIQUAL12_REDUCED_SOLVE_DOMINANT`

MIQUAL12 closes the adapter-overhead attribution question.

Measured successful manager path:

- reduced Richards solve: about 91.6%;
- all other adapter work combined: about 8.4%.

Therefore another round of small adapter micro-optimizations is not justified as the main strategy.

Direct successor:

`F-PE-MIQUAL13 — full-versus-reduced reference-solve cost scaling`.

The successor must determine whether the current n=13 solve is intrinsically too small a reduction from n=16 to yield runtime benefit, or whether the reduced solver/workspace path has avoidable fixed overhead.

Production default remains `LEGACY_NUMERICS`.
