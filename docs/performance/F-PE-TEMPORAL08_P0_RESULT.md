# F-PE-TEMPORAL08 P0 result

Date: 2026-09-27

Status: `PASS_POLICY_DEFAULT_OFF_AND_FAIL_CLOSED`

Preregistration:

`docs/performance/F-PE-TEMPORAL08_PREREGISTRATION.md`

Harness:

`tests/fpe/run_fpe_temporal08_p0_policy.sh`

Current-head authority:

- head: `d97b607ec36457e9b9ebaf9b798b7fe672421a98`;
- workflow run: `36300393644`;
- job: `p0-policy-default-off`;
- conclusion: PASS.

## Frozen policy

`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`

## Result

O0 and O2 both pass.

Policy gates:

- floor behavior: PASS;
- history scaling: PASS;
- missing history: fail closed;
- disabled/default policy: no override.

Seeded authority example:

- dt = `1e-4 day`;
- max predecessor derivative = `400 cm/day`;
- expected budget = `0.026000000000000002 cm`.

Observed:

`TEMPORAL08_EXPECTED_BUDGET = 0.026000000000000002 cm`

## Default-off preservation

The unchanged F-GC49B registry lifecycle passes, including:

- two real FMR handles;
- handle isolation;
- same-origin trial delegation;
- release-busy fail closed;
- stale-handle fail closed;
- monotonic handles across reinitialization;
- kernel remains commit owner.

## Registry equivalence included in P0 harness

The policy-controlled arm and manually configured frozen-budget arm produce exact equality for:

- q_swap;
- integrated bottom outward exchange;
- accepted-trajectory tangent.

Observed example:

- q_swap = `-1.1272900379037450e-13 m/s`;
- tangent = `-3.9715850642542135e-06 1/s`.

The registered base canonical numerical config remains unchanged.

## Decision

P0 passes.

The policy mechanism is exact, default-off, fail-closed and transaction-owner preserving.
