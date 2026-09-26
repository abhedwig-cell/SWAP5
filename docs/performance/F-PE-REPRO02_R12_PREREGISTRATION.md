# F-PE-REPRO02 R12 — temporal state-carrier discriminator

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

R9-R11 establish:

- one serialized reference-floor physical advance on a plain committed physical state succeeds 18/18;
- the normal model-certificate transaction on a temporal-indicator committed state succeeds 7/18;
- attempt-context handling is not causal;
- corrector-backend/workspace lifetime is not causal.

R7 already showed that the inherited physical solver request surface is identical.

The strongest remaining structural difference is therefore the dynamic committed/candidate state carrier and temporal-history continuation payload.

## Question

Does the temporal-indicator state carrier itself alter the first serialized physical solve before temporal certification?

## Arms

Use a single serialized physical advance, not a retry loop, with identical mode-5 request data and 48/16/1e-10 physical controls.

### PLAIN_FLOOR

Existing R9 reference-floor arm with `fmr_b110_physical_state_t`.

### TEMPORAL_FLOOR

Construct the committed origin as `fmr_b110_temporal_indicator_state_t` with the same inherited physical fields and the same initial right-derivative authority as the normal FGC44 temporal state.

Use test-only instrumentation to admit this temporal carrier to the single physical-advance floor diagnostic while temporal certification itself remains disabled for the floor sample. No production source is changed.

The purpose is only to expose whether dynamic state type/history presence changes the physical solve.

## Cases

Six difficult PROFILE06 origins at:

- -0.001 cm;
- 0;
- +0.001 cm.

Three fresh-process repetitions per point/arm.

## Measurements

Report:

- floor status and sample validity;
- nonlinear iterations;
- backtracking attempts;
- mass completeness/residual;
- physical bottom exchange.

## Decision

If TEMPORAL_FLOOR reproduces the transaction failures while PLAIN_FLOOR stays 18/18, the temporal state carrier/history is causally implicated.

If both floor arms succeed identically, temporal carrier type/history presence is excluded from the physical convergence failure. The remaining target is then canonical checkpoint/candidate transaction cloning or pre-advance lifecycle itself.

If the diagnostic cannot isolate the carrier without changing solver-relevant request semantics, stop and report the blocker rather than infer causality.

No production `src/**` change is allowed in R12.
