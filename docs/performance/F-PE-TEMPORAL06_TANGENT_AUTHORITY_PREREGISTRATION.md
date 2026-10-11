# F-PE-TEMPORAL06 tangent-authority discriminator preregistration

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

Parent workunit: `F-PE-TEMPORAL06` / PR #650

## Trigger

The preregistered P0 repeated-sequence overlap gate failed only in the O14 mid dynamic-history groups.

For O14 mid, history +/-0.10:

- c=0.50 and c=0.65 both complete all requests;
- q checksum differs by only about 0.030%;
- accepted-trajectory tangent checksum differs by about 5.86%.

This failure is retained as a valid preregistered finding. The discriminator does not redefine it away.

## Question

Which published tangent, if either, agrees with an independent derivative of the MODFLOW-facing q(h) response from the same captured dynamic origin?

The discriminator is authority-seeking, not coefficient calibration. The frozen c=0.65 coefficient is not changed.

## Scope

Primary discriminator matrix:

- material: O14;
- regime: mid, h0 = -75 cm;
- accepted history imbalance: -0.10 and +0.10;
- same-origin corrector offsets: -0.01, -0.001, +0.001 and +0.01 cm.

These four unique offsets cover the repeated TEMPORAL06 sequence. Repetition itself is not needed in the fresh-only arm because every candidate is discarded and the captured origin is unchanged.

Candidate policies:

- HIST_HALF: c=0.50;
- SELECTED: c=0.65.

## Fresh-only candidate arm

The tangent cache is disabled before candidate evaluation.

For each origin/head pair:

1. set the policy budget;
2. run one candidate from the captured dynamic origin;
3. require completion, no solver rejection and an available response tangent;
4. record q, tangent, accepted-substep diagnostics, retries and temporal rejections;
5. discard the candidate.

The published tangent therefore comes from the accepted trajectory of that request and cannot be a cache-age or refresh-head artifact.

## Independent Reference q(h) authority

Use the existing recovered exact Reference fixed-substep oracle from the same captured dynamic origin.

The oracle:

- uses the serialized Reference backend;
- does not consume the candidate tangent under test;
- uses the admitted BALTOL02 effective compartment and total balance floor per fixed substep;
- constructs MODFLOW-facing q from integrated bottom exchange over the coupling window, matching the participant response definition.

For a target head h and perturbation epsilon:

`D(epsilon) = [q_ref(h+epsilon) - q_ref(h-epsilon)] / (2 epsilon)`

where q is in m/s, h is in m, and D is therefore in 1/s.

Preregistered epsilon ladder:

- 1.0e-4 cm;
- 2.5e-4 cm;
- 5.0e-4 cm;
- 1.0e-3 cm.

Fixed-substep resolutions:

- N=32;
- N=64.

The primary authority value is N=64 at epsilon=2.5e-4 cm. This choice is frozen before execution and is not selected after seeing candidate agreement.

## Authority stability gates

The independent derivative is considered resolved at a point only if both hold:

1. N=64 epsilon support:
   - the derivatives at epsilon 1.0e-4, 2.5e-4 and 5.0e-4 cm each agree with the primary authority within 1% relative error;
2. substep support:
   - N=32 and N=64 at epsilon 2.5e-4 cm agree within 1% relative error.

Relative comparisons use `max(abs(D_authority), 1e-12 1/s)` as denominator to avoid an artificial singularity near zero.

The 1.0e-3 cm value is reported as a wider-scale curvature diagnostic but is not required for the local stability gate.

If either stability gate fails, the point is `AUTHORITY_UNRESOLVED`. No candidate is preferred from that point.

## Candidate comparison

For each authority-resolved point report:

- absolute tangent error, `abs(T_candidate - D_authority)`;
- relative tangent error against the same denominator;
- direct c=0.50 versus c=0.65 tangent difference;
- q difference between the two policies;
- retry and accepted-substep path for both policies.

Classification per point:

- `C050_AUTHORITY_CONSISTENT` if c=0.50 relative tangent error <= 2% and c=0.65 > 2%;
- `C065_AUTHORITY_CONSISTENT` if c=0.65 relative tangent error <= 2% and c=0.50 > 2%;
- `BOTH_AUTHORITY_CONSISTENT` if both <= 2%;
- `NEITHER_AUTHORITY_CONSISTENT` if both > 2%.

A "clearly closer" interpretation additionally requires the smaller absolute error to be no more than half the larger error. This is reported separately from the 2% consistency classification.

## Decision logic

- If c=0.65 is authority-consistent at all resolved discriminator points and c=0.50 is not at the previously failing point(s), the original 1% policy-overlap gate remains recorded as failed but is no longer treated as tangent authority. TEMPORAL06 may continue with MODFLOW-facing response qualification against the independent derivative.
- If c=0.50 is authority-consistent where c=0.65 is not, TEMPORAL06 closes tangent-rejected for c=0.65.
- If both are authority-consistent but differ materially, inspect accepted-substep composition and define which tangent semantics the coupling contract intends before any admission.
- If neither is authority-consistent, or the finite-difference derivative is unresolved, open a separate tangent repair/qualification workunit. No temporal-policy admission follows.

## Cache follow-up

Cache behavior is assessed only after the fresh-only authority result.

If the fresh tangent is qualified, a separate check may verify that production cache reuse:

- reproduces the last qualified fresh tangent exactly as designed;
- refreshes at the existing head-limit / max-age triggers;
- does not change response provenance or q.

No tangent-cache defaults are changed in TEMPORAL06.

## Scope exclusions

No change to:

- c=0.65;
- temporal physical error bounds;
- BALTOL02;
- Richards equations;
- retry scale;
- tangent-cache defaults;
- MODFLOW coupling semantics;
- production temporal policy.

Any tangent-publication repair belongs in a separate workunit.
