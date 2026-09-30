# PPA-WU05-A4 typed outer coupling controller qualification

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_COMPONENT / REAL_RICHARDS_BOUND`

Workflow run: `36769211873`

Head: `b0957e7e7756f165b7a8a41868e52bda42c9c79b`

## Component

A typed research coupling controller now owns:

- predictor execution;
- frozen-exchange correctors;
- exchange convergence;
- damping;
- strict versus practical-cap policy;
- Richards retry/failure propagation;
- combined matrix+macropore mass reconciliation;
- return of one matrix+macropore candidate.

Macropore process physics remains in a separate typed research process component.

## Mock-contract qualification

The controller test verifies:

- strict convergence;
- practical cap reported explicitly rather than as false convergence;
- accepted macropore state isolation;
- candidate water transfer;
- combined mass closure;
- retry propagation.

## Real Richards qualification

The controller was then run against the real Reference Richards solver for the previously qualified B01 `h=-50 cm`, `dt=0.05 d` coupling case.

Observed:

- strict exchange: `1.7336720787 cm d-1`;
- previous hand-written strict reference: `1.7336720683 cm d-1`;
- practical max-3 exchange: `1.7693267011 cm d-1`;
- previous hand-written practical reference: `1.7693267011 cm d-1`;
- strict outer iterations: 21;
- practical outer iterations: 3;
- combined mass gate: PASS.

The small strict difference is below the registered comparison tolerance and reflects the exact stopping point of the typed controller; the practical route is identical to the previous result.

## Retry semantics

The known wet/fresh high-sorptivity adversarial case was rerun through the typed controller.

The real Richards solver returned retry and the controller propagated:

`PPA_COUPLED_RETRY`

without publishing a coupled candidate as accepted authority.

## Architectural conclusion

The previous hand-written research loops can now be replaced by the typed controller for subsequent A4 experiments.

The controller preserves the intended separation:

- process physics -> process component;
- Richards solve -> solver;
- damping/convergence -> coupling controller;
- timestep retry -> owning transaction/timestep layer;
- commit -> outside the controller.

## Next step

Extend the process component with source-bound crack-history and rapid-drain candidate updates and qualify those trajectories through the same typed controller.
