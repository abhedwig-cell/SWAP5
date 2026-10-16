# F-PE-PROFILE06 — difficult Richards practical-stack characterization

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent:
`F-PE-PROFILE05R2`

## Trigger

PROFILE05R2 established that the repaired short live FGC44 coupled loop is too easy for A2C to add measurable benefit on top of A1:

- A1 + A2C versus exact: 13/15 speed-positive, median about +3.39%;
- A1 alone: 15/15 speed-positive, median about +5.38%;
- A2C alone: 8/15 speed-positive, median about +0.57%;
- stack versus A1: median about -3.00%.

The same postimage still shows that roughly 90% of application runtime is inside the Reference backend.

Earlier A2C multistep qualification demonstrated genuine nonlinear-work reduction in difficult cases, including B01-wet, O05-wet and O14-wet.

## Purpose

Measure where the retained A2C practical envelope materially reduces Richards solve effort on production-shaped difficult transients, and identify the remaining dominant Reference-backend cost after that reduction.

PROFILE06 is observation-only.

No `src/**` modification is permitted.

## Primary questions

1. Which material/regime cases produce substantial nonlinear-work reduction under A2C?
2. How closely does wall-clock gain track reductions in:
   - nonlinear iterations;
   - Jacobian builds;
   - linear solves;
   - HeadCalc calls;
   - backtracking attempts;
   - constitutive evaluations?
3. Which cases remain expensive even after A2C?
4. On difficult directional/coupling-shaped cases, does A1 become complementary to A2C?
5. Which Reference-backend component remains the largest measured target after both retained modes?

## Stage P1 — difficult direct Richards matrix

Use the existing 20-step B01/B12/O05/O14 wet/mid/dry matrix with exact versus A2C.

A2C authority:

`practical_richards_a2c_active = true`

with the qualified `1e-8` convergence quartet.

For every case report:

- exact and A2C wall-clock runtime;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- HeadCalc calls;
- constitutive evaluations where exposed;
- accepted substeps;
- retries;
- head, water-content, flux and cumulative exchange deviations.

Run at least five timing repetitions per case and use the median runtime ratio.

## Stage P2 — case selection

Select difficult cases by measured exact work, not by soil label alone.

A case qualifies as difficult when exact uses materially more nonlinear work than the easy floor observed in the matrix.

Prefer the smallest set that spans distinct behavior, expected to include wet B01/O05/O14 if the current postimage reproduces prior evidence.

Freeze the selected set before any directional-stack timing.

## Stage P3 — directional/coupling-shaped difficult cases

For selected difficult cases that support a real accepted-direction request, compare:

1. exact;
2. A1 only;
3. A2C only;
4. A1 + A2C.

Do not synthesize A1 benefit on a route that does not request a tangent.

Measure direct same-postimage runtime and work counters.

## Scientific interpretation

Do not infer speedup from iteration counts alone.

Do not add percentages from separate microbenchmarks.

A candidate remaining hotspot is valid only if it is:

- present in the repaired production-shaped postimage;
- material in wall-clock time;
- associated with a clearly owned computation;
- and still present after retained A1/A2C work reduction.

## Closure

PROFILE06 closes with:

1. a difficult-case A2C runtime/work map;
2. a measured relationship between solve-work reduction and wall-clock gain;
3. a directional-stack result where applicable;
4. one factual remaining hotspot suitable for a separately preregistered next workunit, or a finding that no additional SWAP-side target is currently material.
