# F-PE-NLGLOB11A closeout — head-space endpoint coefficient predictor

Date: 2026-09-29

Final status:

`CLOSED_TG_HEADSPACE_STAGE_PHYSICAL_ADMISSIBILITY_FAILED`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@e59f1b2ffd97fb210c9d682332e740a1552a9f46`

Qualification authority:

- workflow run `36552073887`;
- job `109352378041`;
- conclusion: SUCCESS.

## Closure

NLGLOB11A closes the head-space endpoint coefficient-stage candidate negatively.

The candidate preserves the desired temporal mechanism on the smooth bank:

- median refined head order about `2.048`;
- median refined moisture order about `2.048`;
- 4/4 individual head ladders >=1.5;
- physical mass at roundoff;
- deterministic work ratio `1.0` versus KLAG BE.

It also removes the explicit auxiliary moisture-predictor domain failure.

However the same seven O05 TG HEAD/RUNOFF trajectories still fail the physical-admissibility gate later in the accepted TG construction.

Therefore the remaining near-saturation defect is not caused solely by whether the auxiliary endpoint coefficient stage is predicted in moisture or pressure-head coordinates.

## Scientific conclusion

The accumulated predictor evidence now constrains the successor strongly:

1. full endpoint-stage location is required for second-order behavior;
2. fixed half-step staging is first order;
3. a saturated extension of only the temporary K predictor does not fix the accepted TG state;
4. head-space endpoint staging preserves second order but also does not make the accepted near-saturated TG state admissible.

The unresolved problem is therefore the accepted temporal construction near the saturation boundary.

A successor must treat the temporal step or boundary interaction itself while preserving:

- the accepted physical mass contract;
- endpoint-consistent/provider-consistent K staging;
- second-order smooth behavior;
- no clipping of accepted moisture.

## Direct successor

Open a separately preregistered near-saturation temporal workunit.

A bounded first candidate may test **event-local step subdivision triggered by prospective accepted-state domain admissibility**, provided:

- subdivision is a temporal execution action, not accepted-theta clipping;
- each subinterval remains conservative;
- the final accepted state is the composition of physically admissible substeps;
- smooth TIMEINT16C order is preserved when subdivision is inactive;
- the trigger is defined before result exposure;
- dynamic-top route/event semantics remain explicit.

Do not reuse another fixed coefficient-stage fraction as a rescue.

## Relation to NLGLOB12

NLGLOB12 remains independent.

Its 14 above-floor endpoint failures affect TG and KLAG and are a nonlinear endpoint issue.

The seven NLGLOB11A failures are TG-only near-saturation temporal-admissibility failures.

Do not combine the two mechanisms.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB11A

BASELINE: `e59f1b2ffd97fb210c9d682332e740a1552a9f46`

BRANCH: `research/f-pe-nlglob11a-headspace-predictor`

STATUS: closed negative

IMPLEMENTATION STATUS: research-only head-space stage persisted

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `CLOSED_TG_HEADSPACE_STAGE_PHYSICAL_ADMISSIBILITY_FAILED`

DEPENDENCIES / BLOCKERS: seven O05 TG near-saturation accepted-state failures remain

NEXT SAFE STEP: preregister near-saturation temporal subdivision/admissibility successor

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
