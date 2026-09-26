# F-PE-TEMPORAL07 closeout — c=0.65 coupling admission qualification

Date: 2026-09-26

Status: `CLOSED_BLOCKED_BY_DYNAMIC_ENDPOINT_AUTHORITY_NO_C065_REJECTION`

PR:

`#652 — F-PE-TEMPORAL07: c0.65 coupling admission qualification`

Parent:

`#651 — F-PE-TANGENT01`

Frozen candidate:

`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`

## What passed

### P0 — same-policy linear response

PASS.

Across ten difficult dynamic origin/history groups:

- all center/probe candidates completed;
- zero solver rejections;
- max relative q-linearization error at +/-0.01 cm:
  `1.20277135053985114e-06`;
- max relative error at +/-0.05 cm:
  `4.83999642543446202e-03`.

Both frozen P0 gates pass.

### P1 — production tangent cache

PASS.

Across ten 64-request repeated-sequence groups:

- 8 fresh tangents and 56 reuses per group;
- cached q is bit-identical to cache-disabled q;
- cached integrated exchange is bit-identical;
- no invalid reuse or ownership drift.

### Production-shaped performance evidence

TEMPORAL06 remains attributable because the relevant policy lineage is unchanged:

- c=0.65 completed 768/768 requests;
- retries 384 versus 768 for c=0.50;
- no solver rejections;
- median c=0.65 / c=0.50 repeated-sequence runtime ratio `0.73525`.

## What blocked admission

P2 live MODFLOW6 coupling reaches a physically close endpoint and preserves all production invariants, but the inherited independent physical residual gate fails.

For c=0.65:

- production final residual: approximately `-7.94e-23 m/s`;
- independent endpoint head error: approximately `-1.343e-12 m`, inside the frozen `5e-10 m` head gate;
- independent q(H)-fit residual at that production endpoint:
  approximately `2.7351e-14 m/s`;
- frozen independent residual gate: `1e-15 m/s`.

The gate therefore fails.

## Causal attribution

A preregistered c=0.50 comparator changed only the temporal coefficient and reproduced the same dynamic O14-mid live setup.

Its independent residual is:

`2.7354625687903394e-14 m/s`

with essentially the same:

- endpoint-head error;
- production external residual;
- MODFLOW balance;
- transaction and publication behavior.

Therefore the P2 blocker is not attributable to c=0.65.

The selected policy is neither admitted nor rejected by this result.

## Interpretation

TANGENT01 established that the c=0.65 accepted-trajectory tangent is the correct Jacobian of the c=0.65 response map.

TEMPORAL07 then established:

- the local affine response is accurate over the admission perturbation range;
- production tangent caching is transparent;
- live MODFLOW coupling converges with the c=0.65 response;
- c=0.65 materially reduces repeated retry/runtime burden;
- the remaining admission blocker is the inherited dynamic-origin independent endpoint authority.

The blocker is specifically the relationship between:

1. a historical independent q(H) oracle based on a local constant-flux MODFLOW fit;
2. the very tight `1e-15 m/s` physical residual gate;
3. dynamic-origin endpoints located outside the original closeout probe/bracket scale.

## Decision

TEMPORAL07 closes without production admission.

No change is authorized to:

- c=0.65;
- tangent formulation;
- cache defaults;
- fixed-interface coupling semantics;
- physical error bounds;
- BALTOL02;
- MODFLOW stopping or balance tolerances;
- independent physical residual acceptance tolerance.

No evidence supports reverting to c=0.50.

## Direct next workunit

Open a separate dynamic-origin endpoint-authority qualification.

Its purpose is to determine whether the inherited independent q(H) oracle remains a valid residual authority when extrapolated to the dynamic-origin exchange scale, and to replace or repair that oracle only if independently justified.

The strongest candidate authority is a direct constant-flux MODFLOW endpoint solve that avoids q(H) extrapolation, while preserving the frozen physical residual and endpoint-head gates.

## Closure

F-PE-TEMPORAL07 is closed.

Verdict:

`BLOCKED_BY_DYNAMIC_ENDPOINT_AUTHORITY`

Coefficient attribution:

`NOT_C065_SPECIFIC`

Production admission:

`NOT_YET_AUTHORIZED`
