# F-PE-TEMPORAL08 P1 result

Date: 2026-09-27

Status: `PASS_REGISTRY_POLICY_EQUIVALENCE`

Harness:

`tests/fpe/run_fpe_temporal08_p1_registry.sh`

Current-head authority:

- head lineage before result write: `4f0af890230e3f344bbc69abd60ca4e1e432786f`;
- production-code authority exercised by workflow run `36300393644`;
- P1 job conclusion: PASS.

## Result

O0 and O2 both pass.

The registry-bound temporal policy arm is exactly equivalent to a manually configured frozen c=0.65 budget arm from the same seeded temporal-history state.

Observed seeded budget:

`0.026000000000000002 cm`

Observed response:

- q_swap = `-1.1272900379037450e-13 m/s`;
- tangent = `-3.9715850642542135e-06 1/s`.

Exact equality holds for:

- q_swap;
- integrated bottom outward exchange;
- accepted-trajectory tangent.

The registered base `canonical_numerical_config_t` remains immutable.

## Decision

P1 passes.

The new registry policy is behaviorally identical to the previously qualified manual c=0.65 research route and does not mutate shared numerical configuration.
