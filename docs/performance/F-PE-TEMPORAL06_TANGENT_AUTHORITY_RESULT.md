# F-PE-TEMPORAL06 tangent-authority discriminator result

Date: 2026-09-26

Status: `CLOSED_NEITHER_POLICY_TANGENT_AUTHORITY_CONSISTENT`

Preregistration: `docs/performance/F-PE-TEMPORAL06_TANGENT_AUTHORITY_PREREGISTRATION.md`

## Trigger

The original TEMPORAL06 P0 repeated-sequence gate failed because c=0.50 and c=0.65 produced about 5.86% different accepted-trajectory tangents for O14 mid dynamic origins while q remained very close.

That original overlap failure is retained as a valid negative result. This discriminator asks which tangent, if either, matches an independent derivative of the MODFLOW-facing q(h) response.

## Method

Primary matrix:

- O14 mid, h0 = -75 cm;
- history imbalance -0.10 and +0.10;
- corrector offsets -0.01, -0.001, +0.001 and +0.01 cm.

Candidate tangents:

- HIST_HALF, c=0.50;
- SELECTED, c=0.65.

The tangent cache was disabled. Every candidate tangent was therefore freshly composed from the accepted trajectory for that request.

Independent authority:

- central finite difference of Reference q(h);
- same captured dynamic origin;
- BALTOL02 effective balance floor retained;
- epsilon ladder 1e-4, 2.5e-4, 5e-4 and 1e-3 cm;
- N=32 and N=64 fixed-substep Reference arms;
- primary authority fixed before execution at N=64, epsilon=2.5e-4 cm.

The MODFLOW-facing Reference q sign was constructed from integrated outward bottom exchange using the same public interface convention as the participant. An initial harness-only sign mistake was detected from the coupling contract and corrected before interpretation.

## Authority stability

All 8 discriminator points resolved.

Across the matrix:

- epsilon-support relative discrepancy around the primary derivative was approximately 1.7e-8 to 4.4e-8;
- N=32 versus N=64 relative discrepancy was approximately 0.254%;
- therefore every point passed the preregistered 1% authority-stability gates.

The independent derivative was approximately:

`dq/dh = -1.53365e-5 ... -1.53376e-5 1/s`

over the tested heads and histories.

## Candidate comparison

At all 8 points:

### c=0.50

Published accepted-trajectory tangent:

approximately `-1.42866e-5 ... -1.42871e-5 1/s`.

Relative error to independent authority:

approximately 6.846% to 6.850%.

### c=0.65

Published accepted-trajectory tangent:

approximately `-1.34489e-5 ... -1.34491e-5 1/s`.

Relative error to independent authority:

approximately 12.307% to 12.314%.

### Direct policy difference

The c=0.50 versus c=0.65 tangent difference remains approximately 5.863% to 5.866%.

The corresponding q responses remain much closer:

approximately 0.022% to 0.116% relative difference across the eight fresh-only points.

## Accepted temporal paths

The discriminator localizes the cause of the policy dependence:

- c=0.50: one temporal retry, two accepted substeps;
- c=0.65: zero temporal retries, one accepted substep.

This pattern occurs at every tested O14-mid discriminator point.

Thus the published directional sensitivity depends materially on accepted temporal subdivision even though the resulting q response itself changes only slightly.

## Preregistered classification

All 8 points classify as:

`NEITHER_AUTHORITY_CONSISTENT`

because both candidate tangent errors exceed the preregistered 2% authority-consistency bound.

c=0.50 is numerically closer to the independent derivative at every point, but it does not satisfy the preregistered authority bound.

The smaller c=0.50 absolute error is also not <= 0.5 times the c=0.65 error, so the preregistered `CLEARLY_CLOSER` criterion is false.

## Interpretation

The evidence does not support treating either c=0.50 or c=0.65 accepted-trajectory tangent as the independent MODFLOW-facing q(h) derivative for this difficult dynamic origin.

Therefore the earlier 1% c=0.50 versus c=0.65 overlap gate was not merely too strict. It exposed a real trajectory-dependence in the currently published tangent.

At the same time, this result does not invalidate the TEMPORAL05 physical qualification of c=0.65 for state, q, flux and integrated exchange. The failure is specific to tangent publication / linear-response semantics.

## Decision

TEMPORAL06 does not admit c=0.65 for production coupling.

No cache follow-up is needed in this workunit because the fresh tangent itself is not independently qualified.

A separate tangent-repair / tangent-authority workunit is required before any temporal policy can be admitted for MODFLOW-facing linear-response use.

No production source policy is changed by TEMPORAL06.
