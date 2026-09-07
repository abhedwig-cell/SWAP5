# F-CI07 Qualification — Worker-local legacy trial capsule and state classification

## Outcome

**PASS_WORKER_LOCAL_LEGACY_ROLLBACK_CAPSULE_PHYSICAL_CONTINUATION_BLOCKED**

F-CI07 closes one specific rollback gap left by F-CI06: legacy time/control, forcing cursors, irrigation event workspace and water-accounting accumulators may mutate during a physical trial even though they are not canonical physical continuation state.

The solution is deliberately **not** to add these values to every persistent MultiSWAP column. `b1_10_legacy_trial_capsule_t` is adapter-owned, worker/job-local rollback storage and does not extend `canonical_state_t` or `transaction_state_t`.

## Capsule coverage

The capsule captures/restores:

- numerical/retry state: `dt`, `dtold`, `fldecdt`, `fldtmin`, `fldtreduce`;
- legacy calendar/time projection and day-event flags;
- reporting progress/reset flags;
- meteo/rain forcing cursors;
- irrigation event workspace and the current `dayfix`/`nirri` continuation cursors;
- all intermediate and cumulative water-accounting accumulators from `MOD_integral`, including drainage arrays.

Large arrays are allocatable and therefore cost memory only for active capsules/workers. For the legacy standalone maxima the broad rollback payload can be several MiB, which is acceptable only because it is worker-local rather than multiplied by all logical columns; a MultiSWAP execution class has much smaller compile-time array maxima.

`dayfix` and `nirri` are copied into the capsule for rollback, but this does not settle their final ownership: when irrigation is active they remain candidates for optional persistent process-continuation state.

## Source-bound local qualification

The module was compiled directly against the exact F-CI06 post-port source built from the qualified B1.10 tree under both GNU `-O0` and `-O2`.

A poison/restore test set representative numerical, calendar, reporting, forcing, irrigation, intermediate-accounting, cumulative-accounting and array values; captured the capsule; deliberately corrupted the backing legacy globals; restored the capsule; and verified the original values. Both optimization levels produced:

`FCI07_LEGACY_TRIAL_CAPSULE PASS`

The `-O0` and `-O2` gate logs were identical.

This proves that the new adapter compiles against the real B1.10/F-CI06 module declarations and that the qualified categories can be restored exactly. It is stronger than a stub-only compile, but it is **not** yet a full rejected-SWAP-trial qualification because crop/WOFOST, thermal and solute physical continuation state are not yet fully captured.

## Canonical CI evidence

Canonical workflow run `34085527859` completed the chained qualification successfully:

- F-CI03 transaction substrate — PASS
- F-CI04 canonical runtime — PASS
- F-CI05 B1.10 physical preimage — PASS
- F-CI06 controlled source port/checkpoint — PASS
- F-CI07 worker-local legacy trial capsule — PASS

The F-CI07 CI job compiled and ran the architecture + poison/restore gate at `-O0` and `-O2` and required identical gate logs.

## Repository gate

`tools/fci/fci07_legacy_trial_capsule_gate.py` is fail-closed on the architecture boundary. It verifies, among other things, that the capsule:

- is neither canonical persistent state nor transaction state;
- performs no file I/O;
- contains forcing/time/numerical/irrigation/accounting rollback categories;
- uses allocatable storage for large arrays;
- does not silently absorb `h`, `theta`, `tsoil`, `cml` or `cmsy` as capsule payload.

`tests/fci/run_fci07_gate.sh` compiles and runs the poison/restore contract at `-O0` and `-O2` using deterministic legacy-module stubs. The canonical workflow chains this after F-CI03 through F-CI06.

## Invariant assessment

F-CI07 strengthens invariants 3, 4, 5, 7, 16 and 27 by separating rollback-only legacy bookkeeping from compact persistent column state and allocating the broad rollback payload per active worker rather than per logical column. It also protects invariant 13 by including both intermediate and cumulative water-accounting state in rollback coverage.

No physical formula, solver policy, mass tolerance or time discretization policy is changed.

## Explicit holds

F-CI07 does **not** admit the full physical transaction adapter. Remaining blockers are:

- complete crop/WOFOST continuation state;
- thermal continuation (`tsoil`) ownership;
- solute continuation (`cml`, `cmsy`) ownership and replay semantics;
- final optional persistent irrigation process state (`dayfix`, `nirri`);
- source-bound rejected-trial -> restore -> rerun qualification with all active Hupsel physics;
- generic physical sub-day execution;
- complete accepted unrounded interval mass output;
- reentrant/parallel legacy backend removal or containment.

The next state-integration step must resolve these physical/process categories rather than expanding the worker capsule indiscriminately.
