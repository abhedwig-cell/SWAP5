# PPA-WU05-A2 implementation and reconciliation result

Date: 2026-09-30

Status: `IMPLEMENTED / CURRENT-CANONICAL-RECONCILED / QUALIFICATION_QUEUED`

Current head: `ac998d39f2be304b24fbfbdab871983a4fc142b4`

Reconciled canonical parent: `f9133b92cd7d128838029a162ee607bb8ba69689`

## Implemented

A2 introduces no active macropore equations. It adds the source-bound continuation-state ownership surface established by A1:

- `ICpBtDm`;
- `SorpDmCp`;
- `ThtSrpRefDmCp`;
- `TimAbsCumDmCp`;
- `VlMpDmCp`;
- `WaUnMpDmCp`;
- `VlMpDyCp`.

The seven fields are represented by active-sized `macropore_continuation_state_t`.

The DTO provides:

- explicit active domain/node shape;
- deterministic zero initialization;
- clear/release semantics;
- deep copy;
- exact bitwise state equality for real-valued continuation fields;
- payload-byte accounting.

## Runtime ownership integration

The state is bound into the existing SWAP5 transaction/persistence architecture rather than introducing a parallel transaction system.

Changes include:

- `FMR_OPTIONAL_STATE_LAYOUT_MACROPORE = 505001`;
- an allocatable macropore continuation component in `fmr_b110_physical_state_t`;
- deep-copy propagation through the existing physical-state clone;
- restart topology recognition in `mod_fmr_restart_state_contract`;
- mutual exclusion with Snow and restricted soil-temperature optional state under the first A2 topology contract.

No active macropore physical evaluation is enabled.

## Candidate / reject / retry / accept harness

`tests/fpm/test_ppa_wu05a2_macropore_state.f90` exercises:

1. accepted-state initialization;
2. candidate deep clone;
3. independent mutation of every one of the seven continuation fields;
4. proof that accepted state remains unchanged;
5. candidate discard;
6. retry reconstruction from accepted state with no rejected history;
7. atomic seven-field accepted-state replacement;
8. serialization-neutral restart deep-copy round trip;
9. post-restore independence.

The harness is configured for O0/O2 exact-output comparison.

## Integrated compile dependency

Because `mod_fmr_serialized_reference_backend` now owns the optional DTO, the existing F-KT22 current FMR compile gate was extended only by inserting:

`src/runtime/mod_macropore_continuation_state.f90`

before the backend compile.

The A2 qualification runner now executes that FMR compile gate in addition to the focused DTO transaction/restart harness.

## Current-canonical reconciliation

The A2 branch originally diverged from canonical at `68fcf6d3...`.

Canonical advanced through MULTI06/SCHED01 to:

`f9133b92cd7d128838029a162ee607bb8ba69689`.

The intervening canonical delta changes the parallel worker-pool/performance evidence surface and does not overlap the A2 production source files.

A true two-parent reconciliation commit was created at `6314698056ff76d4031b91a3fc0c40aa89683bee`, using current canonical as first parent. The A2 branch thereafter reports zero commits behind canonical.

Subsequent A2 compile-hygiene fixes preserve that reconciled ancestry.

## Gate history

Two early A2 runs failed before qualification:

- run 36759204610: strict compiler rejected floating-point `==` in an exact state helper;
- run 36759330085: strict compiler identified an impure helper in a short-circuit logical expression.

Both were compile-hygiene issues. Exact state comparison was made bitwise using `transfer`, and the comparison helper was declared `pure`.

No physical equation, tolerance or state ownership rule changed in response.

## Current gate

The strengthened current postimage is pinned to:

- head: `ac998d39f2be304b24fbfbdab871983a4fc142b4`;
- workflow: `PPA-WU05-A2 typed macropore state`;
- run: `36759833884` / run number 12.

At this checkpoint GitHub Actions reports the run as `queued`; it has not yet executed. The queue is infrastructure/platform state, not a passed qualification.

PR #909 was temporarily closed to stop dozens of unrelated historical pull-request workflows from continually refilling the Actions queue. The branch and all commits remain intact. The PR may be reopened after the branch qualification run completes.

## Verdict

A2 is **implemented and reconciled**, but not yet labeled `QUALIFIED` because the persisted current-head gate has not executed.

No production admission is claimed.

The next safe action after run 36759833884 is:

- PASS: record A2 qualification/closeout, reopen PR #909, then preregister A3;
- FAIL: inspect only the A2 run log, repair the bounded issue, and rerun.
