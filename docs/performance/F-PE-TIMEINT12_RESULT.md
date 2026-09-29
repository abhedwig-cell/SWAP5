# F-PE-TIMEINT12 result — blocked before transition-fallback adjudication

Date: 2026-09-29

Status: `BLOCKED_DYNTOP_SWKIMPL1_SURFACE_DERIVATIVE`

Authority:

- canonical base: `integration/f-ci-canonical@044e686d1899adf3a631716d09743aa4fce0818f`;
- Actions run: `36517041240`;
- mechanism job: `109241547524`;
- conclusion: SUCCESS as an experiment harness.

## Intended question

Can fully implicit BDF2 run on the corrected dynamic-top route while reverting the exact transition interval to fully implicit Backward Euler when the accepted top-boundary regime changes?

## What actually happened

The transition-fallback mechanism was not reached broadly enough to decide that question.

Completed BDF2_FALLBACK trajectories:

- 8/24.

All completed cases are transition-regime cases.

All WET/POND trajectories stop earlier with:

`HeadCalc: dynamic head regime omitted surface-head derivative`.

The same failure occurs for:

- BE_FULL;
- BDF2_RAW;
- BDF2_FALLBACK.

The refined fully implicit BE comparator completes only 4/12 cases for the same reason.

## Attribution

This is not a BDF2 failure and not a fallback-policy failure.

The current dynamic-top provider exposes the BOFEK00-qualified surface-head derivative only when fixed top-node conductivity is supplied, i.e. the admitted SWKIMPL=0 fixed-K route.

TIMEINT12 deliberately uses test-only fully implicit conductivity because TIMEINT02 showed lagged-K BDF2 is not genuinely second order.

When the wet route enters the dynamic HEAD boundary with SWKIMPL=1:

- top-face conductivity depends on top-node head;
- the analytical surface-head solution therefore also depends on head through that conductivity;
- the provider does not yet expose the corresponding full `dHsurf/dh_top`;
- HeadCalc fails closed rather than constructing an incomplete Jacobian.

This is correct fail-closed behavior.

## Evidence from completed smooth cases

For the 8 completed no-transition trajectories:

- BDF2_FALLBACK and BDF2_RAW are exactly identical in terminal head, storage and runoff;
- median fallback/raw work ratio = 1.0;
- equation residual gate passes.

Thus the harness itself preserves the no-transition path.

## Decision

TIMEINT12 is blocked on a concrete prerequisite:

`F-PE-DYNTOP-KIMPL01 — fully implicit dynamic-top surface-head Jacobian derivative`.

Do not infer anything negative about BDF2 transition fallback from this run.

After the prerequisite is qualified, rerun TIMEINT12 unchanged from the same preregistered decision rules.

## Production boundary

No production source change.

BOFEK00 fixed-K SWKIMPL=0 authority remains unchanged.
