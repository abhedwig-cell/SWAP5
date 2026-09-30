# PPA-WU05-A4 prescribed-state R2 result — G5 to G7

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / ALL_PRESCRIBED_STATE_GATES_PASS`

## G5 — A3 E4 crack-history regression

The R2 research harness preserved the E4 hysteresis property:

- same current theta = 0.35;
- same previous theta = 0.30;
- no crack history -> dynamic crack volume = 0;
- existing crack history -> dynamic crack volume > 0.30 cm.

Verdict: `PASS`.

This confirms the R2 design cannot derive crack state solely from current matrix moisture.

## G6 — A3 E7/R1-MSTATE02 interface regression

A moving-interface storage transition was evaluated with the universal accepted-flux reconstruction:

`Q_bottom = Q_top - Q_exchange - DeltaW/dt`.

All compartment residuals were below `1e-12 cm d-1`.

Verdict: `PASS`.

The R2 prototype therefore retains the locally conservative interface bookkeeping selected in the A3 interim R1 map.

## G7 — A3 E9 extreme-input regression

Top input was swept through:

`0, 1, 5, 10, 25, 50, 100, 250 cm d-1`.

For every case:

- macropore storage remained between 0 and capacity;
- mass residual remained below `1e-13 cm`;
- excess input became explicit overflow once storage/sink capacity was exhausted.

Verdict: `PASS`.

## Prescribed-state phase conclusion

All preregistered prescribed-state gates now pass locally:

- G1 mass closure: PASS;
- G2 candidate isolation: PASS;
- G3 reject/retry: PASS;
- G4 sorptivity memory: PASS;
- G5 crack history: PASS;
- G6 moving-interface/local conservation: PASS;
- G7 extreme-input boundedness: PASS.

Decision:

`QUALIFIED_R2_PRESCRIBED_STATE_SINGLE_COLUMN_READY_FOR_RICHARDS_COUPLING`.

This is a research qualification only. No production macropore physics is activated.

## Next step

Introduce the real SWAP5 Richards interface in the smallest possible way:

1. obtain matrix hydraulic state from the existing solver/state contract;
2. evaluate one macropore candidate from the accepted/checkpoint state;
3. feed the internal exchange into a second Richards candidate solve;
4. reconcile matrix and macropore candidate mass;
5. accept or reject atomically;
6. start with one-step cases corresponding to E2/E3 before multi-step timestep-manager work.
