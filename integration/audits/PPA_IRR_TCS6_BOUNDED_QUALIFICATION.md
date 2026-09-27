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
