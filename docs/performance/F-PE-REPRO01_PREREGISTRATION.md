# F-PE-REPRO01 — live coupled exact-route status-6 nondeterminism

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC`

Parent:
`F-PE-PROFILE05`

## Trigger

PROFILE05 fixed-build repeatability compiled one exact binary and one A2C binary once, then executed each in 20 fresh live SWAP + MODFLOW6 processes.

Observed:

- exact: 12/20 PASS, 8/20 FAIL;
- A2C: 16/20 PASS, 4/20 FAIL;
- every failure: first SWAP corrector trial returns participant status `6 (TRIAL_FAILED)`.

Because exact itself fails intermittently, the blocker is not attributed to A2C.

## Purpose

Identify the first deterministic state divergence between a passing and failing exact/default live coupled process.

This workunit is diagnostic first.

Do not optimize performance.

Do not change practical-mode tolerances.

Do not use A2C as the primary route until exact-route repeatability is understood.

## Initial hypotheses

Test, do not assume, whether status 6 is associated with:

1. uninitialized or undefined process state;
2. stale transaction/candidate state;
3. uninitialized solver workspace or legacy module storage;
4. OpenMP/runtime-layout sensitivity;
5. initialization-order dependence;
6. non-deterministic temporary path or external MODFLOW/XMI state;
7. floating-point threshold crossing caused by undefined prior values.

## Phase D1 — exact pre-trial provenance

Run exact/default only.

Compile once and execute fresh processes repeatedly.

Before the first corrector trial record deterministic diagnostics for:

- prescribed interface head;
- captured origin lineage/revision/time;
- corrector window t0/t1;
- physical parameter set id and active-node count;
- relevant numerical controls;
- committed pressure-head vector;
- committed water-content vector;
- forcing top flux, bottom head and bottom flux carrier values;
- temporal-history availability and predecessor derivative;
- participant live-candidate state;
- backend observation before and after trial where available;
- returned participant status;
- solver status/diagnostics when trial fails.

No production state may be mutated solely for observation.

## Phase D2 — runtime controls

Only after D1 establishes a stable diagnostic signature, compare exact fixed-build repetitions under controlled runtime environments:

- default runner environment;
- `OMP_NUM_THREADS=1`;
- `OMP_DYNAMIC=FALSE`;
- `OMP_PROC_BIND=TRUE` where applicable.

These are diagnostic environment controls, not production recommendations.

## Phase D3 — initialization sensitivity

If D1/D2 do not isolate the cause, vary only initialization order in a dedicated test harness and compare state snapshots before the first corrector trial.

## Admission / repair rule

REPRO01 itself does not admit a production repair.

If a concrete defect is localized, open a separate repair workunit with:

- exact failing fixture;
- deterministic regression test;
- minimal ownership-correct fix;
- exact-route and coupled requalification.

## Closure

REPRO01 closes only when either:

1. a deterministic root cause is localized sufficiently to preregister a repair workunit; or
2. a genuine external/runtime blocker is demonstrated with bounded evidence and exact next requirements.
