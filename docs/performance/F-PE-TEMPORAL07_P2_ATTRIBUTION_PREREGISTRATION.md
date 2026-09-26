# F-PE-TEMPORAL07 P2 attribution comparator preregistration

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

## Trigger

The expanded-bracket c=0.65 live one-SWAP/one-MODFLOW-cell run reached the full independent endpoint authority.

Observed c=0.65 result:

- production coupled convergence: PASS;
- production q_swap versus q_groundwater residual: approximately 7.9e-23 m/s;
- independent endpoint head error: approximately -1.34e-12 m, within the frozen 5e-10 m endpoint-head gate;
- MODFLOW model balance: PASS;
- MODFLOW API component identity: PASS;
- stopping-flow gate: PASS;
- rejected-trial, publication-order and exactly-once mass invariants: PASS;
- independent physical residual at the production endpoint: approximately 2.74e-14 m/s.

The last quantity exceeds the frozen 1e-15 m/s physical residual gate.

That gate is not changed.

## Attribution question

Is the independent physical-residual failure specifically introduced by the frozen c=0.65 temporal policy, or does the same dynamic O14-mid coupling setup also fail with the c=0.50 comparator?

This distinction matters for causal attribution. It does not waive the c=0.65 admission gate.

## Comparator

Use exactly the same P2 harness as the c=0.65 live test:

- O14 mid, h0 = -75 cm;
- accepted dynamic history imbalance = -0.10;
- same predictor q;
- same captured origin;
- same MODFLOW 6.8.0 library;
- same pinned xmipy/flopy dependencies;
- same adaptive independent-root bracket amendment;
- same MODFLOW solver controls;
- same endpoint, physical residual, component-balance, stopping-flow, mass and publication gates.

Change exactly one quantity:

`budget = max(1e-5 cm, 0.50 * dt * ||h_dot_previous||_inf)`

No c=0.50-specific retuning is permitted.

## Measurements

Record for c=0.50:

- accepted substep/retry path;
- final production head;
- final production q_swap/q_groundwater residual;
- independent endpoint head;
- independent endpoint head error;
- independent physical residual at the production endpoint;
- MODFLOW model/component balance;
- publication/mass invariants.

## Interpretation

- If c=0.50 passes the frozen independent physical residual gate while c=0.65 fails, the P2 failure is attributable to the selected c=0.65 temporal response and TEMPORAL07 closes rejected.
- If c=0.50 also fails the same frozen gate at comparable scale, the c=0.65 failure is not attributable to coefficient selection alone. TEMPORAL07 still cannot claim admission under the current gate, but the blocker becomes a dynamic-origin endpoint-qualification issue that requires a separate workunit.
- If the comparator fails for a different reason, attribution remains unresolved.

No acceptance tolerance is changed by this comparator.
