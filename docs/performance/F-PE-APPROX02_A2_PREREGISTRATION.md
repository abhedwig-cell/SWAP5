# F-PE-APPROX02 A2 preregistration — relaxed Richards convergence envelope

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Parent:
`F-PE-APPROX02 — practical Richards solve-effort frontier`

Current branch authority at preregistration:
`work/f-pe-approx02-richards-effort@ea310c0cd1acd9cf8609ddb3ca7f796e44b404ad`

## Evidence

Single-axis experiments showed that neither head tolerance nor balance tolerance alone unlocks meaningful solve-effort reduction.

On the hard O14-wet workload:

- head tolerance alone, even at very large multipliers, removes only one Newton iteration and yields roughly 2% runtime gain;
- balance tolerance alone leaves the exact 45-iteration route unchanged.

The Reference convergence contract requires both head-change and balance criteria. Relaxing them together is therefore the measured mechanism that reduces nonlinear effort.

## Combined frontier

A 12-case B01/B12/O05/O14 wet/mid/dry matrix compared exact behavior with joint head + compartment/total balance relaxation.

### 1e6 multiplier

- all 12 cases converged;
- median solver speedup: approximately 45%;
- worst relative head deviation: approximately 1.2e-6;
- worst relative bottom-flux deviation: approximately 1.0e-6.

### 1e8 multiplier

- all 12 cases converged;
- median solver speedup: approximately 55%;
- worst relative head deviation: approximately 5.34e-5;
- worst relative bottom-flux deviation: approximately 5.21e-5;
- worst relative water-content deviation: approximately 1.42e-5.

### 1e10 multiplier

- all 12 cases converged;
- median solver speedup: approximately 67%;
- worst relative head deviation: approximately 2.75e-3;
- worst relative bottom-flux deviation: approximately 2.79e-3;
- worst relative water-content deviation: approximately 4.15e-4.

The 1e10 setting remains potentially useful for a later aggressive mode, but its state/flux error grows by roughly two orders of magnitude for only about twelve additional median percentage points of solver speedup.

## Candidate A2

A2 therefore tests the conservative practical setting:

- head absolute tolerance multiplier: `1e8`;
- head relative tolerance multiplier: `1e8`;
- compartment balance tolerance multiplier: `1e8`;
- total balance tolerance multiplier: `1e8`;
- all other solver controls remain exact/current;
- default behavior remains OFF / exact.

With the current research base tolerance of `1e-12`, this corresponds to effective local thresholds of order `1e-4` in the existing native tolerance units.

## Why A2 is not admitted yet

The 12-case matrix consists of independent single solves.

A production practical mode must also demonstrate that small one-step errors do not accumulate materially across accepted transaction steps.

The next qualification therefore owns:

1. repeated accepted-step trajectory;
2. cumulative storage and bottom-exchange deviation;
3. canonical transaction mass ledger;
4. retry/substep behavior;
5. runtime gain over the complete transaction/application path.

## Required multi-step gates

Compare exact and A2 under the same forcing sequence.

At minimum report:

- terminal pressure-head profile error;
- terminal water-content profile error;
- cumulative bottom exchange error;
- storage change difference;
- canonical mass residual for each accepted interval and cumulative sequence;
- accepted substeps;
- retries / failed trials;
- nonlinear iterations and solver calls;
- wall-clock runtime.

The physical sequence must include nontrivial transient intervals, not repeated equilibrium solves.

## Provisional research envelope

For the next experiment only:

- terminal/cumulative state or flux deviations of order <=0.1% are considered strongly acceptable;
- deviations between 0.1% and 1% require explicit application-level interpretation;
- mass-balance deviation must be reported separately and cannot be hidden inside a state/flux percentage.

These are research interpretation bands, not production acceptance thresholds.

## Admission rule

A2 may become a production-shaped opt-in only if:

1. the multi-step transaction/application sequence remains stable;
2. cumulative errors remain bounded;
3. canonical mass accounting remains acceptable;
4. the runtime gain remains material end-to-end;
5. exact default behavior remains unchanged;
6. approximate provenance is explicit.

If cumulative drift is materially larger than the one-step matrix suggests, reject A2 or tighten the multiplier before production implementation.
