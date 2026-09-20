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
