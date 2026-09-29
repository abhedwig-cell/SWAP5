# F-PE-ELASTIC01 Phase-A corrected legacy-ELAS result

Date: 2026-09-29

Status: INITIAL_SCREEN_RECORDED_NO_ADMISSION

Authority at experiment branch creation:
`integration/f-ci-canonical@044e686d1899adf3a631716d09743aa4fce0818f`

Corrected experiment workflow:
Actions run `36518031446`, job `109244592843`, PASS.

## Source-authority correction

Direct inspection of the byte-verified corrected B1.10 `MOD_MvG_functions.f90` confirms:

- `sw_use_elas` selects user-supplied elasticity;
- `cofgen(24,node) -> elas(node)`;
- default MvG at `h >= 0`: `theta = theta_s + h * ELAS`;
- default MvG at `h >= 0`: `C = ELAS`;
- elasticity OFF uses the separate numerical fallback `C = dt * 1e-7`.

The earlier capacity-floor-only development screen is superseded and is not evidence about ELAS.

## Corrected screening result

The current SWAP5 ELAS-off route is the comparison reference. The corrected test-only provider implements the exact positive-head B1.10 ELAS semantics and carries the coefficient in `cofgen(24)`.

Strict gate counts on the 16 preregistered screening cases:

| ELAS | strict passes | non-passes |
|---:|---:|---|
| 0, diagnostic ELAS-on | 15/16 | 1 runoff |
| 1e-8 | 14/16 | 1 runoff, 1 ponding |
| 1e-7 | 14/16 | 1 runoff, 1 nonconvergence |
| 1e-6 | 11/16 | 3 head, 1 runoff, 1 nonconvergence |
| 1e-5 | 11/16 | 2 head, 3 runoff |

These are strict trajectory-equivalence gates against an ELAS-off physical reference. A non-pass therefore does not by itself mean the ELAS physics is wrong. It means the candidate materially changes the Reference trajectory beyond the preregistered comparison tolerance or fails numerically.

## Pim Dik candidate: ELAS = 1e-6

Five of 16 screening cases do not pass the strict Reference gate:

- `B01/WET`: bottom-head delta `-2.4366e-3 cm`; deterministic work unchanged.
- `B01/POND`: runoff delta `-1.07074e-2 cm`, storage delta `+1.07074e-2 cm`; deterministic work `313 -> 212` (32.27% less), but this is coupled to a real physical storage redistribution and cannot be admitted as a pure speed gain.
- `B12/MOIST`: top-head delta `+1.9389e-3 cm`; runoff/storage redistribution about `5.53e-6 cm`; work unchanged.
- `B12/WET`: top-head delta `-2.5498e-3 cm`; runoff/storage redistribution about `1.21e-5 cm`; work unchanged.
- `O05/POND`: nonconvergence at the configured minimum timestep.

The remaining 11 screening cases pass the frozen strict gates.

## Interpretation

The corrected experiment falsifies the idea that `1e-6` can presently be treated as a transparent numerical regularizer. It is actual saturated storage physics and therefore changes state and flux partitioning when positive heads occur.

The result does **not** falsify ELAS = 1e-6 as a physical parameter. The strict reference is ELAS-off, so physically expected differences are intentionally visible. The next question is whether the added storage is physically justified and whether its appropriate magnitude is soil dependent.

The numerical response is also soil/regime dependent. In particular, O05/POND shows non-monotone robustness across the tested coefficients, while B01/POND becomes substantially cheaper at 1e-6 with a corresponding physical runoff-to-storage redistribution.

## Architecture implication

The legacy authority already answers the ownership question: ELAS is a per-soil/per-layer constitutive input in `cofgen(24)`. A future production restoration should therefore place it in typed soil-hydraulic parameter authority, not in `soil_water_numerical_config_t`.

A later soil-driven rule may derive ELAS from soil descriptors, but the runtime owner should remain the soil/material parameter set.

## Next preregistered step

Now that the initial logarithmic screen is recorded, bracket refinement is allowed.

Next work:

1. characterize the ELAS-sensitive saturated cases without opening the four frozen BOFEK holdouts;
2. refine the coefficient grid around `1e-6` for B01, B12 and O05 wet/ponding screening regimes;
3. separate physical storage response from nonlinear-work response;
4. derive candidate soil predictors only after that response surface is available;
5. freeze any soil-dependent rule before opening holdout cases.

No production admission or default change follows from Phase A.
