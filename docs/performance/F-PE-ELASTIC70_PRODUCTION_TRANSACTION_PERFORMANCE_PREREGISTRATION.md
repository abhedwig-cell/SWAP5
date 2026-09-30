# F-PE-ELASTIC70 — production transaction performance validation

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@a3af828f442da7665615b222a0d3a7e5e614ac53`

Parent application policy:
F-PE-ELASTIC69.

## Purpose

Measure whether the canonically admitted 0.20 cm GENERATED-ELAS mode-7
application policy produces the intended reduction in work on the actual
ELASTIC65 mass-first serialized transaction path.

This workunit does not recalibrate the 0.20 cm value and does not reopen the
ELASTIC67/68 physical-oracle line.

## Production-shaped composition under test

Compose already admitted capabilities only:

1. ELASTIC44 application-host preparation of a GENERATED ELAS parameter
   postimage from explicit row interchange;
2. mode 7, swkimpl=0 Reference Richards execution;
3. admitted temporal history;
4. ELASTIC65 normalized mode-7 C-SAFE certificate;
5. the existing mass-first retry/accept transaction path.

No production source change is allowed.

## Frozen comparison

Compare exactly:

- strict research benchmark arm: 0.01 cm;
- admitted application-policy arm: 0.20 cm.

Use the same generated parameter postimage, accepted origin, forcing and retry
configuration for both arms.

Exercise h0=-20 cm with top-flux perturbations:

- -0.05;
- -0.035;
- +0.035;
- +0.05 cm/day.

Initial attempted interval:

`dt = 0.015625 day`.

Maximum retries:
8.

The generated ELAS row source and physical parameter postimage must be identical
between arms.

## Deterministic gates

For each forcing case record:

- completion;
- transaction retries;
- temporal rejections;
- mass rejections;
- solver rejections;
- minimum accepted substep duration.

Require:

1. generated prior is active and finite;
2. O0/O2 observable identity;
3. the 0.20 cm arm never has fewer completed cases than 0.01 cm;
4. for cases completed by both arms, 0.20 cm never has more transaction retries;
5. hard mass acceptance remains unchanged and no source tolerance is modified;
6. source delta relative to canonical is empty.

## Runtime observation

Repeat the four-case sequence enough times to obtain a stable coarse wall/CPU
observation for each arm. Runtime is descriptive only and is not an admission
gate on shared CI hardware.

The deterministic retry reduction is the primary work metric.

## Decision

If the 0.20 cm arm improves completion and/or reduces retries on the actual
production transaction route without changing hard mass or source policy,
classify the application policy as production-shaped performance confirmed.

If no deterministic work benefit appears, retain ELASTIC69 admission but do
not claim a production-path speed benefit from this workunit.
