# PUB-GC E3A preregistration — real-SWAP coupling-envelope characterization

## Status

**PREREGISTERED AFTER E3 ENTRY FAILURE, BEFORE E3A EXECUTION**

Date: 2026-09-18.

Parent E3 preregistration remains unchanged:

`PUB_GC_E3_PREREGISTRATION.md`

The first E3 execution attempted all 40 preregistered cases and produced zero successful cases:

- `DeltaT = 2.5e-5` and `5.0e-5 day`: qualification-bridge initialization failed before the coupling matrix;
- `DeltaT >= 1.0e-4 day`: initialization succeeded, but the first driven prescribed-head corrector failed through the real SWAP transaction participant.

This is treated as an **entry-envelope failure**, not as evidence for or against loose versus iterative coupling.

E3A characterizes that envelope without changing E3's matrix, tolerances, feedback classes or 2 mm external head drive.

## Questions

1. What is the minimum coupling-window duration for which the current admitted real-SWAP predictor/tangent qualification route initializes?
2. At each already-initializable E3 window, what prescribed-head perturbation from the accepted reference head remains admissible through the real corrector route?
3. Are failures caused primarily by solver rejection, temporal-certificate rejection, mass rejection, or an outer qualification/admission condition?

## A. Initialization-duration grid

Fresh-process initialization is attempted at:

```text
1.0e-5
2.5e-5
5.0e-5
6.25e-5
7.5e-5
8.75e-5
1.0e-4
2.0e-4
4.0e-4 day
```

For each duration record the last reached qualification stage.

The stage instrumentation is diagnostic only and changes no acceptance condition.

## B. Prescribed-head perturbation grid

For each duration that initializes among:

```text
1.0e-4
2.0e-4
4.0e-4 day
```

evaluate real SWAP correctors from the same immutable accepted origin at offsets:

```text
0
+/- 1e-6
+/- 2e-6
+/- 5e-6
+/- 1e-5
+/- 2e-5
+/- 5e-5
+/- 1e-4
+/- 2e-4
+/- 5e-4 m
```

No failed point is retried with relaxed tolerances.

Each diagnostic trial is discarded.

## C. Diagnostic fields

For every attempted corrector record:

- kernel result status;
- completed flag;
- accepted substeps;
- retries;
- solver rejections;
- temporal rejections;
- mass rejections;
- whole-window bottom exchange when available.

The diagnostic path uses:

- the same committed state;
- a newly captured checkpoint of that state;
- the same groundwater-head materializer;
- the same corrector backend;
- the same numerical configuration.

It publishes no candidate and mutates no committed state.

## Interpretation

E3A may identify a bounded admissible envelope but does **not** expand it.

If the original E3 head drive lies outside the measured admissible envelope, the original E3 result remains `BLOCKED_BY_CURRENT_REAL_SWAP_ENVELOPE`.

Any later E3B proof-of-mechanism experiment inside the measured envelope must be separately preregistered and clearly distinguished from the original 2 mm E3 experiment.

If a scientifically useful E3 regime requires expanding the real-SWAP corrector envelope, that becomes a numerical qualification workunit rather than a reason to loosen transaction or mass tolerances inside the publication script.
