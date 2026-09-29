# F-PE-TIMEINT12 result — fully implicit dynamic-top derivative prerequisite

Date: 2026-09-29

Status: `IMPLICIT_DYNAMIC_TOP_DERIVATIVE_QUALIFIED`

Authority:

- canonical base: `integration/f-ci-canonical@044e686d1899adf3a631716d09743aa4fce0818f`;
- Actions run: `36517049787`;
- derivative job: `109241572742`;
- conclusion: SUCCESS.

## Candidate

For conductivity mean method 1, include the top-node conductivity dependence in the analytical dynamic-top head derivative using the existing qualified smooth-route constitutive `dK/dh`.

The analytical derivative reduces exactly to the BOFEK00 fixed-K derivative when `dK/dh=0`.

## Result

Across B01, B12, O05 and O14 hydraulic archetypes:

- smooth same-route head-regime points: `608`;
- ponded-head without runoff: `133`;
- linear-runoff head route: `475`;
- all derivatives finite;
- maximum absolute analytical versus central-FD mismatch:
  `1.93e-10`;
- maximum relative mismatch:
  `4.85e-8`;
- fixed-K limiting identity mismatch:
  `2.78e-17`.

Frozen gates:

- >=20 total: PASS;
- >=5 ponded no-runoff: PASS;
- >=5 linear runoff: PASS;
- max absolute <=1e-6: PASS;
- max relative <=1e-5: PASS;
- fixed-K identity <=1e-12: PASS.

## Decision

Classification:

`IMPLICIT_DYNAMIC_TOP_DERIVATIVE_QUALIFIED`.

The missing fully implicit surface-head derivative is no longer a mathematical blocker.

This does not yet qualify SWKIMPL=1 dynamic-top execution. The next phase must materialize the derivative test-only and prove fully implicit Backward Euler stability/correctness on wet/ponding trajectories before BDF2 history is introduced.
