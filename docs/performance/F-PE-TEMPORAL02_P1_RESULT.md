# F-PE-TEMPORAL02 P1 result — accepted-path state and response divergence

Date: 2026-09-26

Status: `SMALL_PATH_DIVERGENCE_RELATIVE_TO_FULL_STEP_REFERENCE`

## Protocol

The P0 frontier was reduced to three budgets:

- 2e-4 cm;
- 5e-4 cm;
- 1e-3 cm, used as FULL_STEP_REFERENCE.

The 1e-3 arm is a physical full-window reference for this path-sensitivity screen because P0 showed that all 12 nonzero points accept the first converged 1e-4 day physical solve with no temporal or solver rejection.

For every successful arm, the participant candidate was committed in a fresh process and terminal physical state was snapshotted.

Compared metrics:

- max absolute terminal pressure-head difference;
- max absolute terminal water-content difference;
- q difference;
- bottom-exchange difference.

Three fresh-process repetitions were deterministic.

## Result

### 2e-4 cm

- 8/12 points complete;
- among those completed points, maximum difference versus the 1e-3 full-step reference:
  - max |dh| = 7.6118218e-5 cm;
  - max |dtheta| = 1.4184451e-7;
  - max |dq| = 1.5780597e-10 m/s;
  - max |d bottom exchange| = 1.3634436e-7 cm.

### 5e-4 cm

- 12/12 points complete;
- maximum difference versus the 1e-3 full-step reference:
  - max |dh| = 6.2953412e-5 cm;
  - max |dtheta| = 5.9334571e-9;
  - max |dq| = 1.1937858e-11 m/s;
  - max |d bottom exchange| = 1.0314309e-8 cm.

Most 5e-4 points are bit-identical to the 1e-3 full-step arm because they accept the first full-window candidate. The nonzero 5e-4 differences are controlled by the O14-wet +/-0.001 cm points, which P0 showed still require one temporal rejection before completion.

## Interpretation

The completion frontier is not accompanied by a large accepted-state discontinuity.

In particular, the first common completing budget, 5e-4 cm, remains extremely close to the full-step reference on this short difficult-corrector window.

This is encouraging for a practical temporal-policy candidate, but it is not a temporal-accuracy proof:

- 1e-3 is a full-step reference, not a refined temporal oracle;
- the P1 comparison quantifies path sensitivity caused by transaction subdivision;
- an independent refined-oracle qualification remains mandatory before production admission.

## Decision

Retain 5e-4 and 1e-3 as the leading P2 timing/effort candidates.

Retain 2e-4 only as a frontier shoulder, not as a common completing policy.

No production policy change is authorized by P1.
