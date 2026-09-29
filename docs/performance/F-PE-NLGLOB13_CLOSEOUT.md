# F-PE-NLGLOB13 closeout — near-saturation TG subdivision

Date: 2026-09-29

Final status:

`CLOSED_TG_NEARSAT_SUBDIV2_INSUFFICIENT`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@ab151e5dcc3054f8be2bc0d7a25f905e44395f96`

Qualification authority:

- run `36554465665`;
- job `109360177737`;
- conclusion: SUCCESS.

## Closure

One-level event-local subdivision is closed as insufficient.

Positive preserved evidence:

- smooth order remains about 2.048;
- physical mass remains near roundoff;
- full dynamic replay completion is 88/96;
- no process failures occur;
- S0/R0 endpoint research authority remains intact.

Negative target evidence:

- all 7/7 frozen O05 TG near-saturation cases fail the subdivision attempt;
- no successful completed subdivision event is observed.

## Scientific conclusion

The remaining TG near-saturation blocker is deeper than a single nominal-step split.

This does not falsify temporal subdivision as a general mechanism, but it falsifies exactly the preregistered one-level `h -> h/2 + h/2` rescue.

The next step is attribution, not deeper subdivision by default.

## Direct successor

Open:

`F-PE-NLGLOB13A — halfstep failure attribution`.

P0 must remain observational.

It must distinguish at least:

1. first-half accepted-state domain failure;
2. second-half accepted-state domain failure;
3. first/second-half endpoint nonconvergence;
4. route mismatch;
5. ponding or nonfinite state failure.

No further subdivision is authorized until that failure structure is known.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB13

BASELINE: `ab151e5dcc3054f8be2bc0d7a25f905e44395f96`

BRANCH: `research/f-pe-nlglob13-nearsat-subdivision-current`

STATUS: closed negative

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `CLOSED_TG_NEARSAT_SUBDIV2_INSUFFICIENT`

NEXT SAFE STEP: preregister NLGLOB13A halfstep failure attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
