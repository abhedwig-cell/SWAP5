# F-PE-APPROX02 R1 preregistration — relaxed Richards convergence envelope

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Parent:
`F-PE-APPROX02`

## Candidate

R1 is the first concrete practical Richards solve-effort candidate.

Research settings:

- head absolute tolerance: `1e-2 cm`;
- head relative tolerance: `1e-2`;
- compartment balance tolerance: `1e-2`;
- total balance tolerance: `1e-2`;
- ponding tolerance unchanged from exact reference;
- max nonlinear iterations unchanged;
- max backtracking unchanged;
- timestep / substep policy unchanged;
- constitutive physics unchanged;
- A1 tangent-cache policy unchanged and independent.

These correspond to the `1e10` head and balance multipliers in the APPROX02 research fixture.

## Why R1

Across B01/B12/O05/O14 and wet/mid/dry single-step production-shaped tests:

- all 12 cases converged;
- median solver speedup: approximately `67%`;
- minimum case speedup: approximately `40%`;
- worst relative pressure-head deviation: approximately `0.275%`;
- worst relative bottom-flux deviation: approximately `0.279%`;
- worst relative water-content deviation: approximately `0.041%`.

The less aggressive `1e6` and `1e8` candidates are retained as comparison points but are not advanced in parallel.

## Critical limitation of current evidence

The current matrix is one-step evidence.

It does not establish:

- multi-step error accumulation;
- cumulative bottom-exchange error;
- production transaction mass-ledger behavior;
- failure/retry behavior over a trajectory;
- coupled MODFLOW endpoint behavior.

R1 may not be production-admitted until these are measured.

## Required next gates

### 1. Multi-step trajectory gate

Across B01/B12/O05/O14 wet/mid/dry:

- run exact and R1 from identical initial state and forcing;
- advance accepted state step by step;
- compare terminal pressure head and water content;
- compare cumulative bottom exchange;
- compare per-step bottom flux;
- record nonlinear iterations, backtracking and failures.

### 2. Production transaction mass gate

Use canonical transaction/application accounting, not only solver-local diagnostics.

Compare:

- accepted storage change;
- total in/out;
- canonical mass residual;
- cumulative accepted bottom exchange.

R1 must not gain speed by bypassing or weakening transaction mass-accounting authority.

### 3. Coupled MODFLOW gate

With A1 held fixed or disabled consistently in both arms:

- compare final MODFLOW head;
- coupled iteration count;
- cumulative interface exchange;
- convergence/failure behavior;
- end-to-end runtime.

## Error reporting

Report absolute and relative errors.

For multi-step trajectories report:

- maximum instantaneous error;
- final-state error;
- cumulative exchange error;
- error growth with step number.

A candidate is rejected if error grows without a stable bound even when the final one-step matrix looked acceptable.

## Default behavior

R1 is research-only and default OFF.

No production numerical configuration is changed by this preregistration.

## Admission rule

R1 may become a production-shaped opt-in only if:

1. multi-step state and cumulative-flux errors remain bounded;
2. canonical mass accounting remains inside a declared practical envelope;
3. no meaningful failure/retry regression appears;
4. coupled MODFLOW behavior remains acceptable;
5. runtime gain remains materially larger than A1 and exact-P0/P1 residual gains;
6. exact default behavior remains unchanged.
