# F-PE-TIMEINT12A result — fully implicit Backward Euler on corrected dynamic top

Date: 2026-09-29

Status: `CLOSED_IMPLICIT_DYNAMIC_TOP_BE_NOT_QUALIFIED`

Authority:

- canonical base: `integration/f-ci-canonical@a73ae3610806d25219c3efa77c7e523ba164e48f`;
- Actions run: `36517472668`;
- implicit-BE job: `109242875008`;
- conclusion: SUCCESS.

## Candidate

Fully implicit Backward Euler on the corrected dynamic-top route:

- SWKIMPL=1;
- conductivity mean method 1;
- test-only TIMEINT12-qualified analytical surface-head derivative;
- zero potential surface evaporation;
- linear runoff;
- bottom mode 2 / zero bottom flux;
- fixed dt=0.005 d.

Comparator:

admitted fixed-K SWKIMPL=0 Backward Euler at the same dt.

## Result

Fully implicit completion:

`6/12`.

Completed KIMPL cases:

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

All failures occur after entering the nonlinear solve and report solver failure.

Thus the previous missing-derivative contract blocker has been removed, but the bounded fully implicit dynamic-top operator is still not robust across the wet/ponding bank.

## Cost on completed pairs

KIMPL/KLAG deterministic work ratios:

- B01/MOIST: 1.207;
- B12/MOIST: 1.554;
- B12/WET: 1.668;
- O05/MOIST: 1.021;
- O05/WET: 1.432;
- O14/POND: 1.035.

Aggregate:

- median: `1.320`;
- maximum: `1.668`.

Frozen gates required:

- 12/12 KIMPL completion;
- every POND case complete;
- median work ratio <=1.25;
- no individual ratio >1.50.

All four relevant advancement conditions fail.

## Numerical validity

For completed KIMPL trajectories:

- states remain finite;
- mass-ledger gate passes;
- no derivative-contract failure remains.

Therefore the result is a nonlinear robustness/cost failure, not a mass or Jacobian-availability failure.

## Decision

Classification:

`CLOSED_IMPLICIT_DYNAMIC_TOP_BE_NOT_QUALIFIED`.

Do not advance fully implicit dynamic-top BDF2 from this operator.

The failed candidate is not rescued by raising MAXIT or changing solver controls in TIMEINT12A; those would be new post-exposure policy changes.

## Scientific implication

TIMEINT02 established that first-order lagged conductivity prevents ordinary BDF2 from becoming second order.

TIMEINT12A establishes that endpoint-fully-implicit conductivity is not yet a robust practical dynamic-top route.

A valid next question is therefore a genuinely second-order semi-implicit treatment of the nonlinear conductivity/operator, using accepted-history extrapolation rather than one-step lagging.

That is a different discretization, not a relaxation of this failed candidate.

## Production boundary

No production source change.

BOFEK00 fixed-K SWKIMPL=0 remains authority.
