# TCS2-4 profile runtime composition

Status: proposed next implementation phase; not runtime qualification.

Owning preregistration: `PPA_IRR_TCS2_4_PROFILE_PREREGISTRATION.json`.
Source evidence: `PPA_IRR_TCS2_4_PROFILE_STATUS.json`.

## Explicit route

For TCS2-4 with DCS2, passing the existing optional `profiles` array to the
bootstrap irrigation adapter will select checked profile derivation. Omitting
it retains the existing supplied aggregate observation route. TCS1 continues
to use supplied daily stress observations. Timing thresholds still come from
the observations object on both routes. Array-size preflight remains mandatory.

Use the already exported committed snapshot's hydraulic view and irrigation
event together. No additional state owner, second snapshot, or alternate
aggregation equations are needed. The source helper, not bootstrap preflight,
validates root geometry when a new eligible event is selected. Pending gifts
and ineligible selection do not require a newly valid profile or timing table.

## Required integration evidence

- Retain all four existing supplied-observation runtime fixtures unchanged.
- Add three profile-derived cases using the same staggered event lengths,
  interior prefix split, hard mass residual limit and decoded fresh-owner restart.
- Give deliberately contradictory supplied aggregates to prove the profile
  route is actually used, rather than accidentally falling back to supplied values.
- Invalid geometry on eligible selection rejects before any hydraulic execution
  and leaves committed snapshot time, revision, water and event unchanged.
- Pending restart continuation with invalid geometry and timing table succeeds
  identically to uninterrupted execution, without selecting another gift.
- Repeat internally progressed hydraulic rejection through this route and
  verify committed physical/event state rollback.
- Run clean IrrigationSource O0/O2 and exact transcript comparison, then the
  hydraulic-copy and guards preservation scopes and documentation gates.

No changes to numerical acceptance, restart carrier identity, depth criteria,
calendar ingestion or canonical admission are included.
