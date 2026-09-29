# F-PE-NLGLOB14D closeout — persistent saturated temporal mode

Date: 2026-09-29

Final status:

`QUALIFIED_PERSISTENT_SATURATED_TEMPORAL_MODE_RESEARCH`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@c0995bd21b2b755cd25337c1b407752d5cb44fb9`

Canonical reconciled before closeout through:

`integration/f-ci-canonical@57fba7961ed5a32679556653c6c4730d775623f2`

The intervening canonical delta is confined to ELASTIC18R verification and does not alter the NLGLOB14 temporal harness, target bank, dynamic-top provider, S0/R0 certificates or constitutive provider.

Qualification authority:

- run `36562038045`;
- job `109384957316`;
- conclusion: SUCCESS.

## Closure

NLGLOB14D closes positively.

All five frozen O05/TG near-saturation trajectories complete after introducing persistent post-saturation temporal regime state.

The qualified research sequence is:

1. ordinary provider-consistent TG while unsaturated;
2. bracketed saturation-event localization at first entry;
3. head/KLAG integration of the exact event remainder;
4. persistent head/KLAG integration on later nominal intervals while saturated research mode remains active.

Observed:

- 5/5 targets complete;
- 11 later saturated-mode intervals complete;
- zero process failures;
- zero later endpoint failures;
- zero route/state failures;
- max interval ledger about `2.24e-14 cm`;
- max cumulative ledger about `1.05e-14 cm`;
- smooth no-event TG remains order about 2.048.

## Scientific conclusion

The remaining near-saturation blocker was a temporal regime-state defect, not a failure of:

- the TG second-order mechanism in the unsaturated regime;
- event localization;
- the immediate KLAG remainder;
- physical mass conservation.

Once saturation has been entered, that regime must persist across nominal interval boundaries instead of re-entering an unsaturated TG formulation that assumes a new interior saturation crossing.

## Direct successor

Open a full-bank qualification workunit:

`F-PE-NLGLOB14E — complete 96-case dynamic-top policy qualification`.

Use the complete qualified research policy:

- ordinary TG before saturation;
- NLGLOB14A event localization;
- NLGLOB14C KLAG event remainder;
- NLGLOB14D persistent saturated KLAG mode;
- unchanged S0/R0 endpoint certificates.

The full bank must establish coverage, mass, route/state admissibility and work diagnostics.

A physical saturated-mode release condition remains downstream and must not be invented inside NLGLOB14E.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14D

BASELINE: `c0995bd21b2b755cd25337c1b407752d5cb44fb9`

BRANCH: `research/f-pe-nlglob14d-persistent-saturated-mode`

STATUS: closed positive

IMPLEMENTATION STATUS: test-only persistent saturated temporal mode persisted

TEST STATUS: focused target + smooth run PASS

QUALIFICATION STATUS: `QUALIFIED_PERSISTENT_SATURATED_TEMPORAL_MODE_RESEARCH`

NEXT SAFE STEP: preregister full 96-case NLGLOB14E qualification

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
