# F-PE-TIMEARCH14 result — trial-detected dynamic-top boundary events

Date: 2026-09-28

Status: `CLOSED_BOUNDARY_EVENT_REFINEMENT_INSUFFICIENT`

Canonical base:

`integration/f-ci-canonical@133cf2693a911f2c3ab1a1b0c2dbeb17c14e4672`

Evidence:

- Actions run: `36431936115`;
- discovery job: `108960035543`;
- conclusion: SUCCESS.

## Candidate architecture

AUTO_REFERENCE proposed steps from normalized accepted-state movement with no normal operating DTMAX.

Candidate final surface mode was classified as:

- FLUX;
- HEAD_NO_RUNOFF;
- HEAD_RUNOFF.

When the candidate mode differed from the previous accepted mode, the full candidate was discarded and the interval was recomputed as two sequential half steps.

Both RESET and RETAIN post-transition memory policies were tested.

## Result

Neither candidate advanced.

### TRANSITION_RESET

- P-C1 pass: 13/16;
- median deterministic work reduction on passing cases: about 34.4%;
- wet/ponding preservation: FAIL;
- median transition refinements: 0.

### TRANSITION_RETAIN

- P-C1 pass: 13/16;
- median deterministic work reduction: about 34.4%;
- wet/ponding preservation: FAIL;
- median transition refinements: 0.

## Failure attribution

Three cases failed in both variants.

### B01/POND

Solver nonconvergence reached the retry floor.

### O05/POND

Solver nonconvergence reached the retry floor.

These failures are consistent with the previously observed short-duration/non-monotone recovery pathology: repeated shrinkage is not guaranteed to make the current Richards solve easier.

### B12/MOIST

One boundary transition was detected and refined.

However, even after two-half refinement the candidate terminal head remained outside P-C1.

Thus one binary refinement is not sufficient for this transition.

## Interpretation

The event-detection idea is directionally better than pre-solve risk prediction because it operates on an actual candidate trajectory.

But the tested implementation remains incomplete:

- transition refinement depth is too shallow for at least one wet transition;
- failure recovery still assumes monotone benefit from timestep reduction;
- initial already-ponded cases can remain in the same coarse surface mode and therefore never trigger transition refinement.

## Decision

Do not advance two-half mode-transition refinement.

A valid successor may use a controller state machine:

- aggressive AUTO only while accepted surface mode remains FLUX;
- stronger localized refinement when leaving FLUX;
- explicit conservative fallback after entering HEAD/runoff;
- no assumption that repeated timestep halving alone is a reliable solver-recovery strategy.

No production controller is enabled.
