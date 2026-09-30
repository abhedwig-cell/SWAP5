# PPA-WU05-A4 local strict-versus-practical multi-step trajectory screen

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / THREE_CORRECTOR_TRAJECTORY_SCREEN_SUPPORTED`

## Purpose

Test whether the one-step error observed for fixed corrector counts accumulates catastrophically over repeated accepted macropore/matrix exchange steps.

This is a reduced local screening model, not a real-Richards qualification.

## Routes

- **strict**: damped fixed-point iteration to exchange convergence;
- **practical3**: at most three exchange iterations per step;
- **one**: one exchange estimate per step, retained as a negative-control practical route.

All routes use identical accepted-history updates.

## Trajectories

Twelve-step trajectories with repeated small macropore recharge were screened for:

1. mild coupling;
2. wet/strong coupling;
3. dry/strong coupling.

## Final-state differences versus strict

### Mild

Three-corrector route:

- cumulative exchange absolute error: `2.31e-4 cm`;
- theta absolute error: `1.26e-5`;
- macropore-storage absolute error: `4.99e-6 cm`.

One-corrector route:

- cumulative exchange absolute error: `7.67e-4 cm`;
- theta absolute error: `4.17e-5`.

### Wet/strong

Three-corrector route:

- cumulative exchange absolute error: `7.21e-4 cm`;
- theta absolute error: `3.92e-5`;
- macropore-storage absolute error: `8.24e-6 cm`.

One-corrector route:

- cumulative exchange absolute error: `2.97e-3 cm`;
- theta absolute error: `1.61e-4`.

### Dry/strong

Three-corrector route:

- cumulative exchange absolute error: `5.43e-3 cm`;
- theta absolute error: `2.95e-4`;
- macropore-storage absolute error: `5.43e-3 cm`.

One-corrector route:

- cumulative exchange absolute error: `2.29e-2 cm`;
- theta absolute error: `1.24e-3`;
- macropore-storage absolute error: `2.29e-2 cm`.

## Interpretation

In this reduced multi-step screen:

- three correctors do not show unstable error accumulation;
- one corrector remains systematically worse;
- the strongest dry trajectory retains the largest practical error, but the three-corrector route is about four times closer to strict than the one-corrector route.

This supports, but does not yet qualify, the current practical candidate:

`adaptive early-stop with maximum three outer correctors`.

## Next step

Run one real-Richards short trajectory comparing:

- strict converged/damped coupling;
- adaptive maximum-three-corrector coupling.

The real test should update the accepted matrix state and macropore event history between steps.

One-corrector need not be promoted beyond negative control unless a later performance study specifically requires it.
