# F-VZAA01 - Discrete conservation, lower-boundary seam and history-cost reconstruction

## Purpose

This note continues the source-bound assessment of the published VZAA formulation before any production implementation.

Primary source:

Sadeghi et al. (2026), "Vadose zone analytical algorithm (VZAA): a non-iterative algorithm for vadose zone soil moisture and groundwater recharge", Journal of Hydrology 673, 135467. DOI 10.1016/j.jhydrol.2026.135467.

Methodological precursor:

Sadeghi et al. (2022), "Estimating soil water flux from single-depth soil moisture data", Journal of Hydrology 610, 127999. DOI 10.1016/j.jhydrol.2022.127999.

This reconstruction distinguishes facts stated in the paper from deductions that follow algebraically from the published equations. The DOI-linked MATLAB supplementary implementation has still not been directly captured, so code-path conclusions remain fail-closed where implementation detail matters.

## 1. Published sequential update

For layer `i` and time step `j`, the published discrete continuity update is Eq. (8):

`f_i,j = f_{i-1,j} - (theta_i,j - theta_i,j-1) d_i / dt`.

Equivalently,

`Delta S_i = (theta_i,j - theta_i,j-1) d_i = (f_{i-1,j} - f_i,j) dt`.

The paper combines this with its analytical moisture-flux approximation to obtain Eq. (9), solves for `theta_i,j`, then computes `f_i,j` from Eq. (8). The resulting flux becomes the input to the next layer. The sweep proceeds top-down until the water table or the deepest active layer is reached.

The paper uses the deepest solved outflux as recharge and updates water-table depth with Eq. (10):

`DWT_j = DWT_j-1 - Re_j dt / Sy_j`.

`Sy_j` is not an exact storage derivative of the accepted discrete column state. It is an empirical dynamic approximation based on a Duke-type hydrostatic expression, a calibration factor `phi`, and a user-defined lower floor `Sy_min`.

## 2. Fixed-domain conservation theorem

For a fixed set of `m` full layers, with no clipping, overwrite, geometry change, source/sink omission or inconsistent flux duplication, Eq. (8) is algebraically conservative layer by layer.

Summing Eq. (8) over `i = 1..m` gives

`sum_i Delta S_i = dt * sum_i (f_{i-1} - f_i)`

and therefore, by telescoping internal interfaces,

`Delta S_column = (f_top - f_bottom) dt`.

This is exact apart from floating-point roundoff if the same `theta`, `d`, and interface fluxes are used on both sides of the ledger.

### Consequence

The non-zero profile mass-balance residuals reported by Sadeghi et al. cannot be explained merely by saying that Eq. (8) is a coarse finite-difference approximation, if the diagnostic ledger uses exactly the same fixed-domain discrete states and fluxes.

At least one assumption of the fixed-domain theorem must be violated in the reported complete method or diagnostic. Candidate locations include:

- the active unsaturated domain changes when the water table crosses layer geometry;
- saturated layers or layer fractions are overwritten rather than updated through the same conservative transfer;
- water-table storage is updated separately through Eq. (10) using approximate `Sy`;
- the diagnostic storage integral is reconstructed from a profile representation that is not identical to the layer stores used by Eq. (8);
- runoff/recharge reclassification at `DWT = 0` changes ledger ownership;
- clipping, limiting or initialization logic modifies `theta` after the continuity update;
- the MATLAB implementation differs from the literal algebraic sequence inferred from Eqs. (8)-(10).

This is a high-value reproduction target for the supplementary code. Gate C remains failed for the published complete formulation, but the failure is now localized more sharply than "Eq. (8) is non-conservative".

## 3. Water-table update is a separate storage operator

The published method treats recharge from the unsaturated sweep as input to a water-table update through

`Delta DWT = -Re dt / Sy`.

For exact accepted-step conservation, the groundwater or saturated-zone storage owner must satisfy

`Delta S_gw = Re dt`

with the same transfer `Re` that leaves the unsaturated domain.

That equality is not guaranteed by an empirical finite-step head update unless `Sy` is the exact secant storage derivative for the state transition actually represented. In the paper, `Sy` depends on a hydrostatic approximation, `phi`, and `Sy_min`; `phi` is also treated as a calibrated, temporally constant parameter even though the authors state that it depends on hydraulic properties and boundary conditions.

Therefore Eq. (10) should not be treated as an exact conservative storage map for SWAP5 without separate qualification.

## 4. Lower boundary is structurally output-driven in published VZAA

The paper explicitly states that VZAA requires the surface flux as external boundary input, propagates fluxes downward, and treats the lower boundary as a model output. It also states that a strict prescribed zero-flux bottom condition cannot be guaranteed in the current formulation.

This directly conflicts with the SWAP5 requirement that the soil-water solver accept an explicit bottom interface contract, including prescribed head and prescribed flux cases and direct MODFLOW coupling.

For direct SWAP5-MODFLOW coupling the required interface target remains

`H_SWAP = H_MF`

and

`q_SWAP = -q_MF`,

with exact transfer accounting even if a qualified head residual is tolerated numerically.

The published VZAA sweep does not provide this contract.

## 5. Smallest plausible conservative derivative

A modified VZAA-like method can be investigated, but it must be classified as a new conservative derivative rather than as the published VZAA solver.

One bounded candidate architecture is:

1. Run the VZAA sequential sweep as a predictor and obtain `theta*`, internal fluxes and a raw bottom flux `q_b*`.
2. Obtain the required bottom interface condition from the runtime/coupler.
3. Determine the exact target column storage from the accepted old state and all accepted boundary/source/sink transfers:

   `S_target = S_old + dt * (q_top - q_bottom + sources - sinks)`.

4. Apply a bounded conservative projection to the predicted layer stores so that:

   `sum_i S_i,new = S_target`

   while respecting physical storage bounds.
5. Reconstruct internal interface fluxes from the accepted layer storage changes, so the complete ledger telescopes exactly.
6. Reject, retry or fall back if the conservative projection becomes too large or violates a qualified physical-deviation envelope.

A simple projection can use one scalar multiplier `lambda`:

`S_i,new(lambda) = clip(S_i* + lambda w_i, S_i,min, S_i,max)`.

Solve the monotone scalar equation

`sum_i S_i,new(lambda) - S_target = 0`.

Bisection or another safeguarded scalar solve gives bounded work if its maximum iteration count is fixed.

### Important limitation

This repair enforces mass conservation but generally moves the corrected state away from the published VZAA constitutive flux relation. Conservation alone is therefore not sufficient for admission. The size and physical consequences of the projection must be qualified against reference Richards solutions.

## 6. Prescribed head requires an additional interface response solve

For a prescribed bottom head, exact mass conservation and head consistency cannot generally be obtained by simply overwriting the water table after the top-down predictor.

A possible conservative response formulation is to treat bottom flux as a scalar trial variable `q_b`:

1. choose trial `q_b`;
2. compute exact target storage from the ledger;
3. conservatively project/update the profile;
4. derive the bottom/interface head from the corrected state;
5. form `r_h(q_b) = H_soil(q_b) - H_target`;
6. solve `r_h = 0` with a safeguarded bounded scalar method;
7. commit only a state that passes both mass and interface gates.

This is not a global Richards/Newton solve, but it may require several `O(N_layers)` profile evaluations. Its production viability therefore depends on a bounded correction count and a monotone/regular interface response over a qualified envelope.

For MODFLOW coupling, the same response map could in principle expose `dq_b/dh_b` or its inverse, but the published VZAA formulation does not supply this tangent.

## 7. Exact half-order history conflicts with compact state and predictable cost

The published Eq. (5) approximates the half-order time derivative using a sum over the complete moisture history from the initial time to the current time.

If evaluated directly for every layer:

- persistent history storage grows as `O(N_layers * N_steps)`;
- work per new time step grows as `O(N_layers * N_steps)` before accounting for any local nonlinear solve;
- total work over `N_steps` grows as `O(N_layers * N_steps^2)` for direct history summation;
- adaptive time-step subdivision increases `N_steps` and makes the cost less predictable.

The paper itself identifies efficient approximation of the half-order derivative with reduced dependence on long moisture histories as future work.

This means the published method does not satisfy the SWAP5 compact-persistent-state invariant or a strong bounded-cost claim as written.

### Possible donor technology, not yet VZAA qualification

Fast Caputo/fractional-history methods based on sum-of-exponentials approximations are established in the numerical-analysis literature. For example, Jiang et al. developed a fast Caputo evaluation that reduces history storage from `O(N_steps)` to `O(N_exp)` and total direct-history work from `O(N_steps^2)` to `O(N_steps * N_exp)` for fixed spatial size, with `N_exp` growing only logarithmically or polylogarithmically for fixed accuracy in their setting.

Such a compressed-history operator could be a useful SWAP5 donor concept, but it changes the VZAA numerical method and requires its own error, conservation, transaction and restart qualification.

## 8. Transactional implications

The exact published history term also complicates checkpoint -> trial -> rollback.

A SWAP5-compatible implementation must not append trial moisture states irreversibly to the committed fractional history. Therefore history state must itself be transactional:

- committed history/compressed modes;
- trial-local updates;
- commit only after the entire soil-water step is accepted;
- discard or roll back trial history on retry.

With full raw history this is memory-heavy. With recursive compressed modes it is architecturally cleaner, provided the approximation is separately qualified.

## 9. Current gate implications

### Gate C - exact discrete conservation

Status remains `FAIL_PUBLISHED_FORMULATION_FOR_SWAP5`.

New refinement: the literal fixed-layer Eq. (8) update is algebraically conservative. The complete published-method residual therefore appears to originate outside that narrow fixed-domain continuity identity. Supplementary-code reproduction is required to locate it exactly.

### Gate D - bottom head/flux boundary

Status remains `FAIL_PUBLISHED_FORMULATION_FOR_SWAP5` because the published lower boundary is output-driven and cannot strictly enforce a prescribed flux/head condition.

### Gate G - transaction semantics

Status becomes `CONDITIONALLY_PLAUSIBLE_BUT_HISTORY_STATE_REQUIRES_TRANSACTIONAL_OWNER`. No proof yet.

### Gate H - bounded runtime

Status becomes `FAIL_STRONG_BOUNDED_COST_CLAIM_FOR_LITERAL_FULL_HISTORY_FORMULATION`.

The sequential layer sweep is promising, but literal full-history evaluation plus adaptive substepping is not bounded `O(N_layers)` per coupling window.

A separate compressed-history derivative may reopen this gate.

### Gate I - MODFLOW response tangent

Remains `OPEN_NOT_PROVIDED`. A bounded scalar bottom-response solve is a plausible research path, not a qualified result.

## 10. Required next experiments

Before any production implementation:

1. capture the DOI-linked MATLAB appendices with provenance and checksum;
2. reproduce one published fixed-water-table/fixed-domain case and verify whether Eq. (8) telescopes to roundoff;
3. reproduce the moving-water-table case and decompose the reported residual into unsaturated-layer, water-table/saturated-storage, geometry-crossing, clipping and bottom-boundary terms;
4. inspect the actual Eq. (9) solution method and count local function evaluations;
5. inspect adaptive-step acceptance/retry logic and establish a worst-case cap or explicit fallback policy;
6. benchmark literal history cost versus a separately qualified compressed-history approximation;
7. prototype the conservative projection only in an isolated experimental harness;
8. reject the derivative if boundary correction requires unbounded global iteration or produces unqualified profile distortion.

## Current decision

The direct published VZAA production path remains blocked.

Two research paths remain legitimate:

- a clearly renamed conservative VZAA-derived solver with exact accepted-step ledger, explicit bottom interface, bounded correction policy and compressed transactional history;
- use of VZAA mechanisms as donor concepts for LayeredMFP or another reduced-order solver.

Neither path is yet qualified.