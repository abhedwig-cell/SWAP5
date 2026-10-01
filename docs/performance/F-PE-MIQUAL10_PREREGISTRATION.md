# F-PE-MIQUAL10 preregistration — serialized manager overhead attribution and zero-waste adapter audit

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_OPTIMIZATION_RESULTS`

Canonical authority:

`integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

Parent authorities:

- MIQUAL06: `QUALIFIED_MIQUAL06_SERIALIZED_RUNTIME_SEAM`;
- MIQUAL09: `MIQUAL09_EQUILIBRIUM_PERFORMANCE_NOT_READY`.

## Problem statement

MIQUAL09 established:

- exact physical equivalence;
- 100% reduced route;
- deterministic work ratio 0.8125;
- median wall ratio 1.05538;
- median CPU ratio 1.05532.

Therefore current runtime composition overhead is larger than the 18.75% deterministic nonlinear-work saving.

## Frozen first attribution target

Static source audit identifies two per-manager-call heap-allocation sites:

1. `saturated_tail_start` allocates a logical saturated-state vector;
2. `fmr_moving_interface_runtime_solve` allocates `tail_h` and `tail_theta`.

Under the MIQUAL09 equilibrium transaction pattern:

- 40,000 external intervals;
- external full-half temporal mode;
- three accepted/trial model advances per interval;
- manager is eligible on every advance.

Thus these sites are exercised approximately 120,000 times per timed trajectory.

The first MIQUAL10 optimization candidate is frozen to:

- replace saturated-tail temporary-vector allocation with allocation-free scalar scanning;
- move tail pressure/theta scratch into adapter-owned persistent buffers;
- reallocate those buffers only when tail shape changes.

No other optimization is included in candidate A.

## Preservation gates

Candidate A must preserve:

- MIQUAL06 serialized seam gate;
- Z43F manager seam smoke;
- default-off behavior;
- full accepted-state authority;
- reduced active dimension;
- exact full rematerialization;
- full fallback and full bypass;
- physical state equivalence;
- manager eligibility envelope;
- all numerical tolerances.

## Performance requalification

Re-run the unchanged MIQUAL09 paired benchmark protocol:

- 40,000 equilibrium intervals;
- 11 alternating pairs;
- same gates and workload.

Classify candidate A:

- `QUALIFIED_MIQUAL10_ZERO_WASTE_RUNTIME_RECOVERY` if MIQUAL09-equivalent physical/route gates pass and median wall ratio <1.00 and median CPU ratio <1.00;
- `MIQUAL10_OVERHEAD_REDUCED_BUT_NOT_RECOVERED` if performance improves materially versus MIQUAL09 but remains >=1.00;
- `MIQUAL10_ZERO_WASTE_NO_BENEFIT` if no meaningful improvement;
- `MIQUAL10_SEMANTIC_REGRESSION` on any preservation failure;
- `MIQUAL10_EXECUTION_INVALID` on invalid measurement.

No post-exposure optimization may be folded into candidate A. Further candidates require a new preregistered successor.

## Production boundary

No default change.

`LEGACY_NUMERICS` remains production default.
