# TAB-HYD typed Reference Richards integration result

Date: 2026-09-23

Status: **qualified research integration evidence; no production admission**

## Question

Does the provider-level raw-head400 speed reduction survive when the provider is called by the
actual canonical Reference-Richards solver through the existing
`constitutive_hydraulics_provider_t` request seam?

## Authority and implementation boundary

- canonical solver/reference source: `bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`;
- canonical Reference-Richards solver and headcalc;
- canonical analytical MvG provider;
- unchanged solver residual, tolerances, state ownership and retry semantics;
- research-only raw-head provider behind the same request-level constitutive seam;
- no production Task-2 provider selection change;
- no legacy `SWSOPHY=1` input path.

Workflow:

- `TAB-HYD typed Reference Richards integration`;
- successful run `35900662982`.

## Integrated fidelity result

Four contrasting Staring materials were evaluated:

- B4 coarse sand;
- B9 loam;
- B12 heavy clay;
- O13 clay subsoil.

For twelve uniform equilibrium heads from -2 to -10000 cm:

- maximum accepted-head drift from the supplied equilibrium state: **0** for every material;
- maximum analytical/table input theta difference:
  - B4: `1.0514e-8`;
  - B9: `8.9205e-9`;
  - B12: `6.0738e-9`;
  - O13: `6.1807e-9`.

Both providers therefore completed the same canonical Reference-Richards equilibrium solve
without a state change at this written numerical resolution.

## Integrated performance result

Ten balanced timing rounds, each repeatedly exercising the full canonical solver call:

| material | analytical median (s) | raw-head table median (s) | delta |
| --- | ---: | ---: | ---: |
| B4 | 0.0394075 | 0.0277785 | **-29.51%** |
| B9 | 0.0398815 | 0.0285430 | **-28.43%** |
| B12 | 0.0386775 | 0.0276165 | **-28.60%** |
| O13 | 0.0398805 | 0.0282075 | **-29.27%** |

The direction and magnitude are consistent across all four materials.

## Interpretation

The earlier legacy-wrapper K0 whole-Hupsel parity was not representative of the current SWAP5
provider architecture.

At the vector-valued provider boundary, raw-head400 was about 19.3% cheaper than analytical MvG.
When exercised inside the canonical Reference-Richards solver on equilibrium solves, that advantage
survives and becomes a roughly 28-29% reduction for this bounded solver workload.

This result is stronger than a provider microbenchmark but is still not a full application-speed claim.
The tested solves are equilibrium/low-iteration cases, so constitutive evaluation represents a large
fraction of total solve cost.

## Next required gate

Before any production-provider work unit is opened, run a preregistered **non-equilibrium multi-step
Reference-Richards trajectory** with:

- identical forcing for analytical and raw-head providers;
- changing pressure-head states;
- multiple nonlinear iterations where naturally required;
- accepted-state head/theta comparison;
- native/integrated mass residual comparison;
- nonlinear-iteration and linear-solve counts;
- balanced repeated runtime.

The candidate must remain fixed. No knot, tolerance or solver-policy changes may be made in response
to the trajectory benchmark.

Only after that gate may the workstream decide whether the K0 acceleration case is strong enough to
justify a separately governed production-provider implementation slice.
