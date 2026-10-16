# F-PE-TEMPORAL04 closeout — oracle-based dynamic temporal-policy qualification

Date: 2026-09-26

Status: `CLOSED_PHYSICAL_PASS_PERFORMANCE_REJECT`

## Question

Can a history-aware temporal head budget derived from the exact origin predecessor derivative provide both robust completion and acceptable oracle error at practical cost?

## Candidate

`HIST_HALF = max(1e-5 cm, 0.5 * dt * ||h_dot_previous||_inf)`

was the only P0 candidate advanced to bounded qualification.

## Findings

### Physical qualification

PASS.

Across 48 difficult dynamic-history corrector points, repeated three times:

- 48/48 complete;
- max terminal head error versus refined oracle: 6.565e-3 cm;
- max water-content error: 6.427e-6;
- max relative terminal-flux error: 0.72%;
- max relative integrated-exchange error: 0.17%.

These satisfy the preregistered P1 envelope.

### Performance qualification

FAIL.

HIST_HALF incurs exactly one temporal rejection/retry on every one of the 48 points.

Against the direct-accept FIXED_0P2 benchmark:

- median repeated-trial runtime ratio = 2.286;
- range = 2.150 to 2.353;
- HIST_HALF temporal rejections = 48;
- FIXED_0P2 temporal rejections = 0;
- no solver rejection occurs in either arm.

## Scientific interpretation

The current temporal defect certificate presents a real performance/accuracy frontier.

The natural half-history scale is conservative enough to remain within a tight oracle error envelope, but too strict to avoid temporal subdivision.

A looser policy can remove the retry and approximately halve trial cost, but the P0 looser candidates exceed the fixed P1 head/theta bounds.

This is a genuine multi-objective trade-off, not a solver defect and not a reason to move the preregistered bounds after seeing the result.

## Decision

TEMPORAL04 closes without policy admission.

No production temporal-budget change is made.

No surrogate is reopened.

## Recommended successor

`F-PE-TEMPORAL05 — blinded temporal accuracy/performance Pareto frontier`

The successor should:

- preregister a coefficient family between the half-history and direct-accept regimes;
- use a calibration subset only to identify the Pareto knee;
- freeze the selected coefficient before evaluation;
- validate blindly on held-out materials/history directions and/or displacement magnitudes;
- retain the recovered fixed-substep oracle as independent error authority;
- report physical error and runtime jointly rather than changing acceptance bounds post hoc.
