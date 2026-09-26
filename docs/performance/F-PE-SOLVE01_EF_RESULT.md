# F-PE-SOLVE01 EF result — aggressive discarded-trial solve-elimination upper bound

Date: 2026-09-26

Status: `PASS_STRONG_SIGNAL_RESEARCH_ONLY`

PR:
`#654 — F-PE-SOLVE01: bounded discarded-trial Richards solve elimination`

Qualified workflow run:
`36274377398 — F-PE-SOLVE01 EF upper bound`

## Scope

EF is the aggressive research-only arm from the SOLVE01 preregistration.

For each repeated eight-request same-origin corrector block:

- the first request is evaluated exactly;
- intermediate discarded responses use the local linear response from the exact anchor;
- the final request is evaluated exactly;
- the final candidate is then evaluated exactly again for authoritative validation and commit outside the timed discarded-trial loop.

No approximate candidate state is committed.

The test uses:

- the six frozen difficult PROFILE06 material/regime origins;
- both +/-10% dynamic-history directions;
- the conservative c=0.50 temporal policy as a research-only nonzero-corrector enabler;
- the qualified BALTOL02 dt-scaled Reference balance floor replayed inside the research harness;
- no production source modification.

## Result

All 12 frozen difficult origin/history groups pass.

Median across groups:

- runtime ratio EF / exact: `0.293106502`;
- median wall-clock speedup: `70.689350%`;
- median full Richards solve reduction: `74.953154%`.

The per-group speedup range is approximately:

- minimum: `69.41%`;
- maximum: `72.16%`.

Solve count in the repeated timed sequence plus final authoritative validation:

- exact arm: `1601`;
- EF arm: `401`.

All groups preserve:

- exact final q identity;
- exact final pressure-head state identity;
- exact final water-content state identity;
- one committed revision;
- one committed ledger entry;
- identical committed ledger exchange.

Thus the measured gain comes from eliminating discarded-trial Richards solves rather than weakening final-state ownership.

## Intermediate response error

Maximum relative error with respect to the exact response excursion over all 12 groups:

`1.11771554385181856e-4`

approximately `0.0112%`.

Representative maxima:

- B01 mid: about `4.56e-6`;
- B01 wet: about `2.09e-5`;
- B12 wet: about `4.00e-6`;
- O05 wet: about `1.12e-4`;
- O14 mid: about `5.99e-6`;
- O14 wet: about `7.26e-5`.

These are characterization values, not production admission limits.

## Gate disposition

Original SOLVE01 research-advancement gates:

- >=50% full-solve reduction: PASS;
- >=30% median end-to-end wall-clock reduction: PASS;
- exact final validation before commit: PASS;
- no approximate state commit: PASS;
- exact committed state/ledger ownership: PASS.

The preregistered strong-signal criterion of approximately 2x or greater speedup is also exceeded.

Measured median speedup factor:

`1 / 0.293106502 ~= 3.41x`.

## Interpretation

This result materially changes the remaining performance question.

On the frozen difficult matrix, the largest practical gain is not another small reduction inside a Richards solve.

It is avoiding full Richards solves for discarded corrector requests.

The EF result does not prove that the aggressive policy is suitable for production. It establishes that a large application-level performance opportunity exists and justifies bounded refresh-policy qualification.

## Important lineage note

The first two EF attempts failed before solve-elimination could be measured because the PROFILE06 parent lineage did not yet contain the later BALTOL02 Reference balance-floor admission required for these difficult nonzero correctors.

The successful research harness therefore replays the already qualified BALTOL02 rule:

`effective_balance_tol = max(configured_tol, 2.8e-16 cm / dt)`

without modifying production source on SOLVE01.

The c=0.50 temporal policy is likewise used only as a research enabler. This does not constitute temporal-policy production admission and does not weaken the TEMPORAL06 tangent-authority finding.

## Decision

`ADVANCE_BOUNDED_SOLVE_ELIMINATION`

Proceed to the separately preregistered P0B refresh frontier:

- E2;
- E4;
- EH;
- EF retained as upper-bound comparator.

No production admission is authorized by EF alone.
