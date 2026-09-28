# F-PE-TIMEINT03 P0 result — explicit fully implicit Backward Euler

Date: 2026-09-28

Status: `P0_IMPLICIT_OPERATOR_USABLE`

Authority:

- canonical base: `integration/f-ci-canonical@0d131bfc0d7b490b936b4315b17d175342e29ee6`;
- Actions run: `36442468184`;
- job: `108996196415`;
- conclusion: SUCCESS.

## Test-only change

The canonical explicit Reference binding was materialized under a distinct test module name.

Its only semantic change was removal of the pre-solve deferral for `conductivity_implicit_mode=1`.

HeadCalc and all physical equations remained canonical.

## Result

BE_KIMPL:

- 4/4 hydraulic/forcing cases complete over the entire four-level dt ladder;
- 16/16 individual runs complete;
- median refined top-head temporal order: `0.9630`;
- expected first-order interval: [0.7, 1.3];
- median deterministic work per step: `16.1875`.

BE_KLAG comparator:

- median refined top-head temporal order: `0.9426`;
- median deterministic work per step: `16.0`.

Work ratio:

`BE_KIMPL / BE_KLAG = 1.0117`.

Thus endpoint-updated conductivity costs only about 1.2% more deterministic work per step in this smooth explicit fixed-flux test envelope.

## Interpretation

The existing HeadCalc SWKIMPL=1 operator is usable through the explicit provider path once the binding-level deferral is removed.

TIMEINT02A failures were entirely caused by the explicit binding contract, not by nonlinear failure of HeadCalc.

P0 advancement gate:

`PASS`.

This does not qualify production SWKIMPL=1 and does not generalize to dynamic-top.
