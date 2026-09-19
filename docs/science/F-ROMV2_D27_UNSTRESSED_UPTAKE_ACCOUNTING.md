# F-ROMV2 D27 — unstressed root-uptake accounting preflight

**Decision:** `D27_UNSTRESSED_TOTAL_UPTAKE_ACCOUNTING_PREFLIGHT_PASS`

D27 is deliberately narrower than a root-active FMC trajectory.

It asks only whether the current SWAP root-uptake route and the literature-bound
FMC finite-volume interpretation can remove the same prescribed **total**
unstressed transpiration water depth while closing their water ledgers.

## Frozen synthetic state

The state is B01 moisture bin 170 of the D12/D24 200-bin discretization:

- theta = 0.3663699;
- effective saturation = 0.85;
- pressure head = -29.793709 cm;
- root-zone depth = 30 cm;
- process interval = 10 s;
- potential transpiration = 0.4 cm d-1.

For the frozen Feddes parameters the PTRA=0.4 critical drought head is

-500 cm.

The synthetic state is therefore safely unstressed.

## SWAP current-source result

D27 compiles and executes the current F-CI31 process/binding source rather than
reimplementing Feddes in the analyzer.

The three rooted 10-cm nodes use cumulative root fractions

[0, 0.1, 0.55, 1].

The resulting sink rates are:

- 0.04 cm d-1;
- 0.18 cm d-1;
- 0.18 cm d-1.

Their sum is exactly 0.4 cm d-1 at reported precision.

The 10-s integrated water depth is

4.62962962962963e-5 cm.

O0 and O2 SWAP outputs are byte-identical.

## FMC finite-volume result

The selected moisture-bin width is

0.00203747.

A fully occupied right-most bin over the 30-cm root zone therefore represents

0.0611241 cm

of finite-volume water.

The 10-s transpiration demand requires only a withdrawal length of approximately

0.02272244 cm

from that bin.

The post-withdrawal right-most-bin length remains approximately 29.97728 cm, so
no inventory exhaustion or structural ambiguity is involved.

The FMC root-zone storage decrement and whole-column storage decrement both
equal the prescribed uptake depth within approximately

7.47e-16 cm.

The frozen accounting gate is 1e-14 cm.

## What is equivalent

D27 establishes exact total-uptake equivalence for this synthetic unstressed
operation:

- SWAP total uptake depth = FMC removed depth;
- difference = 0 at reported precision;
- both are explicitly mass-accounted.

## What is not equivalent

Spatial extraction is intentionally different.

SWAP distributes potential uptake across three rooted nodes and applies the
restricted Feddes response to those node states.

The modern FMC formulation removes water preferentially from the right-most
water-containing moisture bin within the root zone.

D27 does not treat these two sink fields as physically identical.

This distinction is part of the model-structure comparison, not an error to be
hidden by a common sink mapping.

## Authority boundary

A positive D27 does **not** authorize native FMC root-active trajectories.

The synthetic withdrawal is unambiguous because it contains no simultaneous
surface front, falling slug or groundwater-front evolution.

The detailed native update of a composite FMC state under root extraction still
requires primary or traceable secondary implementation authority.

The identified University of Wyoming M2WC70 authors' archive remains the
preferred secondary oracle, but its binary has not yet been materialized
through the current tool route.

Therefore D27 does not qualify:

- native composite FMC root-active trajectories;
- FMC drought-stress feedback;
- seasonal ET;
- drought memory/recovery;
- application acceptance;
- formal performance;
- production ROM.

Production ROM remains unauthorized.
