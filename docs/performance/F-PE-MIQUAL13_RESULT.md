# F-PE-MIQUAL13 result — reference-solve dimension scaling

Date: 2026-10-01

Status:

`QUALIFIED_MIQUAL13_PARTIAL_DIMENSION_SCALING`

Qualification authority:

- workflow run: `36829710759`;
- job: `110263286214`;
- workflow conclusion: SUCCESS.

Canonical authority at final interpretation:

`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

The canonical delta since MIQUAL12 is PPA-WU05A10 macropore rapid-drain work. It touches macropore configuration/runtime surfaces but not the bare reference Richards solver family used by MIQUAL13.

## Validity

All frozen dimensions complete all repetitions with identical solver behavior:

- nonlinear iterations per solve: 1;
- Jacobian builds per solve: 1;
- linear solves per solve: 1;
- backtracking attempts per solve: 1.

Valid dimensions:

- n=8;
- n=10;
- n=11;
- n=12;
- n=13;
- n=14;
- n=16.

Thus the timing comparison is solver-behavior comparable.

## Measured median solve cost

Median wall cost per solve:

- n=8: 2610 ns;
- n=10: 3116 ns;
- n=11: 3365 ns;
- n=12: 3595 ns;
- n=13: 3675 ns;
- n=14: 3751 ns;
- n=16: 3902 ns.

Ratios relative to n=16:

- n=8: 0.6688;
- n=10: 0.7985;
- n=11: 0.8622;
- n=12: 0.9212;
- n=13: 0.9416;
- n=14: 0.9613;
- n=16: 1.0000.

CPU ratios are essentially the same.

## n=13 result

Measured n=13 / n=16 wall ratio:

`0.94163`.

Measured CPU ratio:

`0.94154`.

Deterministic row-work ratio:

`13/16 = 0.8125`.

Therefore the deterministic row-work proxy substantially overstates the actual solve-time saving at this small dimension.

Reducing the active dimension from 16 to 13 saves only about:

`5.8%`

of direct reference-solver wall time, not 18.75%.

## Fitted fixed-cost model

Ordinary least-squares fit across the seven median wall costs:

`cost(n) = a + b*n`

with approximately:

- intercept a = 1502 ns;
- slope b = 160.7 ns/node.

At n=16 the fitted fixed-cost fraction is approximately:

`36.9%`.

The fitted n=13/n=16 ratio is approximately:

`0.8816`.

The directly measured n=13 ratio is even less favorable, 0.9416.

## Interpretation

MIQUAL13 explains the MIQUAL09-11 performance paradox.

The moving-interface manager was correctly reducing nonlinear dimension and deterministic row work, but for n=16 the reference solve contains a large fixed-cost component. A 3-node reduction therefore removes much less measured runtime than the deterministic work proxy suggests.

MIQUAL12 showed that about 91.6% of the measured manager-adapter path is the reduced solve itself. MIQUAL13 now shows that this reduced solve is only about 5.8% cheaper at n=13 than at n=16.

That saving is too small to cover the remaining serialized manager composition cost.

This means the present negative runtime result is not evidence against variable-dimension solving as an architecture. It is evidence that:

- n=16 -> n=13 is too small a production benchmark to demonstrate the intended speed benefit;
- fixed solve overhead matters strongly at small dimensions;
- deterministic work ratios must not be used as wall-time proxies without dimension scaling.

## Classification

`QUALIFIED_MIQUAL13_PARTIAL_DIMENSION_SCALING`

## Consequence

Do not continue adapter micro-optimization as the primary route.

Open:

`F-PE-MIQUAL14 — larger-dimension reference-solve and manager break-even scaling`.

MIQUAL14 should test production-shaped larger dimensions and reductions, at minimum around:

- n=32;
- n=48;
- n=64;

and quantify the active/full dimension fraction required for net runtime benefit after the measured manager overhead.

The key question becomes whether realistic SWAP Heritage columns operate in a regime where enough of the saturated lower column can be reconstructed to cross that break-even point.

## Production boundary

No production-default change.

`LEGACY_NUMERICS` remains production default.
