# F-PE-PROFILE05_CLOSEOUT — combined practical-stack performance rebaseline

Date: 2026-09-26

Status: `CLOSED_BLOCKED_BY_LIVE_COUPLING_NONDETERMINISM`

PR:
`#632 — F-PE-PROFILE05: combined practical-stack performance rebaseline`

Branch:
`work/f-pe-profile05-practical-stack-rebaseline`

Parent:
`F-PE-APPROX03`

## Purpose

PROFILE05 was opened as an observation-only rebaseline after the retained practical modes:

- A1 — bounded same-origin tangent cache;
- A2C — strict-practical Richards convergence envelope.

No `src/**` change belongs to PROFILE05.

The intended primary result was a same-postimage A1+A2C live SWAP + MODFLOW6 performance measurement.

## Stable observations

### Production-shaped application sequence

A2C remained speed-positive in the deterministic application-shaped sequence.

One current-head observation measured approximately:

`23.18%`

speedup while preserving:

- accepted substeps;
- retries;
- canonical mass residual;
- cumulative net flow;
- cumulative storage;
- maximum step-net accounting.

The fixture reported 60 nonlinear iterations in both arms, so this speedup is not interpreted as a simple nonlinear-iteration ratio.

### Repeated application decomposition

The current postimage retained the PROFILE04 structure:

- application runtime at N=10000: approximately `9176 ns/column`;
- Reference backend: approximately `8579 ns/column`;
- Reference backend share: approximately `93.49%`;
- residual application/wrapper share: approximately `6.51%`.

The directional backend remained materially more expensive than plain Reference in the exact repeated decomposition.

### A1 live control

A successful current-head A1 control reproduced:

- exact final MODFLOW head;
- exact final SWAP groundwater exchange;
- exact cumulative interface ledger exchange;
- identical coupled iteration count;
- one fresh tangent and three tangent reuses.

One observed coupled-loop speedup was approximately `3.59%`.

This short-loop timing is descriptive only.

## Live coupled reproducibility finding

The intended combined-stack timing exposed a more fundamental issue.

### Initial observations

The inherited exact-vs-A2C live runner produced a mixed six-replica result:

- 4 completed;
- 2 failed with SWAP corrector status `6 (TRIAL_FAILED)`.

Production source was unchanged relative to the successful APPROX02 A2C qualification source head.

### Explicit arm attribution

A separate six-replica runner then executed exact and A2C independently and reported:

- exact: 6/6 PASS;
- A2C: 6/6 PASS.

Completed endpoints were identical.

Median A2C coupled-loop speedup in that attribution set was approximately `2.37%`.

This showed that the preceding failures could not be assigned to A2C from the available evidence.

### Fixed-build repeatability

The decisive test compiled exact and A2C once and executed each binary 20 times in fresh processes.

Result:

- exact: 12/20 PASS, 8/20 FAIL;
- A2C: 16/20 PASS, 4/20 FAIL.

Every failure was the same first-corrector status:

`6 (TRIAL_FAILED)`.

Therefore the live FGC44 route is process-to-process nondeterministic even with one fixed compiled binary.

This is not an A2C-specific failure.

## Consequence for PROFILE05

The live FGC44 fixture cannot currently serve as authority for an A1+A2C end-to-end performance claim.

Successful sub-millisecond timing samples cannot override the fact that nominally identical fresh processes sometimes fail before producing an endpoint.

PROFILE05 therefore does not publish or admit a combined A1+A2C coupled speedup.

This is a measurement-blocking numerical/runtime reproducibility issue, not evidence that A1 or A2C should be tuned differently.

## Practical-mode status

- A1 remains independently qualified and default OFF.
- A2C remains default OFF.
- PROFILE05 does not withdraw A2C solely because the exact route shares the same nondeterministic failure.
- no temporal A3 mode exists after APPROX03.
- no combined A1+A2C production-stack claim is admitted by PROFILE05.

## PROFILE05 decision

PROFILE05 closes as an observation-only workunit with a genuine blocker:

`FGC44 live exact-route process repeatability`.

Further performance optimization is premature until this blocker is isolated, because coupled end-to-end timing is not currently reproducible enough to act as authority.

## Required next workunit

Open a separate reproducibility workunit whose first authority is the exact/default route.

It must determine whether status 6 originates from:

- uninitialized or stale process state;
- undefined memory/state;
- solver or transaction state not reset between initialization paths;
- environment-sensitive parallel/runtime behavior;
- or another deterministic boundary condition that is not yet explicitly controlled.

Only after exact-route repeatability is restored should practical-stack end-to-end timing resume.
