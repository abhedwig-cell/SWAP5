# F-PE-TEMPORAL02 P0 result — temporal budget completion frontier

Date: 2026-09-26

Status: `NONTRIVIAL_COMPLETION_FRONTIER_FOUND`

## Protocol

Six difficult PROFILE06 origins were evaluated at signed same-origin corrector offsets +/-0.001 cm.

Temporal head-budget sweep:

- 1e-5 cm;
- 2e-5 cm;
- 5e-5 cm;
- 1e-4 cm;
- 2e-4 cm;
- 5e-4 cm;
- 1e-3 cm.

Fixed controls:

- exact Reference solver;
- mode 5 prescribed bottom head;
- max nonlinear iterations 48;
- max backtracking 16;
- min step duration 1e-10 day;
- retry scale 0.5;
- max retries 8;
- existing 1e-12 mass/head tolerances.

Three fresh-process repetitions were run per case/offset/budget. Ordered attempt signatures were deterministic.

## Aggregate result

| Temporal budget (cm) | Completed | Attempt events | Temporal rejections | Solver rejections |
| ---: | ---: | ---: | ---: | ---: |
| 1e-5 | 1/12 | 103 | 25 | 76 |
| 2e-5 | 4/12 | 80 | 21 | 53 |
| 5e-5 | 4/12 | 76 | 19 | 53 |
| 1e-4 | 4/12 | 81 | 20 | 56 |
| 2e-4 | 8/12 | 64 | 18 | 31 |
| 5e-4 | 12/12 | 16 | 2 | 0 |
| 1e-3 | 12/12 | 12 | 0 | 0 |

The frontier is strongly nonlinear. Merely increasing the budget slightly above the current value does not remove the retry cascade for the harder wet cases. Once the budget reaches the 2e-4 to 5e-4 cm range, completion changes sharply.

## Smallest tested completing budget by point

- B01 mid -0.001 cm: 2e-5 cm;
- B01 mid +0.001 cm: 1e-5 cm;
- B12 wet -0.001 cm: 2e-5 cm;
- B12 wet +0.001 cm: 2e-5 cm;
- B01 wet -0.001 cm: 2e-4 cm;
- B01 wet +0.001 cm: 5e-4 cm;
- O05 wet -0.001 cm: 5e-4 cm;
- O05 wet +0.001 cm: 2e-4 cm;
- O14 mid +/-0.001 cm: 2e-4 cm;
- O14 wet +/-0.001 cm: 5e-4 cm.

The common tested completion budget is therefore 5e-4 cm.

## Path behavior

At 5e-4 cm:

- all 12 nonzero points complete;
- 10/12 complete without a temporal rejection;
- the two remaining points complete after one temporal rejection and reduced-duration continuation;
- zero solver rejections remain in aggregate.

At 1e-3 cm:

- all 12 points complete;
- all complete in one transaction event;
- no temporal rejection occurs;
- no solver rejection occurs.

This confirms the REPRO02 causal model: widening the temporal acceptance envelope prevents entry into the short-duration nonlinear-collapse regime.

## Interpretation

P0 demonstrates a real numerical-policy frontier.

It does **not** establish that 5e-4 or 1e-3 cm is physically acceptable.

The observed completion improvement is large enough to justify focused physical qualification, but no production policy change follows from P0 alone.

The next comparison should concentrate on:

- 2e-4 cm, partial-completion shoulder;
- 5e-4 cm, first common tested completion budget;
- 1e-3 cm, first tested all-direct-accept budget.

The current 1e-5 cm authority remains the exact reference policy until qualification says otherwise.

## Decision

Advance to P1.

P1 must quantify accepted-path state/q differences and runtime before attempting any production recommendation.
