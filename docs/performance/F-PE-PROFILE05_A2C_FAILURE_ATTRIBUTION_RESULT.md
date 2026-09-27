# F-PE-PROFILE05 A2C failure-arm attribution result

Date: 2026-09-26

Status: `BOTH_ARMS_6_OF_6_PASS_PRECEDING_FAILURES_UNATTRIBUTED`

## Purpose

Resolve whether the mixed 4/6 exact-vs-A2C reproducibility result could be attributed specifically to A2C.

The attribution harness changed only shell-level provenance and failure capture. Production source and numerical settings were unchanged.

## Result

Six independent attribution replicas completed.

All six reported:

- exact: `PASS`;
- A2C: `PASS`.

Thus:

- exact passed 6/6;
- A2C passed 6/6;
- no status-6 failure occurred in the attribution set.

For every replica the completed exact and A2C arms had identical:

- final MODFLOW groundwater head;
- final SWAP groundwater exchange flux;
- cumulative accepted interface ledger exchange;
- coupled iteration count.

## Coupled-loop timings

A2C speedups in the six attribution replicas were approximately:

- 2.09%;
- 3.82%;
- 0.11%;
- 2.65%;
- 6.37%;
- 1.27%.

Median:

approximately `2.37%`.

Mean:

approximately `2.72%`.

The loop is sub-millisecond and the spread is treated as timing variance. These timings do not supersede the larger application-shaped A2C result.

## Interpretation

The preceding mixed reproducibility run produced 4 successes and 2 status-6 failures, but did not identify the failing arm.

The attribution run then produced 6/6 exact successes and 6/6 A2C successes.

Therefore the evidence does **not** support the claim that A2C itself is the owner of the failure.

It also does not permit the earlier failures to be ignored.

Production source was identical across the successful APPROX02 qualification and PROFILE05 observations. The remaining issue is run-to-run reproducibility of the live coupled test/runtime environment or a latent execution-state sensitivity that is not exposed by source comparison.

## Decision

Do not withdraw A2C solely on the mixed 4/6 result.

Do not form the final A1+A2C production-stack performance claim yet.

The next observation must separate:

- repeated executions of one fixed compile/postimage;
- from independently rebuilt CI jobs.

If repeated execution from one fixed build is stable while independently built jobs remain mixed, investigation moves to build/runtime-layout or environment sensitivity.

If one fixed build itself produces intermittent exact or A2C failure, investigation moves to runtime-state nondeterminism.

Exact default remains authority and A2C remains default OFF.
