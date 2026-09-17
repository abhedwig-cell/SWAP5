# PUB-ME D5 execution checkpoint

Status: **PREREGISTERED_EXECUTION_DESIGN_BEFORE_D5_RUN**

Publication owner: `PUB-ME`

Experiment family: `D5 — numerical workspace becomes physical authority`

## Immutable scientific design authority

- D1-D6 preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`

The frozen D5 semantics are: disposable numerical state from a non-authoritative trial must not become the physical start state of a later retry/continuation.

## Execution base

- `integration/f-ci-canonical@1604b89e6bebf6436dcd2718b8e150bf909d8a01`

At this base:
- D1 = STRUCTURAL_PREVENTION;
- D2 = EARLIER_DETECTION;
- D3 = STRUCTURAL_PREVENTION;
- D4 = EARLIER_DETECTION.

D5 is a separate defect family and must not reinterpret those results.

## Reconciled Reference workspace authority

The current Reference solver uses `reference_richards_workspace_t` as solver-owned scratch. The workspace contains residual/Jacobian arrays, Newton corrections, provider buffers, convergence flags and `old_head`.

`old_head` is populated in the real HeadCalc Newton loop from the current nonlinear iterate before a Newton update. It is therefore a genuine numerical workspace quantity.

The production Reference binding constructs physical candidate state separately in `reference_richards_state_binding_t`, and reinitializes/reset the workspace for every solve.

The field `warm_start_head` is **not** selected for D5 because current production resets it at every solve and no production read/write path establishing meaningful numerical continuation was found. D5 must not manufacture a warm-start mechanism merely to make the experiment work.

## Reference residual-unit guard

P2E05 established before D5 that the Reference HeadCalc compartment/total convergence residual is a **rate residual in cm/day**, whereas the RossFast hard mass bound is an integrated depth in cm. D5 therefore fixes the Reference internal numerical criteria to the existing numeric Reference value `1e-12 cm/day` and must not import or reinterpret a RossFast integrated-mass tolerance as a Reference convergence criterion.

The frozen `full_dt=0.0016 day` and `retry_dt=0.0008 day` are written explicitly in D5 rather than imported from an alternative-solver execution-policy constant. This is a units/authority correction made before the first D5 execution; it does not alter the frozen D5 defect semantics, fixture or B1/B2 classification rules.

## Frozen fixture

Reuse the pre-existing Reference-only B01 P2E02 physical fixture:

- material: B01;
- nodes: existing E0 16-cell grid;
- initial pressure head: -101 cm;
- full trial duration: 0.0016 day;
- refined comparator: two sequential 0.0008 day Reference solves;
- prescribed top flux: 0.01 times initial conductivity;
- prescribed bottom flux: -0.004 times initial conductivity;
- no roots, drainage, irrigation or macropores.

P2E02 independently established a non-zero full-versus-two-half state discrepancy before D5 was designed. D5 therefore freezes a zero temporal discrepancy tolerance: the full trial is non-authoritative/rejected whenever its endpoint is not bit-identical to the two-half comparator.

If the fixture unexpectedly becomes bit-identical on the D5 base, D5 is BLOCKED_FIXTURE_NO_REJECTION. Do not tune forcing or dt.

## Workspace source selected before execution

The D5 workspace source is:

`full_workspace%richards%old_head`

taken immediately after the real full Reference solve and before any later solver call can reset that workspace.

Before the mutant is executed, the harness must verify:

1. the full solve converged;
2. the full endpoint differs from the refined two-half endpoint under the frozen zero tolerance;
3. every selected `old_head` value is finite;
4. `old_head` differs materially/bitwise from the committed initial pressure-head vector.

If condition 4 is false, classify D5 as BLOCKED_WORKSPACE_NOT_INFORMATIVE. Do not select a different workspace field after observing that result.

## Clean retry

After rejection of the full trial, construct a new 0.0008-day retry request from the original committed physical start state:

- pressure head = original -101 cm vector;
- water content = original constitutively consistent theta;
- all forcing/parameters identical to the frozen fixture.

Solve with a fresh Reference workspace.

## Qualification-only D5 mutant

Construct the same 0.0008-day retry, except:

- physical retry pressure head is copied from the rejected full trial's `old_head` workspace;
- water content is recomputed from the **same already-bound constitutive provider** at those heads before retry, solely to avoid creating an unrelated head/theta inconsistency;
- all forcing, parameters, dt, solver policy and boundary conditions remain identical.

No production/reference source changes. No private state access. No modification to the physical equations.

The intentional defect is exactly that a solver scratch iterate is promoted into physical start-state authority after rejection.

## B1 comparator

B1 remains a strong conventional scientific-software baseline.

For clean versus mutant retry, B1 observes:

- solver success/failure;
- endpoint pressure-head and water-content differences;
- integrated storage difference;
- mass/equation residual diagnostics;
- deterministic O0/O2 behavior.

B1 detection occurs when one of the declared post-solve scientific comparisons fails.

The harness must not omit an applicable endpoint, storage or mass comparison to manufacture a B2 advantage.

## B2 transition-authority oracle

B2 contains B1 plus the direct retry-origin rule:

> after rejection, the physical retry start must be derived from the authoritative committed physical state, never from disposable numerical workspace.

Immediately before the retry solve, compare the proposed retry start pressure head and water content with the untouched committed start-state values.

A workspace-derived mismatch is a B2 detection **before retry execution**.

## Frozen classifications

- public/reference interfaces structurally prevent use of workspace as physical retry state without a private bypass → `STRUCTURAL_PREVENTION`;
- B1 and B2 detect at an equally protective pre-retry boundary → `NO_INCREMENTAL_VALUE`;
- B2 detects before retry execution while B1 first detects after solver execution/endpoint comparison → `EARLIER_DETECTION`;
- bounded B1 stays green while B2 detects the origin violation → `UNIQUE_DETECTION`;
- neither B1 nor B2 detects a materially workspace-derived retry → `D5_AUTHORITY_FAILURE`;
- frozen fixture cannot produce informative rejection/workspace separation → one of the declared BLOCKED states above.

The classification rule must not change after observing results.

## Required observations

Record:

- full-versus-two-half `U_h_inf` and `U_theta_inf`;
- maximum absolute difference between full-trial `old_head` and committed initial head;
- B2 retry-origin result;
- clean retry solver status and endpoint;
- mutant retry solver status and endpoint;
- endpoint `h` / `theta` infinity norms;
- integrated storage difference;
- available mass/native residual diagnostics;
- first B1 detection boundary;
- O0/O2 semantic identity.

## Interpretation boundary

D5 tests misuse of **real Reference numerical workspace**, not whether Newton warm starts are generally unsafe.

A positive result does not establish an existing production SWAP5 defect. The current production binding explicitly resets workspace and constructs physical state separately.

The experiment tests whether making that authority distinction explicit supplies incremental qualification value when a plausible modernization error promotes scratch into physical state.

## Hard exclusions

- no `src/**` or `reference/**` mutation;
- no private workspace bypass;
- no unused/synthetic warm-start field as primary evidence;
- no tuning of dt, forcing or tolerance after D5 output;
- no RossFast execution;
- no D6 execution;
- no claim that Newton workspace, rollback or retry semantics are novel.

## Next permitted action

Implement exactly this Reference-only D5 harness, runner and CI gate. If the frozen workspace source is not informative, preserve the blocked result rather than choosing another workspace field after the fact.
