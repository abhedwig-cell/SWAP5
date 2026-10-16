# F-MIG431-LOW03-A-DEP01 preregistration

Status: centrally registered shared prerequisite for the already issued F-MIG431-LOW03-A ordinary implicit Cauchy application. This record precedes any DEP01 production-source change.

## Trigger and falsification

F-MIG431-LOW03-A qualification on its official branch reached the canonical transaction layer but never called Richards. Persisted run 36976190316 at postimage `f5b29383fd523c5dcbc56e8774141e5ea5f79dc2` established:

- frozen corrected-B1.11 source oracles: PASS;
- typed Cauchy provider compile/run: PASS;
- application admission: `ADMITTED`;
- direct transaction diagnostics: three attempts, two retries, three solver rejections, zero mass and zero temporal rejections;
- LOW03-A proposal carrier: available with the expected interval, Haq and Q4;
- solver observation: `solver_executed=F`, route `not-run`.

The cause is current canonical `src/adapter/mod_b110_serialized_context_binding.f90`. Its legacy-context guard admits only bottom modes 7, internal -2, 5 and 2, therefore returning `ok=.false.` for typed mode 3 before the Reference Richards solver is entered.

This is a real shared-authority prerequisite. The closed F-MIG431-LOW03-P0-DEP01 explicitly held "No new application mode3 allowlist" fixed. LOW03-P0 admits the typed mode-3 Reference solver while continuing to declare serialized application mode 3 closed. This prerequisite therefore does not reopen the accepted P0 dependency closure.

## Baseline and ownership

- Canonical baseline: `3869ec27a7314375fd7919debb6abe7c6450f261`.
- Parent work unit: `F-MIG431-LOW03-A`.
- Official branch: `work/f-mig431-low03-a-dep01-serialized-context-mode3`.
- Owning authority: central F-MIG431 lower-boundary migration regie.
- Scientific authority: SWAP 4.3.1 B1.11 corrected reference.
- Typed mode-3 physics authority: canonically admitted LOW03-P0.
- Existing transaction, mass, restart and groundwater owners remain unchanged.

## Authorized delta

The sole production-source semantic delta is to let `bind_b110_serialized_legacy_context` mirror an already validated typed `bottom_mode=3` request into the legacy Reference call context.

The allowed-mode guard changes from `7, -2, 5, 2` to `7, -2, 5, 2, 3`.

No mode-3 physics is added here. This prerequisite does not own or reconstruct RIMLAY, aquifer head, Q4, GWL, saturated-profile resistance, MODFLOW datum conversion, groundwater storage or application history. Those remain explicit typed request/application authorities.

## Held fixed

- LOW03-P0 residual/Jacobian and common typed boundary contract;
- SWKIMPL=1 rejection;
- modes 2/internal -2, 5 and 7 context semantics;
- RossFast mode-3 rejection;
- unsupported selectors do not become application-admitted;
- no public C ABI, groundwater owner, ledger owner, transaction policy or restart-format change;
- no weakening or successor allowlisting of the historical LOW03-P0-DEP01 hash guard.

## Required qualification

Before canonical admission this prerequisite must prove on the exact persisted postimage:

1. mode 3 with SWKIMPL0 and a valid legacy grid mirrors `dt/swbotb/swkimpl/swkmean/qtop/qbot/hbot` exactly;
2. modes 2, internal -2, 5 and 7 remain valid, while unsupported selectors and SWKIMPL1 mode 3 remain fail-closed;
3. LOW03-P0 direct solver qualification remains green;
4. current-canonical versus candidate semantic preservation for existing RossFast/default shared bindings, including the existing RossFast mode-3 rejection;
5. no unrelated application owner acquires mode 3;
6. exact source, runner and tested-postimage hashes plus O0/O2 evidence are persisted.

Only after this prerequisite is canonical admitted may LOW03-A reconcile it and resume application qualification.

## Claim ceiling

Admission establishes only that serialized Reference context can carry an already validated typed mode-3 request to the solver. It does not admit ordinary SWBOTB=3 application by itself. Explicit `SwBotb3Impl=0` remains open, SWBOTB=1 remains parked and SWBOTB=8 remains open.
