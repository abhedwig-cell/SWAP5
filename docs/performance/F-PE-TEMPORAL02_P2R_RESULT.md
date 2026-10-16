# F-PE-TEMPORAL02 P2R result — paired/interleaved runtime replication

Date: 2026-09-26

Status: `POLICY_DRIVEN_RUNTIME_COST_CONFIRMED`

## Protocol

Seven paired batches per point compared 5e-4 with 1e-3 cm, alternating arm order. Each batch used five warm-ups and thirty measured same-origin trials per arm.

## Result

### DIRECT/DIRECT points

Ten points accept the first full-window attempt under both budgets.

Median of their per-point paired runtime ratios, 5e-4 / 1e-3:

`1.00300`

The individual point medians remain close to unity. The earlier B12 +0.001 single-batch ratio of ~1.83 disappears: paired median = `0.99181`.

This confirms that the P2 B12 contrast was batch/machine noise, not a temporal-policy cost.

### RETRY/DIRECT points

The two O14-wet points retain a real path difference:

- O14 wet -0.001 cm: paired median ratio `2.29426`;
- O14 wet +0.001 cm: paired median ratio `2.29748`.

Combined retry/direct median ratio:

`2.29587`

This is consistent with P0: 5e-4 incurs one temporal rejection and reduced-duration continuation, while 1e-3 accepts the first full-window physical solve.

## Interpretation

For points where transaction paths are identical, changing the budget from 5e-4 to 1e-3 has no material runtime effect.

The performance benefit of 1e-3 arises exactly where it removes a temporal retry. On the current O14-wet controls that saves roughly 56% of trial runtime relative to 5e-4.

## Decision

Retain 1e-3 cm as the preferred small-displacement performance candidate.

This is still not a production-policy recommendation. The next phase must determine how the required budget scales with corrector displacement and whether a fixed 1e-3 budget covers a meaningful coupled-corrector window.
