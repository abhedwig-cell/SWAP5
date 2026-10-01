# F-PE-MIQUAL07 closeout — production-shaped serialized runtime benchmark

Date: 2026-10-01

Final status:

`MIQUAL07_DYNAMIC_REFERENCE_BLOCKED`

MIQUAL07 is closed according to the frozen stop rule.

The equilibrium serialized benchmark is positive and exact:

- 4,000 committed intervals;
- 100% reduced manager route;
- zero fallback/bypass;
- exact full-state final equivalence;
- deterministic work ratio 0.8125.

The preregistered dynamic workload is not a valid LEGACY transaction reference. It is rejected by the outer temporal transaction before the first committed interval despite converged underlying solver attempts.

Therefore:

- no benchmark retuning is allowed inside MIQUAL07;
- no paired wall-clock performance qualification is claimed;
- no manager failure is inferred.

Direct successor:

`F-PE-MIQUAL08 — serialized dynamic reference-workload acquisition`.

MIQUAL08 must search existing repository-backed serialized-reference fixtures first. It should not invent a new forcing/tolerance combination by trial-and-error.

Target:

identify one or more already valid dynamic serialized workloads inside the bounded MIQUAL06 manager envelope, then freeze them before any LEGACY/MANAGER timing exposure.

Production boundary unchanged:

- moving-interface manager explicit opt-in;
- `LEGACY_NUMERICS` remains production default.
