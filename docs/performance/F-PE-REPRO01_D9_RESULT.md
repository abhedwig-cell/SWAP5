# F-PE-REPRO01 D9 result — inactive-root qbot materialization

Date: 2026-09-26

Status: `ROOT_CAUSE_CONFIRMED`

## Experiment

D9 tested the root-sink scratch dependency isolated by D8.

Three fixed diagnostic variants were run for 100 fresh exact first-corrector processes each:

1. CLEAN
   - zero/reset workspace;
   - no root-sink poison;
   - original production semantics.

2. ORIGINAL_ROOT_SINK_POISON
   - `provider_root_sink` filled with quiet NaN before the accepted-direction solve;
   - original mode-5 qbot materialization retained.

3. CONDITIONAL_QROSUM_FIX
   - same `provider_root_sink` NaN poison;
   - test-only qbot materialization uses root-sink scratch only when
     `request%evaluation%root_sink` is associated;
   - otherwise `qrosum=0`.

## Result

- CLEAN: 100/100 PASS;
- ORIGINAL_ROOT_SINK_POISON: 0/100 PASS;
- CONDITIONAL_QROSUM_FIX: 100/100 PASS.

The original poisoned failure reproduced the spontaneous exact failure signature:

- participant status 6;
- solver status `SW_SOLVE_RETRY_ADVISED`;
- 16 nonlinear iterations;
- 16 Jacobian builds;
- 16 linear solves;
- 108 backtracking attempts;
- 1 internal retry;
- no temporal certificate.

The conditional inactive-root materialization restored deterministic success under the same deliberately poisoned scratch state.

## Root cause

The exact B1.10 prescribed-head bottom-flux materializer currently computes:

`qrosum = sum(richards%provider_root_sink(1:n))`

unconditionally.

For root-inactive requests:

- `request%evaluation%root_sink` is not associated;
- `provider_root_sink` is worker scratch, not authoritative state;
- that scratch is not required to be initialized by the inactive-root route.

Therefore the materializer reads non-authoritative scratch before write.

Depending on process memory contents, that undefined contribution can contaminate mode-5 qbot reconstruction and destabilize the surrounding transaction path.

## Evidence chain

The diagnosis is supported by independent evidence:

- fixed-build live route: exact 8/20 failures, A2C 4/20;
- reduced first-corrector route can reproduce status 6 without MODFLOW;
- Valgrind reports conditional use of uninitialized heap data originating in Reference workspace allocation;
- whole-workspace poison reproduces status 6 deterministically;
- D7 localizes the active dependency to PROVIDER scratch;
- D8 localizes PROVIDER to `provider_root_sink` only;
- D9 restores 100/100 success while keeping `provider_root_sink` poisoned and changing only inactive-root qrosum ownership.

## Decision

The defect is sufficiently localized for a separate production repair workunit.

REPRO01 itself does not modify `src/**`.
