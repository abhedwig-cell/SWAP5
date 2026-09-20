# TAB-HYD typed generated-provider research result

Date: 2026-09-20

Status: **research evidence; production implementation held**

## Question

Does the bounds-safe raw-head400 representation become a material acceleration when evaluated through SWAP5's existing vector-valued `constitutive_hydraulics_provider_t`, rather than through the legacy scalar `watcon/moiscap/hconduc` wrappers?

## Authority

- canonical contract/preimage: `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`;
- analytical provider: `src/solver/mod_b110_default_mvg_provider.f90`;
- provider ABI: `src/solver/mod_soil_water_solver_contract.f90`;
- Reference Richards implementation: canonical source at the same preimage;
- research representation: bounds-safe raw-head400 only.

No production source is changed by these experiments.

## Typed provider-only result

Runs:

- `35535155474`;
- independent post-extension rerun `35535704356`.

The research provider evaluates theta, C and K together for a vector of nodes, with preprocessing outside the timed repeated evaluation.

Post-extension rerun `35535704356` over all 30 Staring parameter rows:

- theta maximum absolute difference = `5.32098e-5`;
- C maximum absolute difference = `5.17194e-5`;
- log10(K) maximum absolute difference = `3.03816e-4`;
- analytical median = `0.261516 s`;
- table median = `0.210657 s`;
- table delta = **-19.448%**.

The earlier run gave -19.340%, so the provider-level reduction is reproducible.

Interpretation: the legacy whole-model K0 parity result is not evidence that table evaluation itself is runtime-neutral. The scalar legacy call pattern hides a substantial benefit available when theta/C/K share one typed vector-provider evaluation.

## Direct Reference Richards result

Bounds-checked workflow `35535959193` evaluates the analytical and table providers through the canonical Reference Richards solver on 32-node profiles derived from the previously selected coarse, loam and clay material/initial-head cases.

All cases converged in exactly three nonlinear iterations on both routes.

| profile label | max head difference (cm) | max theta difference | max flux difference | table runtime delta |
| --- | ---: | ---: | ---: | ---: |
| coarse_dry_free | 2.6703e-5 | 9.6316e-9 | 8.5265e-12 | **-24.53%** |
| loam_mid_free | 4.1475e-7 | 1.2978e-9 | 2.9533e-8 | **-26.96%** |
| clay_wet_free | 9.8457e-8 | 1.6984e-9 | 6.9171e-10 | **-28.37%** |
| coarse_dry_pulse | 2.6703e-5 | 9.6316e-9 | 8.5265e-12 | **-25.33%** |
| loam_capillary | 1.3989e-7 | 1.1164e-9 | 3.0523e-9 | **-30.41%** |

Mass-residual differences were of order `1e-15`.

The eight timing blocks per profile all retained a large separation between routes; this is not a sub-percent runner-noise effect.

### Scope caveat

The labels above are inherited from the transfer-envelope material/state selection, but this direct solver benchmark does **not** reproduce the complete application forcing and lower-boundary semantics of those legacy scenarios. In particular, the coarse dry/pulse profiles share the same direct-solver setup, and the direct fixture uses its own typed boundary construction.

Therefore this result establishes:

- provider fidelity inside the real Reference Richards solve;
- unchanged nonlinear iteration count in the tested profiles;
- a material solver-level K0 runtime reduction.

It does **not yet** establish whole-application speedup over the complete Hupsel/application envelope.

## Current interpretation

The original acceleration hypothesis should no longer be closed as "K0 parity".

Instead:

1. legacy scalar-wrapper route: approximately whole-model parity;
2. typed vector provider alone: about 19.4% faster;
3. typed provider inside direct Reference Richards: about 24-30% faster in the current 32-node research profiles;
4. transaction/FMR application-runtime integration: still pending at this checkpoint.

The larger solver-level percentage than the provider-only percentage can arise because the direct benchmark changes the constitutive cost composition inside a compact solver fixture. It must not be extrapolated as a whole-SWAP speedup percentage.

## Production boundary

This result still does not authorize production implementation.

A generated MvG-equivalent provider remains distinct from generic user-supplied tabulated hydraulics. A production work unit would need its own:

- typed immutable/preprocessed table ownership;
- deterministic generation/validation contract;
- opt-in provider selection;
- whole-runtime/application qualification;
- independent performance evidence;
- reference-preservation proof.

The current analytical MvG provider remains the production reference.


## Serialized Reference runtime integration

Workflow `35536380158` is the controlling integrated runtime result.

The research table provider was injected only through the existing constitutive-provider pointer in a workflow copy of the canonical serialized Reference backend. The analytical production provider, solver code, transaction policy and canonical branch were not modified.

A first diagnostic run intentionally exposed an important fixture issue: if the table route is started with water content and equilibrium flux computed by the analytical provider, the table route is constitutively inconsistent at t0 and the transaction layer rejects all attempts on the temporal full/half gate. The diagnostic was:

- attempts = 9;
- retries = 8;
- temporal rejections = 9;
- solver rejections = 0;
- mass rejections = 0;
- admission rejections = 0.

No tolerance was changed. The fixture was repaired by keeping the same initial pressure head while deriving theta and the equilibrium conductivity from the active provider, which matches normal pressure-head-based initialization semantics.

With that provider-consistent initialization, the integrated result was:

| material | max head difference (cm) | max theta difference | mass-residual delta | retries equal | nonlinear iterations A/T | table runtime delta |
| --- | ---: | ---: | ---: | --- | --- | ---: |
| coarse | 0 | 3.842e-9 | 0 | yes | 3 / 3 | **-24.92%** |
| loam | 0 | 4.430e-10 | 0 | yes | 3 / 3 | **-30.72%** |
| clay | 0 | 3.785e-10 | 0 | yes | 3 / 3 | **-26.78%** |

The paired median reductions were approximately -24.86%, -30.61% and -26.69%, respectively. One coarse timing pair was an outlier, but the coarse median still showed a large separation and the loam/clay pairs were tightly separated.

Preprocessing occurs in the warm-up/configuration path and is excluded from repeated hot-loop timing. The research backend caches immutable preprocessed table state by `parameter_set_id`, because canonical kernel configuration is invoked for each trial.

### What this proves

Within the current synthetic equilibrium fixture, the generated raw-head table provider:

- passes the real serialized Reference transaction/runtime layer;
- preserves accepted/retry semantics;
- preserves pressure-head state exactly at written double precision in this equilibrium test;
- preserves mass accounting;
- retains a material runtime reduction after transaction/runtime overhead.

### What it still does not prove

The equilibrium runtime fixture is not a dynamic application trajectory. It does not yet prove:

- whole-Hupsel speedup;
- identical retry decisions under non-equilibrium forcing;
- production robustness under the full application envelope;
- generic user-table support.

A non-equilibrium FMR trajectory with identical forcing is therefore the next K0 scientific gate before recommending a production work unit.


## Bounds-safe generated-provider requalification

After the research provider was extended to generate its 400-row representation
directly from the pinned canonical MvG authority, an intermediate branch edit
introduced duplicated imports/helpers. That mechanical merge error was
reconciled in commit
`4a7d4d52b4cdfd00519150229ba271b99b337154`.

The post-reconciliation runs are controlling for the generated-provider route.

### Provider-only

Run `35538295603`, all 30 Staring parameter rows:

- theta max abs difference: `5.32098e-5`;
- C max abs difference: `5.17194e-5`;
- log10(K) max abs difference: `3.03816e-4`;
- analytical median: `0.260065 s`;
- generated raw-head table median: `0.2106475 s`;
- delta: **-19.002%**.

This independently reproduces the earlier ~19.4% provider-level reduction.

### Reference Richards with canonical tridiagonal linear solve

Run `35538295593` used the canonical Reference-Richards nonlinear route and a
bridge to the canonical tridiagonal linear solver.

| profile | max head diff (cm) | max theta diff | nonlinear iters A/T | table delta |
| --- | ---: | ---: | ---: | ---: |
| coarse_dry_free | 5.1524e-6 | 4.2787e-9 | 4 / 4 | **-36.13%** |
| loam_mid_free | 1.5237e-7 | 4.7539e-10 | 3 / 3 | **-34.42%** |
| clay_wet_free | 1.1611e-6 | 8.7980e-10 | 4 / 4 | **-34.19%** |
| coarse_dry_pulse | 7.8383e-6 | 5.3096e-9 | 4 / 4 | **-41.15%** |
| loam_capillary | 2.2837e-7 | 7.4690e-10 | 3 / 3 | **-29.95%** |

Linear-solve counts were also identical route-by-route. Mass residual
differences were of order `1e-17`; the capillary qbot difference was
`2.92e-9`.

The speed separation therefore is not caused by fewer nonlinear iterations or
a different linear-solve count.

### Serialized Reference runtime

Post-generated-provider run `35538295619` passed with
`TYPED_RUNTIME_FIDELITY_FAILURES=0`.

Provider-consistent equilibrium fixtures:

| material | head max diff | theta max diff | iterations A/T | retries equal | table delta |
| --- | ---: | ---: | ---: | --- | ---: |
| coarse | 0 | 3.842e-9 | 3 / 3 | yes | **-28.24%** |
| loam | 0 | 4.430e-10 | 3 / 3 | yes | **-31.37%** |
| clay | 0 | 3.785e-10 | 3 / 3 | yes | **-28.49%** |

This confirms that a material reduction survives the serialized Reference
transaction/runtime layer and deterministic internal table generation.

## Dynamic fixture disposition

The attempted wetting/drying serialized fixture is **not an admissible reference
test** under the current external full/half transaction gate.

Diagnostic run `35538460638` tested analytical MvG only for coarse, loam and
clay, wetting and drying, at perturbations 1.25%, 0.625% and 0.3125%.

Every case returned:

- attempts = 9;
- retries = 8;
- solver rejections = 0;
- temporal rejections = 9;
- mass rejections = 0;
- admission rejections = 0.

Therefore the dynamic-workflow failures are reference-fixture failures, not
table-provider fidelity failures. No transaction tolerance was relaxed.

## Generic temporal-indicator characterization

TAB-HYD-005 was then tested according to
`GENERIC_TEMPORAL_INDICATOR_PREREGISTRATION.md`.

Run `35538572717` passed both phases across all five bounded profiles.

### Phase A

For analytical MvG, replacing only the concrete constitutive dispatch by the
common provider ABI reproduced the canonical temporal indicator within the
preregistered `1e-14 * max(1,abs(reference))` gate for all reported norms,
head bound and right-derivative values, with identical status, availability,
route and solve counters.

### Phase B

The generated raw-head provider produced an available finite indicator for all
five profiles. Bound-selection route matched the analytical route in every
case.

Representative analytical/table head bounds:

- coarse_dry_free: `1.3784398416 / 1.3784312240`;
- loam_mid_free: `0.7996648119 / 0.7996646097`;
- clay_wet_free: `0.6474189031 / 0.6474184467`;
- coarse_dry_pulse: `8.9622935714 / 8.9623578082`;
- loam_capillary: `1.3120751570 / 1.3120751263`.

Thus the temporal-indicator mathematics is not intrinsically tied to analytical
MvG. The remaining production blocker is an explicit solver-contract capability
for validating timestep-dependent provider context. The current common ABI
cannot generically express the existing invariant that the provider's bound
step duration matches `request%step_duration`.

See `GENERIC_TEMPORAL_INDICATOR_RESULT.md`.

## Updated interpretation

For the currently admitted K0 scientific denominator:

1. legacy scalar-wrapper table route: whole-model parity in the legacy-input
   Hupsel benchmark;
2. typed vector provider: reproducibly about 19% lower constitutive evaluation
   cost;
3. real Reference-Richards solve with canonical linear solver: about 30-41%
   lower runtime in the bounded direct-solver profiles, with unchanged iteration
   counts;
4. serialized Reference runtime equilibrium fixture: about 28-31% lower hot-loop
   runtime, with equal retries/iterations and no mass regression;
5. provider-agnostic temporal-indicator mathematics: research-qualified;
6. non-equilibrium application trajectory: still requires a reference-admissible
   fixture/continuation contract.

The acceleration hypothesis is therefore **supported for the typed K0 provider
architecture**, but production implementation remains held at the explicit
timestep-context/temporal-owner boundary and whole-application qualification.

No portable whole-SWAP or MultiSWAP speedup percentage is claimed.
