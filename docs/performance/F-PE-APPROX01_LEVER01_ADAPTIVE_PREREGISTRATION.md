# F-PE-APPROX01 Lever01 adaptive refresh preregistration

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Parent lever:
`F-PE-APPROX01 Lever01 — lagged bottom-head coupling tangent`

## Evidence

Fixed cadence is highly effective in runtime terms, but the error envelope depends strongly on hydraulic regime and corrector-head amplitude.

Across B01, B12, O05 and O14:

- the worst case is consistently O05-wet;
- at ±0.5 cm, lag-4 reaches about 1.57% maximum relative tangent error;
- at ±1.0 cm, lag-4 reaches about 3.20%;
- at ±2.0 cm, lag-4 reaches about 6.63%;
- lag-2 is better but still reaches about 1.65% at ±1.0 cm and about 3.54% at ±2.0 cm.

A universal fixed cadence therefore does not provide a stable error envelope across corrector amplitude.

## Adaptive hypothesis

Reuse the cached tangent while the current prescribed bottom head remains sufficiently close to the head at which the tangent was last refreshed.

Refresh when either:

1. absolute bottom-head displacement from the tangent origin exceeds a threshold; or
2. tangent age reaches a hard maximum number of coupling evaluations.

The head-displacement criterion targets the directly observed source of tangent variation.

The maximum-age criterion prevents indefinite reuse when other accepted-state variables evolve even if bottom head changes little.

## Initial thresholds

Research only:

- head threshold: 0.25 cm;
- head threshold: 0.50 cm;
- head threshold: 1.00 cm.

For all three:

- maximum age: 8 evaluations.

No threshold is production-approved in advance.

## Measurement

For each B01/B12/O05/O14 wet/mid/dry sweep and each tested amplitude:

report:

- refresh fraction;
- tangent evaluations avoided;
- maximum and mean absolute tangent error;
- maximum and mean relative tangent error;
- controlling material/regime.

Compare directly with fixed lag-2/4/8.

## Selection rule

A useful adaptive rule must dominate at least one fixed cadence option:

- equal or lower worst-case error at similar or lower refresh fraction; or
- materially lower refresh fraction at the same error envelope.

If head displacement alone fails to control error, do not tune the threshold indefinitely. Move to a state-aware refresh indicator.

## Production boundary

This remains a research-side replay experiment.

No production cache, cadence flag, or approximate response provenance is added until the adaptive frontier is qualified.
