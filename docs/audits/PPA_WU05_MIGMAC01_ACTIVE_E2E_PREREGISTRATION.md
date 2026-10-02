# PPA-WU05-MIGMAC01 active E2E fixture contract

Date: 2026-10-01

Status: `PREREGISTERED_ACTIVE_E2E`

Qualified prerequisite postimage:
`f88c1fc3106b88fec60edb93fdc56f331ad75dff`

Preservation run:
`36925950836` — SUCCESS.

## Fixture

The active fixture shall use the already-qualified Reference-Richards transaction harness,
but move the standard macropore top from node 1 to node 3. Node 2 is therefore the exact
B1.11 covering cell.

The fixture must start with:

- `top_node = 3`;
- zero external A9 macropore top forcing;
- positive matrix pressure head at node 2;
- nonzero `KsatCovLay`;
- valid top macropore volume strictly between zero and one;
- enough free macropore storage to accept the covered transfer.

No rainfall shortcut or artificial source/sink provider may represent the covered transfer.

## Required observations

For one accepted physical attempt:

1. Reference Richards converges with the covering callback active.
2. The accepted covered amount reconstructed from final `h(2)` is positive.
3. Matrix exchange at node 2 contains the equal-and-opposite covered sink.
4. Candidate macropore storage gain contains exactly the covered amount, in addition to any
   independently qualified standard exchange terms.
5. Internal-exchange residual and macropore balance residual remain within the existing
   production tolerances.
6. The accepted macropore object supplied to the runtime is bit/value unchanged before commit.
7. Repeating from the same accepted origin produces the same matrix candidate, covered amount
   and macropore candidate.
8. The existing PERCH20 restart/preservation gates remain green.

## Admission rule

MIGMAC01 may become a production-admission candidate only after this active E2E fixture is
persisted and green. A compile-only or inactive `h<=0` fixture is insufficient.
