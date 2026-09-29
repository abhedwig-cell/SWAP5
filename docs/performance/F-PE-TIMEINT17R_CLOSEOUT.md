# F-PE-TIMEINT17R closeout

Date: 2026-09-29

Final status:

`QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE`

Qualification authority:

- workflow run `36563988024`;
- job `109391349634`;
- conclusion: SUCCESS.

Canonical was rechecked before this closeout at:

`integration/f-ci-canonical@d4d70ca5b776385db8f0ca9ffa9c9dfa5625c705`.

The intervening canonical delta did not alter the TIMEINT17/NLGLOB14 execution surface used by this qualification.

## Closure

The reopened TIMEINT17 same-route qualification passes with the complete assembled research policy.

Observed:

- 12/12 TG material-route ladders complete;
- 48/48 KLAG comparison trajectories complete;
- median refined TG top-head order about 1.989;
- median refined TG top-moisture order about 1.983;
- 10/12 individual refined head ladders >=1.5;
- max interval ledger about 4.84e-14 cm;
- max cumulative ledger about 6.06e-14 cm;
- max theta/head roundtrip about 1.11e-16;
- max native endpoint balance residual about 3.85e-10 cm/d;
- median TG/KLAG work ratio 1.0;
- all route/state and post-saturation semantic guards pass.

The original blocked TIMEINT17 result remains valid for the earlier solver composition. For the assembled research policy, the same-route blocker is resolved.

## Remaining scope

This result does not yet qualify every dynamic-top event.

Still separate:

- physical desaturation/release from persistent saturated mode;
- remaining release/route event semantics;
- known-time forcing split/restart where required.

TIMEINT18 variable-step TG/LTE remains downstream until those required event semantics close positively.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-TIMEINT17R

BRANCH: `work/f-pe-timeint17-reopen-dynamic-policy`

STATUS: closed positive

TEST STATUS: focused 96-case qualification PASS

QUALIFICATION STATUS: `QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE`

NEXT SAFE STEP: physical desaturation/release attribution, then remaining TIMEINT17 event semantics

## Production boundary

Research/test-only.

No production `src/**` change.

No numerical default or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
