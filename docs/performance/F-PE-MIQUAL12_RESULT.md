# F-PE-MIQUAL12 result — serialized manager component-cost attribution

Date: 2026-10-01

Status:

`MIQUAL12_REDUCED_SOLVE_DOMINANT`

Qualification authority:

- workflow run: `36828484815`;
- job: `110259437931`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@7db09b56deb99decf32f47d2deed72710a04e8b5`

## Preservation

The MIQUAL06 serialized seam gate remains green under diagnostic instrumentation.

The 40,000-interval MANAGER trajectory completes with:

- 40,000/40,000 committed external intervals;
- 100% reduced manager route;
- zero fallback;
- zero bypass;
- exact equilibrium physical state;
- hard mass clean.

The transaction pattern produces 120,000 successful reduced manager calls, consistent with external full/half/half temporal execution.

## Timing attribution

Monotonic clock:

- clock rate: 1,000,000,000 ticks/s;
- successful reduced calls: 120,000;
- total measured successful adapter ticks: 568,519,046;
- reduced Richards solve ticks: 520,736,279;
- adapter non-solve ticks: 47,782,767.

Shares:

- reduced solve: 0.91595, about 91.6%;
- all non-solve adapter work combined: 0.08405, about 8.4%.

Classification:

`MIQUAL12_REDUCED_SOLVE_DOMINANT`.

## Interpretation

The remaining production-shaped manager penalty is not primarily caused by:

- tail detection;
- reduced-request preparation;
- provider composition outside the solve;
- tail reconstruction;
- full candidate rematerialization;
- manager finalization.

All of those combined account for only about 8.4% of the measured successful adapter path in this attribution run.

The dominant cost is the reduced reference Richards solve itself.

This matters because MIQUAL11 already established that the manager performs 18.75% less deterministic row work while remaining about 3.1% slower overall. MIQUAL12 shows that additional adapter micro-optimization cannot plausibly recover most of that gap.

The next question is therefore not “which adapter copy can be removed?”, but:

why does the n=13 reduced reference solve consume so much wall/CPU time relative to the normal n=16 reference solve despite lower deterministic row work?

Possible mechanisms to test, without assuming any one is correct:

- fixed per-solve overhead dominates at these small dimensions;
- reduced workspace/provider route has different constant costs from the established full route;
- workspace generation/reset behavior differs;
- dimension reduction n=16 -> n=13 is too small to amortize manager/reduced-solver fixed costs;
- the deterministic work proxy n × nonlinear iterations is not proportional to actual cost at these dimensions.

## Qualified claim boundary

Qualified:

- reduced solve dominates measured manager adapter cost;
- non-solve adapter overhead is about 8.4% of adapter time in this fixture;
- further small adapter-copy optimizations are not the main route to net speedup.

Not qualified:

- exact reason reduced solve time is high;
- larger-dimension behavior;
- dynamic serialized performance;
- whole-SWAP or MultiSWAP performance.

## Consequence

Open:

`F-PE-MIQUAL13 — full-versus-reduced reference-solve cost scaling`.

MIQUAL13 should compare identical reference Richards solves at multiple dimensions, using the same hydraulic/provider/workspace family, and separate:

- fixed solve overhead;
- dimension-dependent cost;
- workspace reset/allocation behavior;
- deterministic work versus measured CPU/wall time.

No manager physics change is authorized.

## Production boundary

No default change.

`LEGACY_NUMERICS` remains production default.
