# F-CI07 — B1.10 legacy trial capsule and physical rollback layer

F-CI07 separates broad mutable legacy trial bookkeeping from compact persistent column physics. The new `b1_10_legacy_trial_capsule_t` is deliberately **not** a canonical or transaction state. It belongs to the worker/adapter trial and is captured before a physical attempt and restored after rejection.

The capsule covers legacy timestep/retry state, calendar/reporting projection, forcing cursors, irrigation continuation/workspace, water-balance intermediate and cumulative accumulators, balance-period baselines, and day accumulators consumed by crop/root processes. Large arrays are allocatable so they exist only for workers performing the B1.10 legacy trial path.

Persistent physical continuation remains outside this capsule. F-CI06 already qualified the water checkpoint subset. The capsule therefore avoids the A23BU anti-pattern of storing forcing, time, numerical control and accounting permanently inside every logical column.

## Source-bound evidence

The capsule compiles against the exact B1.10/F-CI06 module interfaces at both `-O0` and `-O2`. A full local physical rerun probe was executed against the exact reconstructed B1.10 tree with the F-CI06 four-file postimage.

Two whole-day rollback cases were checked:

- 2002-01-05: the configured fixed-irrigation event day;
- 2003-05-15: five days after emergence of the detailed potato crop.

For each case the sequence was: advance to the committed state before the probe day -> capture physical state plus legacy trial capsule -> run the day -> restore -> reset worker scratch -> rerun the same day. The two accepted physical results were identical for pressure head, water content, soil temperature, mobile solute concentration and `cmsy`; selected water accounting totals were also identical. All measured maximum absolute differences were zero.

The test source is retained as `tests/fci/test_fci07_b1_10_physical_rerun.f90`. `tests/fci/run_fci07_full_b1_10_gate.sh` reconstructs the executable test path from an exact B1.10 source tree, the F-CI06 controlled source-port applicator, TTUTIL and the Hupsel case.

This qualifies the **whole-day Hupsel rollback path**, not arbitrary subday execution and not every optional SWAP module. Generic `[t0,t1]` remains the canonical runtime contract; the current legacy physical bridge still has a separate whole-day limitation.

## Invariant check

This advances invariants 3–5 and 7 by keeping non-physical rollback data out of persistent column state and scratch/job-local. It supports 16 and 27 because broad legacy arrays are paid per active worker, not per logical column. It changes no physics or numerical policy (23), introduces no mass concession (13), and does not claim generic physical time prematurely (9, 29).
