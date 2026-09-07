# F-CI07 Qualification — Worker-local legacy trial capsule and whole-day physical rollback

## Outcome

**PASS_WORKER_LOCAL_LEGACY_ROLLBACK_CAPSULE_HUPSEL_WHOLE_DAY_RERUN**

F-CI07 closes the rollback gap left after F-CI06 without making broad legacy bookkeeping persistent per-column state. `b1_10_legacy_trial_capsule_t` remains adapter/worker-local and does not extend `canonical_state_t` or `transaction_state_t`.

The strengthened capsule covers:

- legacy numerical retry state;
- calendar/reporting projection and forcing cursors;
- irrigation continuation and event workspace;
- intermediate and cumulative water-accounting accumulators;
- water-balance baseline state (`volini`, `pondini`, intermediate-period baselines and `ithetabeg`);
- day accumulators consumed by crop/root processes (`inqpotrot_day`, `inqredrot_day`, `iqrot_day`, `iptra_day`, `ialpwet_day`, `ialpdry_day`).

These categories are rollback data for the serialized legacy physical trial path, not canonical physical continuation state.

## Local source-bound qualification

The strengthened capsule passed static and poison/restore gates under GNU Fortran at both `-O0` and `-O2`, and compiled against the exact B1.10/F-CI06 module interfaces at both optimization levels.

A source-bound physical rerun probe was executed on exact reconstructed B1.10 plus the F-CI06 four-file source port. Two whole-day Hupsel cases were used:

1. **2002-01-05** — configured fixed-irrigation event day;
2. **2003-05-15** — detailed potato crop active, five days after emergence.

For each case the sequence was: advance to the committed state immediately before the probe day -> capture physical state and worker-local capsule -> run -> restore -> reset worker scratch -> rerun the same day. The measured maximum absolute differences were all zero for `h`, `theta`, `tsoil`, `cml`, `cmsy` and the selected water-accounting totals.

The reproducible evidence is retained in:

- `tests/fci/test_fci07_b1_10_physical_rerun.f90`;
- `tests/fci/run_fci07_full_b1_10_gate.sh`.

The full-source runner requires an exact reconstructed B1.10 source tree, TTUTIL and the Hupsel qualification case; these external qualified inputs are deliberately not fabricated inside ordinary GitHub CI.

## Canonical CI evidence

Canonical workflow run **34086427010** completed with conclusion **success** for the strengthened source/test postimage. The complete chained gate passed:

- F-CI03 transaction substrate — PASS;
- F-CI04 canonical runtime — PASS;
- F-CI05 B1.10 physical preimage — PASS;
- F-CI06 controlled B1.10 source port — PASS;
- F-CI07 worker-local legacy trial capsule — PASS.

The final status/qualification commits after that run modify only administrative evidence; they do not change the qualified production or test postimage.

## Admission boundary

F-CI07 admits the worker-local legacy rollback capsule and the **whole-day Hupsel physical restore/rerun path**. It does **not** admit generic subday physical execution, every optional SWAP process configuration, complete unrounded interval mass output, parallel reentrancy of the legacy backend, or B2 reference status.

## Invariants

The change advances explicit data ownership and compact persistent state (3–5), rejected-trial isolation (7), MultiSWAP scaling (16) and pay-for-use optional storage (27). No physical formula or numerical policy changed (23), and mass conservation remains a hard requirement (13). Generic time remains the canonical contract, while the present legacy physical bridge is explicitly whole-day limited rather than silently assuming generic support (9, 29).
