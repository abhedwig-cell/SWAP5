# PPA-WU05-A4 closeout — typed R2 single-column coupling controller

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_CONTROLLER_PHASE_COMPLETE`

## Qualified in A4

A4 now provides a research-only typed architecture for coupled matrix/macropore execution with:

- A2 seven-field continuation state;
- source-shaped sorptivity event memory;
- source-bound crack hysteresis;
- explicit rapid-drain external ownership;
- predictor/corrector Richards coupling through the existing source/sink ABI;
- strict converged and practical max-three coupling policies;
- bounded under-relaxation;
- solver retry propagation to the timestep owner;
- combined matrix + macropore mass reconciliation;
- accepted-state multi-step continuation.

## Key evidence

- fixed exchange real Richards: run 36764661597;
- dynamic predictor/corrector: run 36765169021;
- bounded Picard: run 36765412541;
- adversarial coupling characterization: run 36766001665;
- timestep/damping stabilization: run 36766340685;
- strict/practical converged trajectory: run 36767379536;
- typed controller mock + compile qualification: run 36769040494;
- typed controller bound to real Richards: run 36769211873;
- crack + rapid through controller: run 36769705960;
- accepted-state crack/rapid trajectory: run 36770067804.

## Scientific conclusions

1. Macropore/Richards exchange can be coupled outside the Richards Newton Jacobian in the tested regimes.
2. Outer fixed-point coupling can be strong, oscillatory or trigger solver retry, so a single unconditional corrector is not general.
3. Damping and timestep retry are sufficient stabilization mechanisms in the tested adversarial cases.
4. A max-three-corrector practical route is a supported research candidate, with ~1.15% cumulative exchange deviation in the qualified six-step real-Richards comparison.
5. Crack and sorptivity history are genuine continuation state.
6. Rapid drainage is an external accepted flux and must not be folded into internal matrix/macropore exchange.
7. The typed controller can return one coupled candidate or propagate retry without mutating committed state.

## Production status

`NOT_ADMITTED`.

The implementation remains under `research/macropore/` and no production macropore physics route is activated.

## Follow-on

The next research phase should complete the **process-composition surface** rather than further refine the controller.

Priority order:

1. exact/source-bound top-input partition and excess redistribution;
2. full multi-compartment/multi-domain exchange and storage geometry;
3. moving domain-bottom/drain topology;
4. exact local accepted flux reconstruction over the full domain;
5. restart/replay and preservation with all active process pieces together;
6. only then evaluate production-shaped integration and MultiSWAP/parallel ownership.

This follow-on is designated PPA-WU05-A5.
