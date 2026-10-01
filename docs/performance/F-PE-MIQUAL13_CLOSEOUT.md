# F-PE-MIQUAL13 closeout — reference-solve dimension scaling

Date: 2026-10-01

Final status:

`QUALIFIED_MIQUAL13_PARTIAL_DIMENSION_SCALING`

MIQUAL13 closes the small-dimension scaling question.

The direct reference solver does become cheaper as active dimension falls, but n=13 versus n=16 yields only about 5.8% measured solve-time saving despite an 18.75% deterministic row-work reduction.

A fitted linear model attributes roughly 37% of n=16 solve cost to fixed overhead.

Combined with MIQUAL12, the conclusion is:

- the remaining serialized manager penalty is not mainly adapter waste;
- the n=16 benchmark is too small for a 3-node reduction to amortize fixed solve/runtime costs;
- further small adapter micro-optimization is not the main path.

Direct successor:

`F-PE-MIQUAL14 — larger-dimension reference-solve and manager break-even scaling`.

The manager remains technically qualified and explicit opt-in. Its production speed case now depends on larger realistic dimensions and sufficient reconstructible saturated-tail depth.

Production default remains `LEGACY_NUMERICS`.
