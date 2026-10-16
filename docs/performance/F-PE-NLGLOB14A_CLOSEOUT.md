# F-PE-NLGLOB14A closeout — bracketed saturation-event root localization

Date: 2026-09-29

Final status:

`NLGLOB14A_SATURATION_EVENT_ROOT_LOCALIZED`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@b7e5acf9ea297d3d59f0b28202d34a0ccc96dd5e`

Qualification authority:

- run `36560164660`;
- job `109378844000`;
- conclusion: SUCCESS.

## Closure

NLGLOB14A closes positively.

All five frozen O05/TG near-saturation saturation events are localized by bracket-preserving bisection of the actual prospective TG event function.

Observed authority:

- 5/5 localized;
- maximum 14 bisection evaluations;
- maximum retained lower-state event distance about `4.58e-8 cm`;
- maximum event-subinterval physical ledger about `1.41e-14 cm`;
- no process failures.

## Scientific conclusion

The saturation boundary is a well-defined temporal event for the remaining near-saturation TG targets.

The earlier failures were caused by insufficient event-time localization, not by an inherently nonlocal or unbracketable defect.

A direct one-shot linear estimate is insufficient, but a bounded bracket-preserving root solve succeeds without clipping accepted moisture or altering the physical mass contract.

## Direct successor

Open:

`F-PE-NLGLOB14B — conservative saturation-event split and remainder integration`.

The successor must be preregistered before result exposure.

Mandatory mechanics:

1. localize the event using the qualified NLGLOB14A bisection;
2. commit the localized event state as an internal transactional subinterval;
3. reevaluate the dynamic-top provider and saturated/near-saturated regime;
4. integrate the exact remaining fraction of the original nominal interval;
5. publish only the final nominal-interval accepted state;
6. close physical mass over the complete nominal interval;
7. preserve smooth TIMEINT16C order when event logic is inactive.

No recursive subdivision semantics or accepted-state clipping are authorized.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14A

BASELINE: `b7e5acf9ea297d3d59f0b28202d34a0ccc96dd5e`

BRANCH: `research/f-pe-nlglob14a-saturation-root`

STATUS: closed positive

IMPLEMENTATION STATUS: test-only bracketed root localization persisted

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `NLGLOB14A_SATURATION_EVENT_ROOT_LOCALIZED`

NEXT SAFE STEP: preregister NLGLOB14B conservative event split

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
