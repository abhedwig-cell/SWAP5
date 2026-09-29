# F-PE-NLGLOB14J result — dry-phase lower-block mass redistribution attribution

Date: 2026-09-29

Status:

`NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`

Canonical base:

`integration/f-ci-canonical@6fe778ffb5a55f6fb3cc13b9c1a43b71a4641096`

Qualification authority:

- workflow run: `36567115728`;
- job: `109401658928`;
- conclusion: SUCCESS.

## Frozen question

Is the upward expansion of the dry-phase lower saturated block explained by physically consistent downward internal redistribution from the drying upper profile?

## Coverage

PASS.

All eight frozen O05/TG forcing-reversal fixtures:

- complete;
- remain finite;
- preserve the frozen dry forcing;
- remain mass-clean;
- retain contiguous saturated lower blocks;
- have zero bottom flux within authority.

Process failures:

`0`.

## Frozen classification

All 8/8 fixtures classify:

`DOWNWARD_REDISTRIBUTION_SUPPORTS_BLOCK_EXPANSION`.

Aggregate classification:

`NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`.

## Redistribution evidence

For every fixture:

- saturated-node count expands;
- fixed lower region nodes 3:16 gain storage;
- fixed upper cap nodes 1:2 lose storage;
- total profile storage decreases;
- every saturated-block expansion interval has downward edge flux;
- downward expansion fraction: `1.0`;
- bottom flux: `0`.

Typical first-to-final dry-phase changes:

- lower-region storage gain: about `+0.1115` to `+0.1168 cm`;
- upper-cap storage change: about `-0.315` to `-0.381 cm`;
- total profile storage change: about `-0.280` to `-0.301 cm`.

Physical interval and cumulative mass remain near roundoff.

## Scientific interpretation

The counterintuitive saturated-block expansion is physically supported by internal redistribution under the frozen equations.

Upper nodes lose more water than the profile loses overall, while a smaller portion is redistributed downward into the lower region. The moving saturated edge is supplied by downward internal flux in every observed expansion event.

Therefore the NLGLOB14I pattern is not evidence of a state inconsistency or hidden water creation.

## Consequence

The previous restriction against extending the drying horizon is removed.

A longer-horizon observational fixture is now scientifically justified to determine whether the physically consistent lower saturated block eventually disappears.

The next release quantity should remain threshold-free:

`SATURATED_SET_EMPTY`

meaning no active node is saturated according to both existing head and moisture indicators.

No switch back to TG is authorized yet.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No release rule or numerical default changed.

`LEGACY_NUMERICS` remains production default.
