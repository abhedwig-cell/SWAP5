# A23BR timestep ownership contract

## Status

`PASS_TIMESTEP_OWNERSHIP_SPLIT / LEGACY_GLOBAL_DT_BACKEND_PROJECTION_REMAINS / PHYSICAL_BACKEND_SERIAL_ONLY`

## Ownership

### Persistent numerical column state

`hupsel_column_state_t%numerical%dt` is the authoritative continuation value for the next legacy Richards step. It is cloned with the transactional checkpoint, restored before every trial and captured again after a successful physical advance.

The B1.6 backend still exposes `variables%dt` internally to 21 legacy source files. In A23BR that global is an adapter projection of the committed/trial column numerical state, not the ownership location of the new architecture.

### Worker-derived timestep control

The former singleton `variables%fldtmin` is removed. Its active meaning is represented by `worker%control%at_min_dt`.

At the start of every trial the adapter derives this flag from the restored `dt` and immutable `dtmin` using the same legacy threshold:

`at_min_dt = dt <= (1 + 1e-8) * dtmin`

`reset_attempt_control()` clears `last_numbit` and `request_dt_reduction` but deliberately preserves `at_min_dt`. Thus `SWAP(iTask=21)` cannot erase the timestep state derived from the committed column checkpoint.

### Local orchestration control

The former singleton `variables%fldtreduce` is removed. It is replaced by the local logical `repeat_current_step` in the dynamic SWAP execution call. It has no lifetime outside the retry loop and therefore belongs neither to column state nor worker persistent state.

## Transaction semantics

For every A23BL reference trial:

1. clone committed column state;
2. restore physical/process/forcing/numerical column state, including `dt`;
3. seed worker timestep control from restored `dt` and configured `dtmin`;
4. reset attempt-only solver controls;
5. execute B1.6 physical advance;
6. capture resulting `dt` back into trial column state;
7. discard rejected trial state or commit the accepted two-half endpoint.

Rejected trials cannot change the committed `dt`.

## Qualification boundary

A23BR does **not** remove the legacy global `dt` from all B1.6 physics/process routines. There are 531 active `dt` references in 21 transformed legacy files. Removing those requires a wider API change and is intentionally deferred.

A23BR removes only the hidden singleton ownership of `fldtmin` and `fldtreduce`, while making the already explicit per-column `dt` contract dynamically enforceable.

## Invariants

- Invariant 3: numerical continuation state is separated from physical/process state.
- Invariant 4: only one 8-byte `dt` is retained per logical Hupsel column; no duplicate `fldtmin`/`fldtreduce` persistent state is added.
- Invariant 5: derived minimum-timestep control is worker-owned; retry-loop control is stack/local.
- Invariant 7/8: trial restore seeds timestep control from the committed checkpoint, preventing retry contamination.
- Invariant 13: hard B1.6 mass gate unchanged.
- Invariant 23: ownership changed; timestep policy and physical equations did not.
- Invariant 30: exact B1.6 parent, deterministic source transform, O0/O2 physical regression, transaction regression and worker isolation are retained.
