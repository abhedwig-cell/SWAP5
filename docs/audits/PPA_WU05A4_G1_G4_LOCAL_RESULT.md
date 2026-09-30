# PPA-WU05-A4 prescribed-state R2 result — G1 to G4

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / G1_G4_PASS / NOT_YET_RICHARDS_COUPLED`

## Prototype

A first R2 candidate-step prototype was implemented locally with immutable input states and three explicit outputs:

- candidate matrix state;
- candidate macropore state;
- mass receipt.

The prototype uses the A3 source-shaped sorptivity relation and finite macropore storage, but still takes matrix hydraulic state as prescribed input rather than calling the Richards solver.

## G1 — one-step two-reservoir mass closure

Initial matrix theta: `0.16`.

Initial macropore storage: `0.7 cm`.

Top macropore input: `0.2 cm d-1`.

Step duration: `0.1 d`.

Observed:

- matrix storage gain: `0.1023181313 cm`;
- macropore storage change: `-0.0823181313 cm`;
- top input amount: `0.0200000000 cm`;
- rapid drainage: 0;
- overflow: 0;
- residual: `~1.4e-16 cm`.

Therefore internal exchange is exactly conservative to roundoff.

Verdict: `PASS`.

## G2 — candidate isolation

The prototype receives immutable committed-like input records and returns a separate candidate.

After trial evaluation:

- original matrix theta remains unchanged;
- original macropore storage/history remains unchanged.

Verdict: `PASS`.

## G3 — reject/retry

A clean candidate was generated.

A second identical candidate was generated and discarded.

Retry from the original accepted state reproduced the clean candidate exactly.

Verdict: `PASS`.

## G4 — A3 E3 sorptivity-memory regression

Two states with identical current matrix theta and macropore storage but different admissible sorptivity history were evaluated under identical forcing.

Fresh-event candidate:

- matrix gain `0.1023181313 cm`;
- next theta `~0.165561`.

Aged-event candidate:

- matrix gain `0.0225773599 cm`;
- next theta `~0.161227`.

The fresh event transfers more than four times as much water to the matrix, reproducing the A3 E3 memory property.

Verdict: `PASS`.

## Interpretation

The first coupled R2 object can already express the key architecture correctly:

`accepted state -> pure candidate evaluation -> mass receipt -> later accept/reject`.

Internal matrix/macropore exchange is represented once and cancels exactly at the combined-system level.

## Next step

Extend the same candidate-step harness with:

- E4 crack-history regression;
- E7 moving-interface/local-flux reconstruction;
- E9 extreme-input boundedness.

If G5-G7 also pass, the prescribed-state R2 phase can be considered ready for a real Richards adapter.
