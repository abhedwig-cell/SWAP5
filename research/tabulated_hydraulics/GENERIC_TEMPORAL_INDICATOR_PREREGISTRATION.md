# TAB-HYD provider-agnostic temporal-indicator preregistration

Date: 2026-09-20

Status: **preregistered research experiment; no production implementation**

## Research question

Can the current Reference-Richards temporal-indicator algorithm be separated from the concrete `b110_default_mvg_provider_t` type without changing any analytical-MvG result, so that a second constitutive provider can at least be characterized behind the existing provider ABI?

This experiment addresses TAB-HYD-005. It does not admit a generic production temporal certificate.

## Frozen source authority

- canonical preimage: `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`;
- current indicator: `src/solver/mod_reference_richards_temporal_indicator.f90`;
- current provider ABI: `src/solver/mod_soil_water_solver_contract.f90`;
- current analytical provider: `src/solver/mod_b110_default_mvg_provider.f90`;
- research table provider: bounds-safe raw-head400 typed provider only.

## Research-only code change

The candidate may change only the constitutive dispatch inside the temporal indicator:

1. preserve the existing concrete analytical-provider `step_duration == request%step_duration` check exactly;
2. for the analytical provider, evaluate the same provider at the same base and candidate heads;
3. move the two provider evaluations through the common abstract `constitutive_hydraulics_provider_t%evaluate` call path;
4. permit a non-analytical provider to reach the existing mathematical indicator calculation.

No other formula, boundary restriction, source/sink policy, linear algebra, normalization, route selection, tolerance or transaction code may change.

Because the common provider ABI has no generic step-duration validation method, a non-analytical result is **research characterization only** even if numerically successful.

## Phase A — analytical equivalence gate

Use the same five 32-node profiles already used by the typed Reference-Richards benchmark.

For each profile:

- solve with the canonical analytical provider;
- evaluate the temporal indicator with the original canonical implementation;
- evaluate the same solve result/request with the generic-dispatch research implementation.

Required equality:

- identical indicator status;
- identical `available`;
- identical route string;
- identical additional nonlinear/tridiagonal solve counters;
- absolute differences in `raw_m_norm`, `defect_m_norm`, `bounded_m_norm`, `head_inf_bound` and `min_mass_weight` <= `1e-14 * max(1,abs(reference))`;
- current-right-derivative vector equal within the same scaled tolerance.

Any analytical failure blocks Phase B.

## Phase B — table characterization

Only if Phase A passes:

- solve the same profile with the bounds-safe raw-head400 table provider;
- evaluate its temporal indicator with the generic-dispatch research implementation;
- require the indicator to be available rather than `constitutive-policy-deferred`;
- compare indicator values against the analytical route descriptively;
- do not use this phase to alter transaction tolerances or claim production equivalence.

The goal is to determine whether the mathematical indicator remains numerically well-behaved for the table provider, not to force equality between two different constitutive approximations.

## Decision rule

- Phase A fails: genericization is rejected; TAB-HYD remains blocked at the temporal-indicator owner boundary.
- Phase A passes but Phase B is unavailable/unstable: generated table acceleration remains solver/equilibrium-runtime research only.
- Both phases pass: open a separate solver-contract/temporal-indicator architecture work unit. Do not production-admit TAB-HYD directly.

The production design still requires an explicit generic contract for timestep-context validation.
