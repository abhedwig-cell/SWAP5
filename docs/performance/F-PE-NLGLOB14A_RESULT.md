# F-PE-NLGLOB14A result — bracketed saturation-event root localization

Date: 2026-09-29

Status:

`NLGLOB14A_SATURATION_EVENT_ROOT_LOCALIZED`

Canonical base:

`integration/f-ci-canonical@b7e5acf9ea297d3d59f0b28202d34a0ccc96dd5e`

Qualification authority:

- workflow run: `36560164660`;
- job: `109378844000`;
- conclusion: SUCCESS.

## Frozen question

Can the actual prospective TG saturation-event function be localized with bracket-preserving bisection from the same accepted physical origin, without clipping or empirical damping?

## Coverage

PASS.

All five frozen O05/TG near-saturation targets were evaluated.

Process failures:

`0`.

## Root-localization result

Localized targets:

`5 / 5`.

Maximum bisection evaluations required:

`14`.

Maximum retained admissible event-state water-depth distance from saturation:

`4.5780643165294066e-8 cm`.

This satisfies the unchanged `5e-8 cm` physical event-distance authority.

Maximum event-subinterval physical ledger:

`1.4065571624088946e-14 cm`.

All retained lower-bracket event states are retention-admissible and route/state finite.

## Frozen classification

`NLGLOB14A_SATURATION_EVENT_ROOT_LOCALIZED`.

All frozen qualification gates pass.

## Interpretation

The NLGLOB14 linear event estimate failed because the accepted TG event function is nonlinear in temporal fraction, not because the saturation event is ill-defined.

Bracket-preserving bisection resolves the event robustly and conservatively from the same physical origin.

The event can therefore be treated explicitly as a temporal boundary in the research time integrator.

## Consequence

A separately preregistered conservative event-split workunit is now authorized.

That workunit must:

1. commit the localized admissible event state transactionally;
2. reevaluate the dynamic-top/saturated regime at the event;
3. integrate the remainder of the original nominal interval under the explicitly resolved regime;
4. preserve the full nominal-interval physical mass ledger;
5. preserve smooth second-order behavior when no event occurs.

No production change is admitted by NLGLOB14A itself.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
