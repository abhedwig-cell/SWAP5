# F-GC23 Whole-Window Response Tangent and One-Corrector Composition Audit

## Decision

`BLOCKED_BY_UPSTREAM_WHOLE_WINDOW_SENSITIVITY_CAPABILITY`

F-GC23 cannot truthfully qualify a production whole-window `dh_bottom/dq_bottom` response on the audited current canonical. The available production sensitivity is intentionally and explicitly scoped as `LOCAL_TERMINAL`. No production source is changed by this workunit.

This is a semantic and numerical-capability boundary, not a missing rename or missing field copy.

## Audited authority

Current canonical:

`integration/f-ci-canonical@379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b`

tree:

`556221f62b4fde616981499eba68ef5460f5d83c`

Parent completion audit:

`work/f-gc28-groundwater-coupling-v1-completion-audit@4e7da5fd014c0eb799c6637a07dfd2f3e3c487c9`

Program authority:

`regie/f-rg03-post-ci59p-program-rebaseline@aac2644149dda47282a25a39892c6dc808323dd0`

Primary sensitivity authorities:

* F-SI28 `work/f-si28-interface-sensitivity-production-solve@5b514e678d0d794e5837f161033b0bac58385707`
* F-SI32 `work/f-si32-scoped-interface-sensitivity-reconciliation@dfe1a285ae485e1e8348ee10492bb7808f85dd39`
* F-CI56 predictor-corrector closeout `c19a04721a05c6a00ba264e7477969807dcb258f`

## What is already qualified

F-SI28 qualifies an optional same-factorization native-qbot sensitivity for the prescribed-bottom-flux Full Richards route. The numerical primitive solves

`J * (partial h / partial qbot) = e_N`

from the accepted local linearization. Its normal accepted path costs one additional tangent backsolve, zero additional nonlinear trajectories and zero additional Jacobian builds. Sensitivity ON/OFF leaves state, flux and mass outputs bitwise identical in the qualified scope.

The production B1.10 adapter requests this sensitivity only on the qualified smooth surface-flux route. Its source comment explicitly calls it the `local qbot tangent`. Retry, failure and unsupported routes publish no sensitivity.

The transaction layer then publishes accepted sensitivities under the only admitted non-empty semantic:

`TX_INTERFACE_SENSITIVITY_LOCAL_TERMINAL`

with provenance `origin_t0`, `origin_t1` and `covers_requested_interval`.

The canonical runtime transports only the final accepted transaction's local-terminal sensitivity. When multiple accepted transaction substeps are required, it does not compose their sensitivities. It explicitly forces requested-interval coverage false unless exactly one accepted transaction produced the final sensitivity.

The kernel copies that structured result without changing its semantic classification.

This is correct fail-closed transport.

## Why `covers_requested_interval` is not enough

F-SI32 explicitly freezes the distinction between temporal coverage and derivative scope.

`covers_requested_interval = true` means only that the accepted solve segment that produced the local-terminal value has the same temporal endpoints as the requested interval. It does not convert `LOCAL_TERMINAL` into any of:

* a derivative of a sequence of accepted substeps;
* a derivative of the full canonical interval;
* a derivative of the groundwater coupling window;
* a coupled SWAP-groundwater residual Jacobian.

This remains true for a single transaction spanning the requested interval. The current producer response is still defined by the terminal accepted solver linearization, not by a separately qualified trajectory sensitivity contract.

## Missing mathematical capability

For a coupling window containing one or more physical soil-water steps, a true endpoint/window response to a window-level boundary perturbation generally requires propagation of perturbations through the state-transition sequence. Schematically, for states `x_k` and boundary control `q`,

`x_{k+1} = F_k(x_k, q)`

requires propagation such as

`dx_{k+1}/dq = (dF_k/dx_k) * dx_k/dq + dF_k/dq`.

The currently exposed scalar terminal `dh_bottom/dq_bottom` does not contain the state-transition derivative needed to build that chain across multiple accepted substeps. Averaging, summing or rescaling local terminal scalars would therefore be a new unqualified numerical model.

The RossFast research construction that used `n_substeps * local_terminal_tangent` is explicitly research-only under F-SI32 and is not evidence for adaptive, nonuniform or production coupling windows.

## Why F-GC23 does not implement around the gap

Three tempting shortcuts are rejected:

1. **Relabel LOCAL_TERMINAL as WHOLE_WINDOW.** This directly violates F-SI32 and would create a false physical/numerical claim.
2. **Use `covers_requested_interval=true` as a semantic upgrade.** F-SI32 explicitly forbids that interpretation.
3. **Require +dq/-dq full-window reruns as the production tangent.** Finite differences remain valid reference/fallback evidence, but making them structural would violate the bounded coupling-cost architecture and the frozen intent that production should not require 6-9 full SWAP trajectories per coupling window.

The existing F-GC21 predictor-corrector remains valid without tangent consumption. F-GC23 therefore leaves that production path untouched rather than weakening correctness.

## Cross-owner dependency

A true whole-window capability cannot be created solely inside the groundwater coupler from the currently exposed scalar local response.

The minimal dependency is upstream and spans two ownership layers:

1. **Soil-water solver capability:** establish a mathematically explicit, optional trajectory/window sensitivity primitive sufficient to propagate the effect of bottom-boundary forcing through accepted soil-water state transitions. Full Richards should preferably reuse accepted Jacobian/factorization information. Alternative solvers must remain allowed to return unavailable.
2. **Transaction/runtime/kernel composition:** add a separately named whole-window sensitivity semantic and prove accepted-route composition, retry/rollback safety, exact `[t0,t1]` provenance and fail-closed publication. A local-terminal value must never be promoted implicitly.

Only after those two capabilities are independently qualified and admitted can F-GC23 be reopened to consume the true whole-window response in the coupling algorithm.

## Required properties of the upstream capability

The future capability must satisfy all of the following:

* distinct machine-readable semantic from `LOCAL_TERMINAL`;
* exact committed-origin and accepted `[t0,t1]` provenance;
* no rejected, retry or stale sensitivity publication;
* no modification of committed physical state by sensitivity evaluation;
* mass result unchanged and hard mass conservation retained;
* optional/fail-closed availability for alternative solvers and nonsmooth routes;
* no dependence on HeadCalc arrays in the coupling layer;
* preferably same-Jacobian/factorization reuse or another bounded-cost method;
* finite-difference whole-window runs only as oracle/reference/fallback, not mandatory normal production cost;
* explicit diagnostics for method, additional backsolves/linear solves and availability/fallback;
* generic time and non-calendar-aligned windows;
* deterministic behavior compatible with MultiSWAP worker ownership.

## Effect on F-GC23 and G05

F-GC23 status: **not qualified**.

The F-GC28 G05 closure chain remains blocked at its first sensitivity obligation. No downstream G05 work may claim that this sensitivity obligation is closed merely because local-terminal transport exists.

This negative qualification does not invalidate F-GC21 predictor-corrector, F-GC20 tile aggregation, F-GC22 temporal/application accuracy or the existing exact groundwater mass ledger. Those capabilities retain their existing authorities and scopes.

## Mass conservation

No mass path is changed by F-GC23. The accepted bottom-interface transfer remains the exact accepted candidate transfer and groundwater pairing remains exact opposite-sign under the existing coupling contract.

Sensitivity availability, absence or future approximation can never authorize mass tolerance or missing water.

Result:

`MASS_CONSERVATION_HARD_UNCHANGED`

## Production impact

* production source changed: **NO**
* Full Richards physics changed: **NO**
* common solver contract changed: **NO**
* kernel transaction semantics changed: **NO**
* frozen denominator changed: **NO**
* new MODFLOW assumption: **NO**
* whole-window tangent admitted: **NO**
* one-corrector production path modified: **NO**
* structural finite-difference production reruns introduced: **NO**

The architecture audit is recorded in `integration/f-gc/F-GC23_ARCHITECTURE_AUDIT.json`.
