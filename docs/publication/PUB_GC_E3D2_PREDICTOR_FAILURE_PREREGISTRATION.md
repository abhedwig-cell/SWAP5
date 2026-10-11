# PUB-GC E3-D2 preregistration — whole-window predictor failure mechanism

## Status

**PREREGISTERED AFTER E3-D, BEFORE E3-D2 EXECUTION**

Date: 2026-09-18.

E3-D established that every predictor-envelope failure occurs at:

```text
104 = PREDICTOR_WHOLE_WINDOW_TRIAL_INCOMPLETE
```

before tangent construction or groundwater coupling.

E3-D2 diagnoses the returned kernel/canonical execution status and rejection history. It does not change the failed/successful predictor boundary and does not relax any model or temporal tolerance.

## Cases

For each window, evaluate the largest demonstrated successful point and the smallest demonstrated failed point:

```text
DeltaT=1e-4 day:
    q=3e-5 cm/day   READY reference
    q=1e-4 cm/day   first failed point

DeltaT=1e-3 day:
    q=1e-4 cm/day   READY reference
    q=3e-4 cm/day   first failed point

DeltaT=1e-2 day:
    q=1e-4 cm/day   READY reference
    q=3e-4 cm/day   first failed point
```

Total: six predictor-only cases.

## Diagnostic record

Immediately after the real SWAP predictor `run_trial`, before any early return, the qualification-only bridge records:

- kernel/canonical result status;
- `completed`;
- transaction calls;
- accepted substeps;
- attempts;
- retries;
- solver rejections;
- temporal rejections;
- temporal-certificate-unavailable rejections;
- mass rejections;
- trial rollbacks;
- internal retries;
- maximum temporal indicator;
- minimum accepted substep duration;
- maximum accepted substep duration;
- accepted-trajectory direction availability.

The diagnostic getter is test/qualification-only and remains readable after an unsuccessful configured initializer. Production SWAP5 and MODFLOW6 interfaces are unchanged.

## Interpretation

Canonical result status uses the existing runtime contract:

```text
0 = COMPLETED
1 = INVALID_REQUEST
2 = TRANSACTION_FAILED
3 = NO_PROGRESS
4 = SUBSTEP_LIMIT
```

Kernel-specific statuses, if observed, are retained verbatim and not remapped after the fact.

### Temporal-envelope evidence

A failed point is classified as temporal/retry-envelope limited only if the evidence actually shows temporal rejection/retry/substep exhaustion. Stage 104 alone is not sufficient.

### Solver-envelope evidence

If solver rejections dominate without temporal rejection, the limitation is attributed to the real Richards trial route, not to the coupler.

### Mass-envelope evidence

If mass rejections dominate, the mass qualification remains binding and is not relaxed for coupling convenience.

### Unavailable certificate

If temporal-certificate-unavailable rejections occur, this is a capability/publication problem distinct from an indicator exceeding its budget.

## Stop rule

E3-D2 is diagnostic only.

No tolerance, retry count, maximum substep count or head budget is changed in this workunit. Any proposed envelope expansion must become a separate scientific/qualification workunit after the mechanism is known.
