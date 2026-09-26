# F-PE-PROFILE05 fixed-build repeatability preregistration

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

## Trigger

Two observation sets on identical production source gave different coupled robustness outcomes:

- inherited exact-vs-A2C runner: 4/6 completed, 2/6 status-6 failures with arm attribution unavailable;
- arm-attribution runner: exact 6/6 PASS and A2C 6/6 PASS.

The second harness changed shell-level failure capture only.

## Question

Does one fixed compiled exact/A2C binary pair produce intermittent live coupled failures when executed repeatedly?

## Protocol

Compile exact and A2C once from the current PROFILE05 postimage using the same code generation, compiler flags and pinned MODFLOW/xmipy/flopy dependencies as the inherited APPROX02 runner.

Then, without rebuilding, execute 20 independent Python coupling processes for each arm:

- exact;
- A2C at `1e-8`.

Alternate exact and A2C by cycle.

Each process initializes its own FGC44 SWAP state and MODFLOW model exactly as the existing E2E test does.

## Measurements

Per arm and cycle record:

- PASS/FAIL;
- process return code;
- status-6 diagnostic when present;
- successful endpoint identity markers when available.

Final summary:

- exact pass/fail count;
- A2C pass/fail count.

## Interpretation

If either arm fails within one fixed build, the issue is runtime/state nondeterminism and not merely independent-build variation.

If both arms pass 20/20 from one fixed build, the preceding mixed independent-job failures are localized to build/job/environment sensitivity rather than ordinary repeated execution of a fixed binary.

This experiment does not modify production code or numerical settings.
