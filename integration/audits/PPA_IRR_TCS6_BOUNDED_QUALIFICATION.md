# TCS6 bounded runtime qualification

Status: branch-local qualified scope, not canonical admission.
Reconciled at `9d6142880`; tested scientific/test postimage `11baf3343`.
Owning evidence: `PPA_IRR_TCS6_COMPOSITION_STATUS.json` and
`PPA_IRR_TCS6_OWNER_DESIGN.md`. Historical staged entries are not current gaps.

## Established boundary

- Explicit daily ordinal and source weekly counter reside in the single existing
  committed irrigation/hydraulic carrier. Successful no-gift calls publish them;
  rejected calls do not. There is no inferred calendar or second counter owner.
- Startup, duplicate suppression, seven successor invocations, zero-deficit
  rollover, gap/backward rejection and correct retry are exercised through the
  daily adapters. Rollover state survives a freshly initialized decoded restart.
- Positive deficit triggers a gift at successor ordinal 111 after counters 5/6;
  active-gift restart and same-ordinal completion retain counter 0 without a
  duplicate gift. These are explicit management invocations over short hydraulic
  intervals, not seven elapsed simulation days.
- Exact, next-prefix and window adapters forward an optional numerical selector
  through prepared bootstrap, resolved runtime, backend and the existing kernel.
  No selector is enabled by default. Acceptance and per-column publication stay
  in the existing transaction path, including mixed-column behavior.
- The originally failing 1/1024-day no-gift interval completes with the test
  selector; invalid target rejection, commit, decoded restart and another
  1/1024-day continuation are covered. Original/restored continuations have exact
  physical/history/mass identity. Stale event markers are rejected; unchanged
  continuation forcing must clear the expired marker.
- Process splitting, durable prefix budgets and short two-prefix gift/no-gift
  completion have separate evidence. Selector forwarding does not generalize
  those tests to arbitrary long forcing windows.

## Evidence and limitations

The current full IrrigationSource gate passes clean O0/O2 exact transcripts at
`11baf3343`, including three bootstrap fixture variants. Same binaries pass
hydraulic-copy and guards with exact identity. Documentation source and strict
MkDocs checks pass. Build: `swap-ppa-wu01-9774933a1556443da4b41df24d575c84`.

The default long no-gift failure remains a preserved negative fixture. The first
failed endpoint remainder is about 1.586689e-6 day with compartment residuals
slightly above 1e-12 cm/day. Shrinking eventually worsens residuals. This is not
proof of a general root cause; neither increasing iterations nor changing time
origin alone resolved it. No tolerance was relaxed.

Not established: full-day or seven-day hydraulic execution, disk-codec
qualification, automatic crop reset, TCSFIX, broader physical delivery routes,
or canonical admission.

## Next numerical experiment

### Effective retry policy reconciliation

The IrrigationSource fixture already selects retry scale 0.8 and caller budget
64 before building the profile. The ordinary bounded selector tightens this to
16; `--weekly-full-day-dense` raises only the effective cap to 64. It does not
introduce denser shrink sampling relative to the ordinary full-day experiment.
`mod_canonical_interval_runtime` copies the caller policy and takes the minimum
of retry caps; `reject_and_retry` in `mod_transaction_reference` directly
multiplies the attempt duration by the configured scale. There is no
solver-suggested duration override on that rejection path. Both experiments
therefore share the first 16 retry durations. More retries reach much smaller
steps but do not resolve the second-day failure. No acceptance criterion changed.

### Full-day trial result (2026-09-27)

Failure diagnostic postimage `81a08bee7` gives identical O0/O2 evidence:
31882 accepted internal steps, 31909 attempts, 27 solver rejections and zero
temporal rejections. Terminal trial is 4101.6739501953143 to
4101.6739506248114; four balance failures, no head failures, maximum balance
rate 1.6855274120874952e-11 and total -7.9446362682977778e-12.
Rollback checks pass for candidate unavailability, committed time/revision,
pressure, water, temporal history and weekly metadata. This is not exhaustion
of the 131072-step cap. It does not yet establish the cause of the first solver
rejection. Next: examine that first rejection and retry-cap interaction without
relaxing acceptance. Ordinary IrrigationSource and hydraulic-copy/guards retain
exact O0/O2 identity. Build `swap-ppa-wu01-6e5769c3bf2c4f24ad1452878f15bb05`,
`O0/O2/full-day.txt`; negative experiment intentionally exits nonzero.

Continuation attempt `498da7ce5`: requesting another full day from the original
committed owner fails with transaction status 2 in both O0/O2. The optional
experiment exits nonzero before restored-owner replay, so it does not establish
restart divergence or continuation equivalence. First-day qualification remains
green. Ordinary IrrigationSource and hydraulic-copy/guards retain exact O0/O2
identity. Build `swap-ppa-wu01-87fb0b79dab642819a7a06e118cd63bc`,
`O0/O2/full-day.txt`. Next diagnostic: failure endpoint/counters and rollback;
the numerical gap is not a campaign-wide blocker. No acceptance rule changed.

Follow-up postimage `26f3214ad` additionally commits the full-day candidate through
the existing publisher and checks time T0+1/revision 1. Decoded export/restore
preserves exact pressure, water, temporal history, time, revision, lineage and
weekly counter 4/ordinal 101, with no active gift. Ordinary IrrigationSource and
same-binary hydraulic-copy/guards pass clean O0/O2 identity; separate full-day
output matches excluding wall time. Build
`swap-ppa-wu01-b78d232e50ac445c9496577e9b81170c`, `O0/O2/full-day.txt`;
TEMP `swap-full-day-restart-baseline.log`. This supersedes the trial-only boundary
below for publication and decoded restoration, but not continuation replay,
disk codec, full-day daily adapters or seven-day execution. Next: compare
original/restored continuation from this committed full-day checkpoint.

Test postimage `274b463a6` adds the isolated `--irrigation-source
--weekly-full-day` experiment without changing the ordinary regression or
production defaults. Clean O0/O2 IrrigationSource baseline and same-binary
hydraulic-copy/guards pass with exact identity. The separate full-day experiment
also completes in both builds, with identical output excluding measured wall time:

- Requested endpoint reached: 4101.1875 (one full day from 4100.1875).
- Accepted substeps 65571; attempts 65750; solver rejections 86; temporal rejections 93.
- Mass residual -5.3429483060085659e-15; status 0, completed true.
- Wall time approximately 2.008 seconds O0 / 0.990 seconds O2 on this host.
- Candidate ready, committed owner remains at original time and revision 0.

Build `swap-ppa-wu01-d0ef4820ea604e2784d1845d044c22b4`; TEMP logs
`swap-weekly-full-day-baseline.log`, `swap-weekly-full-day-O0.log` and
`swap-weekly-full-day-O2.log`. This establishes a full-day **trial**, not
publication, restart replay, daily adapter execution or seven-day coverage.
Next: full-day commit and decoded restart continuation with this explicit policy.
The experiment budget/design below is retained as its preregistration.

The test selector caps every internal target at 1/65536 day. Therefore a full
day needs **at least 65536 accepted substeps**, even before adaptive reductions.
The current fixture cap of 16384 cannot complete a full day under that policy;
raising only the requested endpoint would test a known resource ceiling.

Run a separately labeled full-day experiment with explicit execution budget
at least 131072 substeps, retaining nonlinear, temporal and mass tolerances,
transaction retry limits, unchanged forcing and one daily ordinal. This changes
resource allowance, not acceptance. Keep the bounded regression unchanged.
Record actual endpoint, attempts, accepted steps, mass, wall time and failure
classification; preserve committed state on failure. First establish one day
before attempting seven days or recommending a default numerical policy.
If this is too expensive or fails, keep the numerical gap explicit and continue
other migration capabilities rather than treating it as campaign-wide closure.
