# F-PE-MIQUAL13 preregistration — reference-solve dimension scaling

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@7db09b56deb99decf32f47d2deed72710a04e8b5`

Parent authority:

- MIQUAL12: `MIQUAL12_REDUCED_SOLVE_DOMINANT`.

## Purpose

Measure the actual cost scaling of the reference Richards solve with active dimension.

MIQUAL12 showed that about 91.6% of measured successful manager-adapter time is spent inside the reduced reference solve. MIQUAL13 tests whether the deterministic row-work proxy is representative of measured solve cost at the small dimensions used by the moving-interface manager.

## Frozen solver family

Use the same production reference Richards binding and B110 default MvG provider family used by MIQUAL09-12.

No manager wrapper is used in the timed region.

Hydraulic profile:

- O05-shaped parameters used by MIQUAL09;
- dz = 10 cm;
- explicit top flux = 0;
- fixed bottom flux = 0;
- zero source/sink;
- SWKIMPL=0;
- conductivity mean method=1;
- MAXIT16 evidence profile;
- hydrostatic zero-flux state.

## Frozen dimensions

Compile and measure exactly:

- n=8;
- n=10;
- n=11;
- n=12;
- n=13;
- n=14;
- n=16.

Each executable uses the same top-origin profile:

`h(i) = -120 + 10*(i-1) cm`.

## Timing protocol

Per dimension:

- 2,000 untimed warmup solves;
- exactly 200,000 timed solves per repetition;
- exactly 5 repetitions.

Execution order by repetition:

- odd repetitions: ascending dimension;
- even repetitions: descending dimension.

No timing sample deletion or substitution.

Primary metric:

- median elapsed nanoseconds per solve from monotonic `system_clock`.

Secondary:

- median CPU seconds per solve;
- nonlinear/Jacobian/linear/backtracking diagnostics;
- deterministic work proxy `n * nonlinear_iterations`.

## Analysis

For each dimension report ratios relative to n=16.

Key ratio:

`R13 = median_time_per_solve(n=13) / median_time_per_solve(n=16)`.

The deterministic row-work ratio for equal nonlinear iteration count is:

`13/16 = 0.8125`.

Also fit ordinary least squares across the seven median elapsed costs:

`cost(n) = a + b*n`.

Report:

- intercept `a`;
- slope `b`;
- fitted fixed-cost fraction at n=16: `a / (a + 16*b)`;
- fitted n=13/n=16 ratio.

## Frozen classifications

- `QUALIFIED_MIQUAL13_FIXED_OVERHEAD_DOMINANT` if R13 >= 0.95.
- `QUALIFIED_MIQUAL13_PARTIAL_DIMENSION_SCALING` if 0.85 < R13 < 0.95.
- `QUALIFIED_MIQUAL13_EFFECTIVE_DIMENSION_SCALING` if R13 <= 0.85.
- `MIQUAL13_SOLVER_BEHAVIOR_NOT_COMPARABLE` if convergence/iteration counts differ materially by dimension.
- `MIQUAL13_EXECUTION_INVALID` if timing or build is invalid.

## Consequence

If fixed overhead dominates, n=16 -> n=13 is too small a dimension reduction to justify the current runtime manager on speed grounds. Future work should investigate either larger safe reductions or reducing fixed solver overhead, not further adapter micro-optimization.

If dimension scaling is effective, investigate why the serialized reduced solve path does not realize that direct-solver saving.

## Production boundary

No production change. `LEGACY_NUMERICS` remains production default.
