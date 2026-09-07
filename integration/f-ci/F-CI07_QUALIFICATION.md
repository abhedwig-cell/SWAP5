# F-CI07 Qualification — Worker-local legacy trial capsule and whole-day physical rollback

## Current outcome

**MATERIALIZED_CI_PENDING** for the strengthened postimage.

The earlier F-CI07 capsule already qualified worker-local rollback of legacy time/control, forcing cursors, irrigation workspace and water accounting. The strengthened postimage adds two classes that matter when a rejected trial crosses reporting or crop-process boundaries:

- water-balance baseline state (`volini`, `pondini`, intermediate-period baselines and `ithetabeg`);
- day accumulators used by crop/root processes (`inqpotrot_day`, `inqredrot_day`, `iqrot_day`, `iptra_day`, `ialpwet_day`, `ialpdry_day`).

These values remain adapter/worker rollback data. They are not added to persistent `canonical_state_t` or `transaction_state_t`.

## Local qualification

The strengthened capsule passed static and poison/restore unit gates under GNU Fortran at both `-O0` and `-O2`. It also compiled against the exact B1.10/F-CI06 module interfaces at both optimization levels.

A source-bound physical rerun probe was then executed on exact reconstructed B1.10 plus the F-CI06 four-file source port. Two whole-day Hupsel cases were used:

1. **2002-01-05** — configured fixed-irrigation event day;
2. **2003-05-15** — detailed potato crop active, five days after emergence.

For each case: advance to the committed state immediately before the probe day -> capture physical state and worker-local capsule -> run -> restore -> reset worker scratch -> rerun. The measured maximum absolute differences between the two accepted outcomes were all zero for:

- `h`;
- `theta`;
- `tsoil`;
- `cml`;
- `cmsy`;
- selected water-accounting totals.

The test source and a full-source runner are retained in `tests/fci/` so this evidence is reproducible wherever the exact B1.10 tree, TTUTIL and Hupsel qualification case are available.

## Admission boundary

If current canonical CI passes, F-CI07 admits the worker-local legacy rollback capsule and the **whole-day Hupsel physical restore/rerun path**. It does not admit generic subday physical execution, every optional process configuration, complete unrounded interval mass output, parallel reentrancy of the legacy backend, or B2 reference status.

## Invariants

The change advances explicit data ownership and compact persistent state (3–5), rejected-trial isolation (7), MultiSWAP scaling (16) and pay-for-use optional storage (27). No physical formula or numerical policy changes (23) and mass conservation remains a hard requirement (13). Generic time remains a canonical requirement, but the current legacy physical bridge is still explicitly whole-day limited (9, 29).
