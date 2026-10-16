# F-PE-APPROX01 A1 preregistration — bounded same-origin tangent cache

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Parent:
`F-PE-APPROX01 Lever01 — lagged bottom-head coupling tangent`

Current branch authority at preregistration:
`work/f-pe-approx01-tangent-cadence@c9a6c067086108679ee0ab4bfd3f7b46ac7abcee`

## Evidence

The exact DIR01 postimage still carries a bottom-head directional increment of roughly 73% above Reference.

APPROX01 has now measured the tangent error/runtime frontier.

### Exact-solve timing

Paired benchmarks in which every evaluation retains the exact Richards physical solve and only tangent construction is skipped on non-refresh evaluations show approximate median speedups:

- lag-2: 18-22%;
- lag-4: 28-34%;
- lag-8: 32-40%.

Physical solve checksums remain identical.

### Material/regime tangent frontier

Qualified matrix:
- B01, B12, O05, O14;
- wet, mid, dry;
- bottom-head corrector sweep to approximately ±0.5 cm.

Worst case is O05-wet.

At ±0.5 cm:
- lag-2 worst relative tangent error: about 0.8%;
- lag-4/8 worst relative tangent error: about 1.6%;
- worst local flux-prediction error relative to the actual flux excursion remains below about 0.8% for lag-4/8.

### Larger corrector amplitudes

Fixed cadence deteriorates as head distance grows.

Worst O05-wet relative tangent errors:

- ±1 cm: about 1.65% for lag-2, about 3.2-3.3% for lag-4/8;
- ±2 cm: about 3.5% for lag-2, about 6.6-7.1% for lag-4/8.

Therefore cadence alone is not an adequate bound.

### Adaptive head-delta frontier

A head-delta refresh trigger strongly bounds the error.

With a 0.5 cm head threshold and a maximum age of eight evaluations:

- ±0.5 cm pattern: about 83% of tangent evaluations avoided;
- ±1 cm pattern: about 67% avoided;
- ±2 cm pattern: about 33% avoided;
- worst relative tangent error over the 4x3 material/regime matrix stays about 1.65% or lower.

A 0.25 cm threshold is more conservative, keeping the current worst case below about 0.8%, but refreshes substantially more often.

## Candidate A1

A1 tests a bounded cache for the physical bottom-head response tangent.

The cache is valid **only within one captured coupling origin and one coupling window**.

Initial experimental policy:

- default OFF;
- opt-in only;
- exact physical SWAP solve on every trial;
- fresh tangent on the first trial from an origin;
- tangent reuse allowed while:
  - absolute prescribed bottom-head displacement from the tangent's refresh head is <= 0.5 cm;
  - fewer than 8 evaluations have occurred since refresh;
  - origin lineage/revision and coupling window are unchanged;
  - previous tangent was valid and finite;
- otherwise refresh the tangent.

## Mandatory invalidation

The tangent cache must be discarded on:

- capture of a new origin;
- commit;
- abandon origin;
- lineage/revision change;
- coupling-window change;
- tangent-unavailable result;
- trial failure/retry path that invalidates tangent provenance;
- nonfinite cached tangent;
- any unsupported route or control-coordinate change.

No tangent may cross an accepted physical timestep boundary.

## Semantics

A1 approximates only the response derivative supplied to the coupling iteration.

It must not approximate:

- accepted pressure head;
- water content;
- bottom exchange of the physical trial;
- mass balance;
- transaction acceptance;
- nonlinear solver convergence;
- committed SWAP state.

For a given prescribed-head sequence, physical trial outputs must remain identical to fresh-tangent mode.

## Diagnostics

Any implementation candidate must expose at minimum:

- approximate tangent mode enabled/disabled;
- fresh tangent count;
- reused tangent count;
- refresh reason;
- cached tangent origin lineage/revision;
- cached tangent window;
- cached tangent refresh head;
- reuse age.

A reused tangent may never be presented as a newly computed exact accepted-trajectory tangent without explicit provenance.

## Experimental admission gates

Before any production admission:

1. run production-shaped fresh versus A1 same-origin corrector sequences;
2. confirm exact physical state/flux/mass identity;
3. measure actual tangent-computation avoidance and wall-clock speedup;
4. compare cached tangent and coupling flux prediction against fresh tangent authority;
5. exercise at least B01/B12/O05/O14 wet/mid/dry;
6. demonstrate cache invalidation on new origin, commit, retry/failure and window change;
7. keep default mode bit-for-bit equivalent to the exact path.

## Initial envelope

The 0.5 cm / max-age-8 rule is a research candidate, not yet a production guarantee.

Current evidence supports a working target of roughly <=2% local tangent error over the qualified matrix.

The end-to-end MODFLOW response error remains to be measured before admission.
