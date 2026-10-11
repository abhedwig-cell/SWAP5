# PUB-GC E3-D result — predictor-envelope diagnosis

## Status

**PREDICTOR ENVELOPE DIAGNOSED — STAGE 104 BOUNDARY**

Date: 2026-09-18.

Workflow run: `35343968268`.

Preregistration:

`PUB_GC_E3D_PREDICTOR_ENVELOPE_PREREGISTRATION.md`

All 21 prespecified predictor-only cases were executed.

## Result

Fourteen predictor cases were ready and seven failed. Every failure had exactly the same stage code:

```text
104 = PREDICTOR_WHOLE_WINDOW_TRIAL_INCOMPLETE
```

No failure occurred in:

- accepted-trajectory tangent endpoint construction;
- bottom-face mapping;
- interface flux conversion;
- predictor-response assembly;
- cell-response aggregation;
- MODFLOW linear-term composition;
- participant origin capture;
- ledger setup.

The higher-flux blocker is therefore upstream of the coupling/interface machinery: the real SWAP predictor does not complete the requested whole-window trial.

## Window-dependent boundary

| coupling window | largest successful predictor flux | smallest failed predictor flux |
| ---: | ---: | ---: |
| `1e-4 day` | `3e-5 cm/day` | `1e-4 cm/day` |
| `1e-3 day` | `1e-4 cm/day` | `3e-4 cm/day` |
| `1e-2 day` | `1e-4 cm/day` | `3e-4 cm/day` |

Thus the original E3 jump from `1e-6` directly to `1e-3 cm/day` skipped a substantial valid interval.

The valid predictor envelope is also window-dependent: the shortest window rejects `1e-4 cm/day`, while both longer windows accept it.

## Successful predictor response

All successful cases retained complete canonical mass accounting. Storage change remained at zero or double-precision round-off because E3-D preserved equal top and bottom forcing.

Selected response coefficients:

| window | q predictor | u | q_u |
| ---: | ---: | ---: | ---: |
| 0.0001 | 0.000001 | 3.40293604e-5 | -9.65885212e-7 cm/day |
| 0.0001 | 0.00003 | 3.40293655e-5 | -2.89765580e-5 cm/day |
| 0.001 | 0.000001 | 2.68610643e-4 | -7.64218994e-7 cm/day |
| 0.001 | 0.00003 | 2.67244942e-4 | -2.27885842e-5 cm/day |
| 0.001 | 0.0001 | 2.66574371e-4 | -7.57381017e-5 cm/day |
| 0.01 | 0.000001 | 1.19027209e-3 | -5.18295109e-7 cm/day |
| 0.01 | 0.00003 | 1.12632912e-3 | -1.31214804e-5 cm/day |
| 0.01 | 0.0001 | 1.12015812e-3 | -4.28706038e-5 cm/day |

The response coefficient changes strongly with coupling-window length and, especially at the longer windows, also varies measurably with predictor flux. This reinforces the decision not to treat `u` as a static soil parameter.

## Interpretation

E3-D falsifies the idea that the original 36 unavailable E3 cases were caused by tangent or coupling-interface construction.

Instead:

> the component predictor trial itself reaches a bounded whole-window execution envelope.

This supports the broader paper architecture: the coupler must distinguish a component that cannot provide a valid candidate from an outer iteration that fails to converge.

The exact reason for the incomplete whole-window trial is not yet identified by stage 104 alone. The next diagnostic must inspect the returned kernel status and retry/rejection diagnostics rather than infer the cause.

## Immediate consequence for E3

E3 can now be extended without relaxing any scientific tolerance.

For `1e-3` and `1e-2 day`, `q=1e-4 cm/day` is already demonstrated to produce a valid predictor. It is therefore a legitimate next coupling case and is 100 times the original F-GC44 flux.

For the `1e-4 day` window, `q=3e-5 cm/day` is the largest demonstrated point in this scan.

These points will be used in a separately preregistered coupling refinement. The original 48-case matrix remains unchanged.

## Decision

**E3-D complete.**

Next actions:

1. diagnose stage-104 kernel/transaction failure mechanism at the first failed point for each window;
2. run loose-versus-iterative coupling at the largest demonstrated predictor points;
3. use a cleaner groundwater-feedback fixture before interpreting conductivity as coupling strength.
