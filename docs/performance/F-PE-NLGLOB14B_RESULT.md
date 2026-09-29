# F-PE-NLGLOB14B result — conservative saturation-event split and remainder integration

Date: 2026-09-29

Status:

`CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED`

Canonical base:

`integration/f-ci-canonical@ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

Qualification authority:

- workflow run: `36560757071`;
- job: `109380777128`;
- conclusion: SUCCESS.

## Frozen question

Can the qualified saturation event be committed as an internal subinterval and the exact remainder of the nominal interval be completed with the unchanged TG temporal formulation?

## Smooth regression

PASS.

The no-event smooth bank remains strongly second order:

- 4/4 ladders complete;
- median refined head order about `2.048`;
- median refined moisture order about `2.048`;
- 4/4 head ladders >=1.5;
- median deterministic work ratio versus KLAG BE: `1.0`;
- physical mass at roundoff.

Thus the event-split machinery does not damage the smooth TIMEINT16C mechanism when inactive.

## Target result

Completed frozen near-saturation targets:

`0 / 5`.

Remainder accepted-state domain failures:

`5 / 5`.

Remainder endpoint failures:

`0 / 5`.

Process failures:

`0`.

Physical mass accumulated before failure remains near roundoff:

- max accepted-interval ledger about `2.24e-14 cm`;
- max cumulative ledger about `1.15e-14 cm`.

## Frozen classification

`CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED`.

## Interpretation

The event time is now known accurately, and the event-state integration is physically clean.

The failure occurs after the saturation event because the unchanged unsaturated TG accepted-state construction is no longer an admissible temporal representation for the remainder.

This is not an event-localization failure and not an endpoint-solver failure.

It is a regime-formulation failure after reaching the saturation boundary.

## Consequence

Do not recurse or move the event time.

The next workunit must explicitly change the temporal formulation for the remainder after the saturation event while preserving the event state and nominal-interval mass contract.

A bounded candidate is to switch the remainder to the existing implicit head-based/KLAG endpoint formulation under the reevaluated dynamic-top route.

That candidate requires separate preregistration and must not alter the no-event TG path.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
