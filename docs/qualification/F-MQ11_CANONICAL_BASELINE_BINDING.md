# F-MQ11 — Canonical baseline binding after qualified F-CI exit

## Purpose

F-MQ11 resumes the MultiSWAP qualification workstream after the F-CI canonical integration line reached a qualified exit. This work unit is qualification-only: it does not change production source, solver physics, numerical policy, or a production MultiSWAP runtime.

The goal is to replace the earlier provisional `F-CI/F-KT` dependency labels in F-MQ with exact bindings to the final F-CI canonical source postimage and to make the remaining ownership explicit without upgrading any real-physics or production-runtime claim.

## Exact lineage

- F-MQ parent: `qualification/f-mq10-fci11-fixture-admission` at `831110d0c6f1838e3583391b5e9266a2f5f95ebb`.
- F-CI canonical closeout: `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab` (`F-CI18`).
- F-CI development-baseline exit head: `1eceed967b12396b8bbc832f897376378463adce`.
- Qualified production-source head: `da5026d8b87ad2f3c7912360891839a120ecccb6`.
- Corrected legacy oracle: B1.10.
- F-VQ07 final F-CI handoff branch: `qualification/f-vq07-final-fci-exit` at `4ae2fc87970d46ff2103553930e583dd05a59f0b`.

F-CI18 records `QUALIFIED_EXIT`, all required gates qualified, downstream release allowed, and no remaining F-CI blockers. F-VQ07 admits the final F-CI development baseline for downstream qualification, but explicitly keeps canonical real-reference execution fail-closed.

## Canonical contract findings

The final canonical source now provides stable prerequisites that F-MQ can bind to directly:

1. `mod_transaction_reference` defines the cloneable transaction state, nonpersistent attempt context, trial outcome, transaction model, policy and transaction result.
2. `mod_canonical_contracts` separates canonical state, forcing, interval `[t0,t1]`, numerical configuration, mass accounting, diagnostics and results.
3. `mod_canonical_interval_runtime` clones externally committed state, performs accepted work only on a private working copy, and moves the working state into the externally committed state only after the full requested interval completes.
4. `mod_b1_10_process_checkpoint` provides a B1.10 process continuation state and allocates thermal, solute, irrigation and crop/WOFOST state only when those options are active in the covered legacy profile.
5. The canonical diagnostics contract exposes transaction, retry, rollback, solver and numerical-work counters required by F-MQ diagnostics qualification.

These findings materially remove F-CI as a blocker for the corresponding *interfaces and transaction prerequisites*.

## Deliberate fail-closed boundaries

F-MQ11 does **not** claim that the final baseline makes real-physics MultiSWAP qualification executable.

Two source-level boundaries are especially important:

- `mod_canonical_interval_runtime` still sets `result%mass%complete = .false.` on successful completion. The canonical mass result type therefore exists, but that generic runtime does not yet expose an F-MQ03-complete accepted-interval mass record.
- `mod_b1_10_reference_model` / the reference-policy candidate keep `reference_execution_admitted` fail-closed until the required reference numerical profile is independently qualified. F-VQ07 likewise records `canonical_reference_admission = BLOCKED_FAIL_CLOSED`.

Therefore P10/P11 deterministic real checkpoint/recompute qualification and P16/P17 real hard-mass qualification are **not** promoted in F-MQ11.

## 35-row binding overlay

`tests/multiswap/fmq11_canonical_binding.json` preserves all 35 F-MQ01 requirement IDs and assigns each one a current canonical binding plus the remaining workstream owner(s).

The principal ownership change is that F-CI is no longer retained as a remaining blocker after its qualified exit. Open work is assigned to the appropriate active/downstream workstreams:

- F-VQ: admitted real scientific/reference execution and event-local physical evidence;
- F-KT: continuing kernel/state/transaction contract hardening where required;
- F-SI: solver scratch ownership, reentrancy and worker isolation;
- F-MR: production MultiSWAP scheduler, batching, aggregation, tiles and coupling runtime;
- MP/F-MR: the performance-only lane.

This is an ownership/binding change, not a qualification promotion.

## Coverage result

Coverage remains unchanged:

- synthetic executable: **27 / 35**;
- real physics executable: **0 / 35**;
- production runtime qualified: **0 / 35**.

This is intentional. F-MQ11 prevents a qualified F-CI development baseline from being mistaken for a qualified real-reference route or a qualified production MultiSWAP runtime.

## Architecture invariant check

F-MQ11 reinforces invariants 1, 3, 4, 5, 7, 8, 9, 13, 16, 23, 26, 27, 29 and 30. In particular:

- one canonical transaction/kernel contract is reused rather than copied into MultiSWAP;
- state, forcing, numerical configuration and result data remain explicit;
- rejected/trial work cannot directly replace externally committed state;
- worker attempt context is kept outside persistent state;
- time remains generic `[t0,t1]`;
- mass completeness is fail-closed instead of inferred;
- no performance/runtime policy is allowed to silently qualify physics.

## Gate

The focused repository gate is:

```text
python3 tests/multiswap/run_fmq11_gate.py
```

It checks exact lineage and source-blob pins, preservation of all 35 requirement IDs, removal of F-CI as a remaining blocker, canonical prerequisite bindings, fail-closed mass/reference boundaries, explicit downstream ownership and zero coverage promotion.

## Next qualification step

F-MQ12 should only promote a row when a downstream workstream supplies executable evidence. The highest-value triggers are:

1. F-VQ admits a real B1.10/canonical event-local reference record -> exercise P10, P11 and P16;
2. F-SI exposes qualified scratch/reentrancy seams -> exercise real P06/P18/P19;
3. F-MR exposes the production MultiSWAP runtime -> bind R01-R08 and production P01-P04/P09/P13/P15/P17/P20-P22.

Until one of those occurs, F-MQ should keep the current real/production coverage fail-closed.
