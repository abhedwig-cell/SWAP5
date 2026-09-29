# F-PE-NLGLOB14Z1 closeout — late-retreat refinement

Date: 2026-09-29

Final status:

`BLOCKED_NLGLOB14Z1_REFINEMENT`.

## Closure

The preregistered four-level late-retreat refinement cannot qualify because the added finest fixed timestep, dt=1.5625e-5 d, does not reach the late `7:16 -> 8:16` event in either route family.

The failure is reproducible and transaction-safe:

- HEAD requests retry near 0.17161 d;
- RUNOFF requests retry near 0.16509 d;
- both remain finite;
- both remain mass-clean;
- both remain on dry surface-flux top-boundary semantics;
- both have accepted saturated tail 5:16 immediately before failure.

The next coarser dt=3.125e-5 d completes the 2.80 d horizon and reaches the late retreat in both routes.

This establishes a non-monotone fixed-dt solver robustness boundary.

## Mechanistic blocker

The immediate mechanism is HeadCalc nonlinear-loop exhaustion.

The reference binding reports status 2 as `SW_SOLVE_RETRY_ADVISED`.

HeadCalc responds to unresolved nonlinear convergence by:

- restoring the accepted origin state;
- setting `fldecdt=.TRUE.`;
- setting `request_dt_reduction=.TRUE.`;
- returning without accepting the failed candidate.

No state or mass leakage occurs.

The remaining unresolved attribution is why this retry request appears at the smaller fixed dt while the next coarser level passes the same broad physical phase.

## Preserved physical evidence

The complete control levels dt=1.25e-4, 6.25e-5 and 3.125e-5 d continue to expose a consistent accepted physical retreat:

`7:16 -> 8:16`

near:

- HEAD: 2.442875 d;
- RUNOFF: about 2.4397 d.

This evidence remains valid but does not satisfy the frozen Z1 four-level refinement gate.

## Direct successor

If this line is continued, open a separately preregistered local retry-attribution workunit around the first dt=1.5625e-5 failure origin.

The successor should test transaction-safe bounded subdivision of that one failed interval and determine whether:

1. a half-step is accepted and the nominal fixed-dt trajectory can resume;
2. repeated subdivision is required;
3. the retry is tied to a local nonlinear state transition rather than the late retreat;
4. accepted state, forcing and mass remain unchanged by rejected trials.

Do not tune MAXIT, BALTOL or physical forcing.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z1

BRANCH: `research/f-pe-nlglob14z1-late-retreat-refinement`

REFINEMENT RUN: `36610958316`

ATTRIBUTION RUN: `36611358172`

STATUS: closed with explicit nonlinear retry blocker

QUALIFICATION STATUS: `BLOCKED_NLGLOB14Z1_REFINEMENT`

NEXT SAFE STEP: preregister local transaction-safe subdivision attribution at the first finest-dt retry origin.

## Production boundary

No production source or default policy change.

`LEGACY_NUMERICS` remains production default.
