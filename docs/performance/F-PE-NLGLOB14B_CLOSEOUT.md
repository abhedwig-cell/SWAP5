# F-PE-NLGLOB14B closeout — conservative saturation-event split

Date: 2026-09-29

Final status:

`CLOSED_SATURATION_EVENT_SPLIT_REMAINDER_INSUFFICIENT`

Canonical authority rechecked before closeout:

`integration/f-ci-canonical@262190047ff97399cb1368cf45d7965dedf6de86`

Qualification authority:

- run `36561069471`;
- job `109381802775`;
- conclusion: SUCCESS.

## Closure

NLGLOB14B closes the first complete event-split attempt negatively.

The first saturation event is localized correctly, but all primary O05/TG event targets immediately encounter a second accepted-state saturation crossing when the same unsaturated TG construction is restarted over the remaining nominal subinterval.

Observed authority:

- primary event targets complete: 0/5;
- full-bank event splits attempted: 8;
- second-crossing failures: 8;
- smooth median head order: about 2.048;
- smooth median moisture order: about 2.048;
- full-bank completion: 88/96;
- mass ledgers: roundoff scale;
- process failures: 0.

## Scientific conclusion

The current blocker is now a post-event regime problem.

Further recursive subdivision of the same unsaturated accepted-state formulation is not authorized.

The localized saturation boundary must be treated as an actual temporal regime transition.

## Direct successor

Open:

`F-PE-NLGLOB14C — post-saturation remainder regime formulation`.

The successor must define, before numerical result exposure:

- event-state ownership at saturation;
- saturated-state temporal variable(s);
- dynamic-top route/flux semantics after the event;
- a remainder residual/storage formulation that does not require representing `theta > theta_s` with the unsaturated retention inverse;
- nominal-interval mass composition;
- fail-closed behavior if the saturated regime cannot be resolved;
- smooth TIMEINT16C preservation when no event occurs.

A formulation may use pressure head as the post-saturation state variable while holding moisture at the saturated constitutive value, but the exact storage and mass semantics must be explicit before implementation.

## Closed routes

Do not:

- recurse into h/16-style subdivision;
- repeatedly relocalize the same saturation event without changing regime;
- clip accepted moisture;
- damp the remainder duration empirically;
- reinterpret saturation overshoot as a tolerance issue.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14B

BASELINE: `ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

CANONICAL RECONCILED THROUGH: `262190047ff97399cb1368cf45d7965dedf6de86`

BRANCH: `research/f-pe-nlglob14b-conservative-event-split`

STATUS: closed negative

IMPLEMENTATION STATUS: test-only event split persisted

TEST STATUS: focused combined qualification PASS

QUALIFICATION STATUS: `CLOSED_SATURATION_EVENT_SPLIT_REMAINDER_INSUFFICIENT`

DEPENDENCIES / BLOCKERS: post-saturation remainder regime unresolved

NEXT SAFE STEP: preregister NLGLOB14C post-saturation remainder formulation

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
