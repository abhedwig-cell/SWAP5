# F-PE-REPRO02 R4 — legacy-context binding A/B test

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

R1-R3 localized the rejection to the nonlinear solver and ruled out:

- temporal acceptance;
- max nonlinear iterations;
- max backtracking;
- minimum-step duration.

The successful P0 direct-solver route does not call:

`bind_b110_serialized_legacy_context(request, ok)`

before solving.

The serialized participant does.

## Question

Does applying the serialized legacy-context binding to the otherwise unchanged P0 direct request reproduce the difficult-origin failure?

## Arms

For each case/offset:

- DIRECT: existing P0 request and solve;
- BOUND: same request, then `bind_b110_serialized_legacy_context`, then the same solve.

No other request field changes are allowed.

## Cases

The six difficult PROFILE06 origins.

Offsets:

- -0.001 cm;
- 0;
- +0.001 cm.

Use 48 nonlinear iterations, 16 backtracking and 1e-10 day minimum step as in the successful P0 characterization.

## Decision

If DIRECT passes and BOUND reproduces the participant retry-advised failures, the first causal divergence is legacy-global context binding.

If both behave identically, R5 must compare remaining serialized request/provider state directly.
