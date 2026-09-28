# F-PE-TIMEARCH14 preregistration — trial-detected boundary-transition refinement

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@133cf2693a911f2c3ab1a1b0c2dbeb17c14e4672`

Parent authority:

- TIMEARCH01-11 — timestep architecture and AUTO_REFERENCE interface qualified;
- TIMEARCH12 — effort-only controller rejected;
- TIMEARCH13 — pre-solve origin/linear boundary-risk prediction rejected as insufficiently selective;
- DYNERR01A — severe dynamic-top false-safe attributed to an actual FLUX -> HEAD path transition.

## Purpose

Test a controller that detects a dynamic-top regime transition from the actual converged candidate trial rather than trying to predict that transition before the solve.

Research-only. No production activation.

## Base proposal

Use the normalized accepted-state proposal:

`r_h = max_i(|h_i(k)-h_i(k-1)| / max(10 cm, |h_i(k-1)|))`

with frozen target:

`R = 0.40`.

After an accepted interval:

`factor = clamp(sqrt(R/max(r_h,1e-12)),0.5,2.0)`

`preferred_dt_next = preferred_dt_previous * factor`.

No normal operating DTMAX is used.

Initial preferred dt:

`0.005 d`.

Internal retry floor:

`0.001 d`.

Hard horizon/event clipping remains separate.

## Accepted boundary history

After every committed accepted interval, retain only the final dynamic-top boundary regime:

- FLUX;
- HEAD.

This is numerical/controller history, not physical state.

The initial origin has no previous accepted boundary mode.

## Trial transition rule

For each requested interval:

1. execute one full candidate trial transactionally from the accepted origin;
2. if the full trial fails to converge:
   - rollback;
   - apply normal solver retry: `max(retry_floor, attempted_dt/2)`;
   - do not update accepted controller history;
3. if the full trial converges:
   - inspect the full trial final dynamic-top boundary regime;
4. if no previous accepted boundary mode is available:
   - accept the converged full trial;
5. if full-trial final mode equals the previous accepted final mode:
   - accept the full trial;
6. if full-trial final mode differs from the previous accepted final mode:
   - discard the full candidate;
   - execute two sequential half intervals from the same accepted origin;
   - require both half trials to converge and satisfy the unchanged ledger gate;
   - commit the second-half endpoint;
   - use the second-half final mode as the new accepted boundary history;
   - count all discarded full-trial and two-half solver work.

Thus refinement is triggered only by an observed candidate mode transition.

## Important limitation

The rule detects endpoint-mode change relative to the previous accepted endpoint.

It does not prove that the within-step path contains no transient mode change that returns to the same final mode.

TIMEARCH14 therefore remains a research screening workunit.

## Comparator

Current LEGACY_NUMERICS Reference route.

## Calibration bank

Use the already exposed 16 BOFEK01 screening cases.

No material or regime identifiers may enter the controller.

## Accuracy gate

Use P-C1 unchanged:

- cumulative runoff <= 0.01 cm absolute when baseline runoff < 1 cm, otherwise <=1%;
- terminal storage <= max(0.01 cm, 0.5% baseline storage);
- terminal ponding <=0.02 cm;
- top/mid/bottom terminal head <=2 cm;
- max ledger <=5e-8 cm;
- no retry pathology.

## Performance gate

Count all deterministic work:

`NL + BACK + JAC + LIN`

including discarded full trials and refined half trials.

Advance only if:

1. >=15/16 P-C1 pass;
2. all WET/POND cases pass;
3. median deterministic work reduction >=15%;
4. no hydrologic regime has median work regression >5%;
5. retry-work fraction is no more than 5 percentage points above LEGACY_NUMERICS.

## Attribution

Record:

- number of observed mode transitions;
- number of refined intervals;
- discarded full-trial work;
- two-half refinement work;
- nonlinear retry work.

If no candidate advances, do not add another endpoint-mode heuristic in TIMEARCH14.

## Outcome

Possible:

- `TRIAL_TRANSITION_CONTROLLER_CANDIDATE_RESEARCH_ONLY`;
- `CLOSED_TRIAL_TRANSITION_REFINEMENT_NO_GAIN`;
- `CLOSED_TRIAL_TRANSITION_REFINEMENT_PHYSICAL_FAIL`.

No production timestep behavior changes.
