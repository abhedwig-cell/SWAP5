# F-PE-TIMEINT12A result — fully implicit BE on corrected dynamic-top

Date: 2026-09-29

Status: `CLOSED_IMPLICIT_DYNTOP_BE_NOT_QUALIFIED`

Authority:

- canonical base: `integration/f-ci-canonical@a73ae3610806d25219c3efa77c7e523ba164e48f`;
- Actions run: `36517444870`;
- job: `109242790414`;
- conclusion: SUCCESS.

## Candidate

Fully implicit Backward Euler on the corrected dynamic-top route:

- SWKIMPL=1;
- test-only TIMEINT12 qualified surface-head derivative;
- current BE storage derivative;
- BALTOL02 representation-aware floor;
- bottom mode 2 / zero bottom flux;
- no macropore/root/drainage composition.

Comparator:

- admitted fixed-K SWKIMPL=0 Backward Euler at identical fixed dt=0.005 d.

## Result

Planned KIMPL cases: 12.

Completed KIMPL trajectories:

`6/12`.

POND completion gate:

FAIL.

Successful KIMPL cases:

- B01/MOIST;
- B12/MOIST;
- B12/WET;
- O05/MOIST;
- O05/WET;
- O14/POND.

Failed KIMPL cases:

- B01/WET;
- B01/POND;
- B12/POND;
- O05/POND;
- O14/MOIST;
- O14/WET.

All completed KIMPL cases retain finite state and roundoff-scale water ledgers.

## Work cost

Across cases where KIMPL and KLAG both complete:

- median KIMPL/KLAG deterministic work ratio: about `1.320`;
- maximum ratio: about `1.668`.

Frozen gates were:

- median <=1.25;
- every individual <=1.50.

Both fail.

## Important interpretation

The TIMEINT12 surface-head derivative prerequisite is mathematically qualified.

Therefore this result is not evidence that the analytical derivative formula is wrong.

The failure is at the level of complete SWKIMPL=1 dynamic-top nonlinear execution.

The same fully implicit operator was previously robust and near-cost-neutral on the smooth fixed-flux envelope. The robustness loss is specific to dynamic-top composition.

## Decision

Do not advance dynamic-top BDF2.

The prerequisite for BDF2 smooth-history execution on wet/ponding dynamic-top cases is not satisfied because fully implicit first-order execution is itself insufficiently robust/cost-effective.

No production source change.

