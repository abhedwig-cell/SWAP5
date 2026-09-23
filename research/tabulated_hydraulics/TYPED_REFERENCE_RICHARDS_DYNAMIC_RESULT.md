# TAB-HYD typed dynamic Reference Richards result

Date: 2026-09-23

Status: **qualified research solver evidence; no production admission**

## Authority and protocol

- current relevant canonical blobs are unchanged through `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`;
- preregistered protocol: `TYPED_REFERENCE_RICHARDS_DYNAMIC_PREREGISTRATION.md`;
- research-only table provider behind the existing `constitutive_hydraulics_provider_t` seam;
- canonical Reference Richards, K0, numerical tolerances, residual, retry and state ownership unchanged;
- workflow run `35900988596`: **success**.

## Dynamic trajectory fidelity

Each material followed the same 16-step predeclared non-equilibrium flux sequence from h=-75 cm.

| material | head max abs (cm) | head RMSE (cm) | theta max abs | native mass diff max | integrated mass diff max |
| --- | ---: | ---: | ---: | ---: | ---: |
| B4 | 7.01e-6 | 3.32e-6 | 3.81e-9 | 8.88e-16 | 1.11e-16 |
| B9 | 9.46e-7 | 4.91e-7 | 7.15e-10 | 1.33e-15 | 1.67e-16 |
| B12 | 4.72e-6 | 2.78e-6 | 3.61e-9 | 6.66e-16 | 8.33e-17 |
| O13 | 1.16e-6 | 7.26e-7 | 3.97e-10 | 1.78e-15 | 2.22e-16 |

All preregistered fidelity and mass gates passed by large margins.

## Numerical-work identity

For every material the analytical and table routes required exactly the same total nonlinear iterations
and linear solves over the 16 accepted steps:

| material | nonlinear analytical/table | linear analytical/table |
| --- | ---: | ---: |
| B4 | 77 / 77 | 77 / 77 |
| B9 | 62 / 62 | 62 / 62 |
| B12 | 55 / 55 | 55 / 55 |
| O13 | 51 / 51 | 51 / 51 |

The speed result is therefore not caused by fewer Newton iterations or a different solve path.

## Dynamic solver performance

Eight balanced repeated trajectory rounds gave:

| material | analytical median (s) | table median (s) | table delta |
| --- | ---: | ---: | ---: |
| B4 | 0.032332 | 0.022236 | **-31.23%** |
| B9 | 0.0273185 | 0.018727 | **-31.45%** |
| B12 | 0.0251465 | 0.017567 | **-30.14%** |
| O13 | 0.023787 | 0.016626 | **-30.10%** |

Thus the raw-head400 typed provider reduces runtime by about 30-31% for this bounded non-equilibrium
Reference-Richards workload while preserving the numerical work count and trajectory to very small error.

## Current scientific interpretation

The acceleration hypothesis is now supported at three increasingly integrated levels:

1. typed constitutive provider: about **-19.3%**;
2. equilibrium canonical Reference-Richards solve: about **-28 to -29%**;
3. preregistered non-equilibrium canonical Reference-Richards trajectories: about **-30 to -31%**.

This is strong evidence that the current vector-valued SWAP5 provider architecture can exploit tabulation
far better than the historical scalar `SWSOPHY=1` call path.

It is still not a full SWAP application-speed claim. The next controlling experiment is application-level
timing through the existing typed Hupsel/legacy-adapter route, with no provider-selection change admitted to
canonical production.
