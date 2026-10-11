# F-PE-NLGLOB14B closeout — conservative saturation-event split

Date: 2026-09-29

Final status:

`CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

Qualification authority:

- run `36560757071`;
- job `109380777128`;
- conclusion: SUCCESS.

## Closure

NLGLOB14B closes the unchanged-TG remainder formulation negatively.

All five event localizations succeed and the no-event smooth bank remains second order, but all five exact remainders again produce accepted-state retention-domain failure.

There are no remainder endpoint failures and no process failures.

## Scientific conclusion

The remaining blocker is now a regime-formulation issue after saturation.

Once the accepted state reaches the saturation boundary, continuing the same unsaturated moisture-based TG accepted-state construction over the remaining interval is not admissible on this bank.

Further subdivision or event-time tuning is not justified.

## Direct successor

Open:

`F-PE-NLGLOB14C — saturated-remainder temporal regime switch`.

Freeze one bounded candidate:

1. localize and commit the NLGLOB14A saturation event;
2. reevaluate the dynamic-top route;
3. integrate the remaining duration with the existing implicit head-based/KLAG endpoint formulation;
4. preserve the event state as the remainder origin;
5. preserve the full nominal-interval physical mass ledger;
6. leave the no-event TG path unchanged;
7. retain S0/R0 research endpoint certificates;
8. no recursive split and no accepted-state clipping.

The candidate must be qualified first on the five frozen near-saturation targets and the smooth no-event bank.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14B

BASELINE: `ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

BRANCH: `research/f-pe-nlglob14b-saturation-event-split`

STATUS: closed negative

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED`

NEXT SAFE STEP: preregister NLGLOB14C saturated-remainder regime switch

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
