# F-KT21 — Accepted-Route Trajectory Directional Sensitivity Composition

Ordinary ChatGPT chat. Use the GitHub connector directly. Repository: `abhedwig-cell/SWAP5`.

Recheck the live F-KT namespace. F-KT21 was branch-wise free when this prompt was written; use it only if still free. Suggested branch: `work/f-kt21-accepted-trajectory-directional-sensitivity-composition`.

Start from the exact live `integration/f-ci-canonical` head. Before implementation, verify that F-SI37 has the definitive decision `QUALIFIED_ACCEPTED_STEP_DIRECTIONAL_DERIVATIVE_PRIMITIVE_READY_FOR_TRANSACTION_TRAJECTORY_COMPOSITION` backed by a successful executable gate. If F-SI37 is still CI-pending or negative, stop and record that dependency.

## Objective

Compose the qualified F-SI37 **single accepted-step** directional derivative over a generic accepted trajectory `[t0,t1]`. F-KT21 owns transaction/runtime composition only: do not change Full Richards physics or the F-SI37 step derivative.

Required semantics:

- bind sensitivity to the same exact committed checkpoint origin as the physical trajectory;
- advance sensitivity only when that exact physical candidate is accepted;
- reject/retry discards the trial direction and restores the previous accepted sensitivity origin;
- retry exhaustion/failure publishes no accepted trajectory sensitivity;
- stale or cross-candidate directional data must fail closed;
- sensitivity never controls physical acceptance or mass accounting;
- no midnight/day assumption; accepted substeps may partition `[t0,t1]` arbitrarily;
- preserve control coordinate explicitly: `SWBOTB=2` native qbot and `SWBOTB=5` bottom pressure head remain distinct and must not be inverted or relabelled;
- if any accepted step has F-SI37 sensitivity unavailable, the trajectory sensitivity is unavailable unless a separately qualified fallback exists.

## Outputs

If available, return a typed trajectory result containing exact origin/lineage provenance, `[t0,t1]`, accepted-step count, control coordinate/method, final pressure-head/water-content/ponding directions, and derivative of accepted interval-integrated bottom exchange using the same accepted substep durations and sign conventions as physical exchange. Include availability route and cost diagnostics.

Do not call this `dh_bottom_dq_bottom` or `WHOLE_WINDOW` unless the exact returned semantic is independently derived and qualified. F-GC23 remains the owner of groundwater response-tangent composition.

## Cost

Normal path: approximately one O(N) derivative backsolve per accepted F-SI37-available step, zero extra full nonlinear Richards trajectories, zero extra physics-changing Jacobian construction, and no persistent solver-factorization state.

## Qualification

Executable tests must include:

- at least three accepted substeps;
- mode 2 and mode 5 independently where supported;
- centered whole-trajectory FD oracle with multiple perturbation sizes;
- sensitivity ON/OFF physical identity;
- reject then retry from the same committed origin;
- retry exhaustion with no accepted sensitivity;
- unavailable/nonsmooth accepted step causing trajectory sensitivity unavailable while physical solve remains valid;
- stale/cross-candidate provenance injection rejected;
- a generic non-day-aligned interval;
- exact derivative accumulation of accepted bottom exchange;
- cost counters showing no structural extra nonlinear trajectories.

Mass conservation remains absolute. Rejected trials contribute zero accepted physical exchange and zero accepted exchange derivative.

Audit all 30 SWAP Core Architecture Invariants, especially transactionality, worker scratch, compact state, generic time, solver isolation, mass conservation, MultiSWAP scalability and bounded coupling cost.

Success decision only after executable evidence:

`QUALIFIED_ACCEPTED_TRAJECTORY_DIRECTIONAL_SENSITIVITY_READY_FOR_GROUNDWATER_WHOLE_WINDOW_COMPOSITION`

After success, return to F-GC23. Do not claim groundwater/MODFLOW production admission, a universal head tolerance, inverse dh/dq semantics, derivatives through timestep-controller branch changes, or derivatives through physical regime switches.
