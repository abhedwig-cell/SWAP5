# F-PE-MIQUAL12 preregistration — serialized manager component-cost attribution

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- MIQUAL11: `MIQUAL11_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`.

## Purpose

Measure the remaining production-shaped moving-interface runtime overhead before any further optimization.

No physics, manager eligibility, numerical tolerance, reconstruction, fallback, benchmark workload or production default may change.

## Frozen first attribution

Instrument the existing MIQUAL11 adapter with monotonic `system_clock` counters for:

1. total successful reduced-route adapter time;
2. time spent inside the reduced reference Richards solve;
3. successful reduced-route call count.

Derived:

`adapter_non_solve = adapter_total - reduced_solve`.

Use the existing MIQUAL09 40,000-interval equilibrium trajectory in MANAGER mode.

The transaction executes full/half/half physical advances, so approximately 120,000 successful reduced adapter calls are expected.

## Measurement rule

This is attribution-only instrumentation.

Do not use the instrumented wall time as a production speed claim.

Require:

- MIQUAL06 seam gate remains green;
- 40,000/40,000 committed equilibrium intervals;
- 100% reduced routing;
- zero fallback/bypass;
- exact physical final state;
- positive monotonic timer rate;
- adapter total ticks >= reduced solve ticks.

## Frozen interpretation

- `MIQUAL12_ADAPTER_NON_SOLVE_DOMINANT`: non-solve adapter share >= 50% of measured adapter time.
- `MIQUAL12_REDUCED_SOLVE_DOMINANT`: reduced solve share > 50%.
- `MIQUAL12_MIXED_COMPONENT_COST`: neither component can be treated as a practically dominant target due to timer resolution/noise or inconsistent repeats.
- `MIQUAL12_EXECUTION_INVALID`: timing or semantic gate invalid.

If adapter non-solve dominates, the next workunit may split request/provider/rematerialization costs.

If reduced solve dominates, further adapter micro-optimization is unlikely to recover the remaining runtime gap at n=13 and the line should pivot to larger dimension reduction or broader solver cost.

## Production boundary

No default change. `LEGACY_NUMERICS` remains production default.
