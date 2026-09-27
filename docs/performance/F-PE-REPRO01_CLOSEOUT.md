# F-PE-REPRO01 closeout — live coupled exact-route nondeterminism

Date: 2026-09-26

Status: `CLOSED_ROOT_CAUSE_LOCALIZED`

PR:
`#633 — F-PE-REPRO01: live coupled exact-route nondeterminism`

Branch:
`work/f-pe-repro01-live-coupling-nondeterminism`

Parent:
`F-PE-PROFILE05`

## Trigger

PROFILE05 found process-to-process status-6 failures in the live FGC44 route even when exact/default was used.

A fixed-build test produced:

- exact: 12/20 PASS, 8/20 FAIL;
- A2C: 16/20 PASS, 4/20 FAIL.

The same first-corrector failure class occurred in both arms.

## Isolation

REPRO01 removed unrelated components step by step.

Key findings:

- failure can occur without MODFLOW/XMI;
- failure occurs on the exact/default first corrector trial;
- successful and failing processes have identical reported HCOF, RHS, href and boundary flux inputs;
- the failing solver path enters `SW_SOLVE_RETRY_ADVISED` after 16 nonlinear iterations, 108 backtracking attempts and one internal retry;
- OpenMP controls did not reproduce a systematic effect;
- compiler zero-init and sNaN/check modes did not establish a generic local-variable initialization cause.

## Memory evidence

Valgrind reported conditional use of uninitialized heap values originating from Reference workspace allocation on the accepted-direction path.

A deliberate full workspace poison reproduced the spontaneous failure signature deterministically.

## Scratch-family localization

D7:

- ZERO: 40/40 PASS;
- DFDH: 40/40 PASS;
- RESIDUAL_DELTA: 40/40 PASS;
- SOURCE_SINK: 40/40 PASS;
- PROVIDER: 0/40 PASS;
- DCON_OLD: 40/40 PASS;
- FLUX_GRAD: 40/40 PASS;
- BAND: 40/40 PASS.

D8 split PROVIDER:

- THETA: 40/40 PASS;
- K: 40/40 PASS;
- CAPACITY: 40/40 PASS;
- DKDH: 40/40 PASS;
- ROOT_SINK: 0/40 PASS.

## Root cause

Mode-5 qbot materialization unconditionally executes:

`qrosum = sum(richards%provider_root_sink(1:n))`

even when `request%evaluation%root_sink` is not associated.

In the root-inactive route, `provider_root_sink` is non-authoritative worker scratch and is not required to have been written.

This is a read-before-write ownership defect.

## Causal falsification

D9 used a deliberately NaN-poisoned `provider_root_sink` vector.

Results:

- clean original: 100/100 PASS;
- original code + ROOT_SINK poison: 0/100 PASS;
- conditional inactive-root qrosum + same ROOT_SINK poison: 100/100 PASS.

The test-only conditional materialization changed only:

- associated root-sink provider -> sum authoritative root-sink scratch;
- inactive root route -> `qrosum=0`.

This restored the clean physical/solver outcome while retaining the poison.

## Decision

Root cause is localized sufficiently for production repair.

REPRO01 remains diagnostic-only and makes no `src/**` changes.

The next workunit must implement the minimal ownership-correct repair and requalify:

1. deterministic poisoned-workspace regression;
2. exact mode-5 first-corrector repeatability;
3. live exact SWAP + MODFLOW6 repeatability;
4. A1 preservation;
5. A2C coupled reproducibility;
6. application-shaped mass and endpoint preservation.

Performance claims blocked by PROFILE05 may resume only after that repair is qualified.
