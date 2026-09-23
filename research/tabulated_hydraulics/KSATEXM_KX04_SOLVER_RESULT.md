# TAB-HYD-KX04 — typed Reference-Richards KSATEXM solver result

Date: 2026-09-23

Status: **PASS_SCIENTIFIC__PERFORMANCE_NOT_DEMONSTRATED_IN_ACTIVE_EXTENSION**

Controlling workflow run: `35858733419`.

Entry authority:

- KX03 constitutive PASS: `35858102782`;
- current canonical: `a2d99ddd149ffaa422d9c422f96bd66e92c8555d`.

## Test

A controlled four-node Reference-Richards K0 column used the exact recovered Hupsel hydraulic materials:

- nodes 1-2: exact upper Hupsel material;
- nodes 3-4: exact lower Hupsel material;
- F-SI39 KSATEXM active in both materials;
- same numerical settings in analytical and KX03 routes;
- no process physics beyond the constitutive/solver seam.

Three preregistered regimes were tested:

1. below threshold, h0=-5 cm;
2. transition, h0=-2 cm;
3. active extension, h0=-1 cm.

## Scientific result

All three cases converged and passed the frozen gates.

| regime | max |dh| (cm) | max |dtheta| | mass residual diff (cm) | nonlinear iters A/T | linear solves A/T |
| --- | ---: | ---: | ---: | ---: | ---: |
| below_threshold | 2.863e-9 | 4.185e-11 | 2.776e-17 | 4 / 4 | 4 / 4 |
| transition | 7.199e-9 | 3.358e-11 | 8.327e-17 | 5 / 5 | 5 / 5 |
| active_extension | 4.585e-9 | 7.025e-12 | 2.776e-17 | 5 / 5 | 5 / 5 |

Top- and bottom-flux differences were zero at reported precision for all cases.

Thus the explicit analytical F-SI39 sub-branch preserves the Reference-Richards solution class and solver effort over this bounded exact-material envelope.

## Performance observation

Performance was secondary and is not a production claim.

Four-node repeated medians:

- below threshold: table delta `-1.15%`;
- transition: table delta `+12.59%`;
- active extension: table delta `+27.28%`.

Interpretation:

The raw-head table acceleration applies to the ordinary MvG branch. In the active KSATEXM branch KX03 intentionally performs the analytical authority-state evaluation in addition to the generated theta/C evaluation. On this very small four-node benchmark that extra work dominates and removes the acceleration benefit.

This does not establish whole-Hupsel slowdown because:

- the benchmark is only four nodes;
- whole-Hupsel has a mixed temporal/state distribution;
- provider preprocessing and solver overhead scale differently;
- no exact whole-Hupsel runtime comparison was performed here.

It does establish that **KSATEXM support cannot inherit the existing F-TAB02 speedup claim without separate performance qualification**.

## Research conclusion

The former F-TAB02-F scientific blocker is resolved at constitutive and direct solver level:

- KX01: generated-theta branch ownership rejected;
- KX02: head-threshold floating equivalence rejected;
- KX03: explicit analytical F-SI39 authority sub-branch PASS;
- KX04: typed Reference-Richards K0 scientific PASS.

The remaining decision belongs to the F-TAB02 production owner:

1. whether to admit the explicit F-SI39 sub-branch into generated-provider scope;
2. if yes, re-run production qualification and exact M1/Hupsel Gate F;
3. qualify performance separately for the KSATEXM-active application envelope.

No production branch is modified by this research result.
