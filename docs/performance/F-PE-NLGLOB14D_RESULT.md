# F-PE-NLGLOB14D result — persistent saturated temporal mode

Date: 2026-09-29

Status:

`QUALIFIED_PERSISTENT_SATURATED_TEMPORAL_MODE_RESEARCH`

Canonical base:

`integration/f-ci-canonical@c0995bd21b2b755cd25337c1b407752d5cb44fb9`

Qualification authority:

- workflow run: `36562038045`;
- job: `109384957316`;
- conclusion: SUCCESS.

## Frozen question

After the first localized TG saturation event and successful KLAG remainder, is persistent KLAG/head-based evolution over subsequent nominal intervals sufficient to complete the frozen near-saturation target horizon without re-entering TG event logic?

## Result

All five frozen O05/TG HEAD-RUNOFF target trajectories complete the requested horizon.

Observed authority:

- completed targets: `5 / 5`;
- process failures: `0`;
- later endpoint failures: `0`;
- state failures: `0`;
- persistent saturated KLAG intervals: `11`;
- max accepted-interval physical ledger: about `2.24e-14 cm`;
- max cumulative physical ledger: about `1.05e-14 cm`.

No later `SATURATION_ROOT_BRACKET_INVALID` occurs.

## Smooth no-event preservation

PASS.

The original no-event smooth bank remains strongly second order:

- 4/4 ladders complete;
- median refined top-head order about `2.04787`;
- median refined top-theta order about `2.04787`;
- 4/4 individual refined head ladders >=1.5;
- median deterministic work ratio versus KLAG BE: `1.0`;
- physical mass remains at roundoff.

## Frozen classification

`QUALIFIED_PERSISTENT_SATURATED_TEMPORAL_MODE_RESEARCH`.

All frozen gates pass.

## Interpretation

The remaining near-saturation TG blocker is resolved at research level for the frozen target set.

The required temporal state machine is:

- unsaturated: provider-consistent second-order TG;
- first saturation crossing: bracketed TG event localization;
- exact event remainder: head-based KLAG;
- subsequent nominal intervals: persistent KLAG while the saturated research mode remains active.

Returning immediately to TG after the first remainder was the cause of the repeated saturation-bracket failure.

## Consequence

A full 96-case dynamic-top qualification is now authorized using the complete research policy:

- no-event TG;
- saturation-event localization;
- KLAG event remainder;
- persistent saturated-mode KLAG;
- unchanged S0/R0 endpoint certificates.

A separate later workunit is required for physical desaturation/release semantics before production-shaped admission.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
