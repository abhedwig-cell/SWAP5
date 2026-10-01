# PPA-WU05-A8 closeout — canonical bounded FMR macropore admission

Date: 2026-10-01

Status: CLOSED / CANONICALLY ADMITTED

Canonical merge: `9bad713b0d2ab24d40fcf937d11c850d3fb52a22`

Admission PR: #923

Pre-admission selective qualification:
- postimage `e364f03cd247ade34a58074da37cd0dd147c31ac`
- run `36821243957` — SUCCESS

Final admission-branch qualification:
- head `287375c8b0f1c3712c0d7f32f0d739fb7e89a7fc`
- run `36821554854` — SUCCESS

Post-merge canonical preservation:
- canonical `9bad713b0d2ab24d40fcf937d11c850d3fb52a22`
- run `36821651670` — SUCCESS

## Admitted capability

The current canonical line now admits a bounded production macropore route through serialized single-column FMR:

- standard `swmbf=1` macropore formulation;
- Reference Richards only;
- immutable production macropore configuration;
- dynamic matrix/macropore hydraulic views derived from accepted state;
- outer source/sink coupling with inner Richards `macropore_active=.false.`;
- candidate-only macropore publication until kernel commit;
- discard/retry leaves committed state unchanged;
- committed persistence/restart carries the seven continuation fields;
- restart continuation reproduces the next accepted candidate in the qualified fixture;
- external full/half temporal acceptance is used;
- discrete `ICpBtDm` topology disagreement fails closed.

## Non-admitted scope

This closeout does not admit:

- perched-zone macropore physics;
- source-connected surface macropore input without separate source-faithful rain/irrigation/melt/ponding/runon forcing;
- rapid drainage in the FMR macropore route;
- dynamic crack-geometry displacement feedback inside one corrector;
- RossFast macropore execution;
- parallel/concurrent MultiSWAP macropore execution.

These remain explicit future work, not implicit capability.

## Governance closure

Lifecycle reached:

implemented -> persisted -> tested -> qualified -> admitted -> closed

The frozen Status-A review denominator is unchanged. This is a post-Status-A canonical capability.
