# Next bounded dependency prompt: F-SI36

Start and complete a separate solver-interface workunit:

## F-SI36 — SWAP5 Accepted Trajectory Bottom-Interface Sensitivity Capability, Whole-Window Composition Prerequisite & Fail-Closed Qualification

Ordinary ChatGPT chat, not Work mode.

Use the GitHub connector directly.

Repository:

`abhedwig-cell/SWAP5`

### Numbering

Recheck the complete live F-SI namespace before branch creation.

At F-GC23 closeout, F-SI workunits existed through F-SI35 and no F-SI36 branch existed. Use F-SI36 only if it is still genuinely free. Never overwrite an existing workunit.

Suggested branch:

`work/f-si36-accepted-trajectory-interface-sensitivity`

### Start authority

Recheck live `integration/f-ci-canonical` and start from its exact current SHA/tree.

F-GC23 audited:

`integration/f-ci-canonical@379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b`

tree:

`556221f62b4fde616981499eba68ef5460f5d83c`

Use the live canonical if it has advanced.

### Governing evidence

Reconstruct and treat as authority, not merely branch-name evidence:

* F-SI28 `work/f-si28-interface-sensitivity-production-solve@5b514e678d0d794e5837f161033b0bac58385707`;
* F-SI32 `work/f-si32-scoped-interface-sensitivity-reconciliation@dfe1a285ae485e1e8348ee10492bb7808f85dd39`;
* F-SI33 Full Richards reference-solver v1 completion authority;
* F-SI34 HeadCalc isolation completion authority;
* F-SI35 mandatory production soil-water solver seam authority and its independent qualification/canonical admission;
* F-GC16 restricted production coupling plan;
* F-GC23 negative qualification and its exact source evidence;
* current transaction/runtime/kernel sensitivity semantics.

### Problem statement

Current SWAP5 correctly exposes an optional same-factorization `dh_bottom_dq_bottom` from the accepted Full Richards linearization. That primitive is qualified only as `LOCAL_TERMINAL`.

Current transaction/runtime/kernel code correctly transports that value without semantic upgrade. F-SI32 explicitly establishes that:

* `LOCAL_TERMINAL` is not a derivative of a sequence of accepted transaction substeps;
* it is not a derivative of the full canonical `[t0,t1]` interval;
* it is not a derivative of a groundwater coupling window;
* `covers_requested_interval=true` is provenance only and does not change derivative scope.

F-GC23 therefore cannot compose the frozen-v1 whole-window response tangent without an upstream capability.

This workunit owns only the soil-water solver/interface prerequisite. It must not change groundwater coupling orchestration, groundwater mass ledgers, tile mapping or MODFLOW adapters.

### Objective

Determine, derive and if defensible implement the minimum optional soil-water sensitivity capability needed so a later transaction/runtime workunit can propagate an accepted bottom-interface perturbation through a sequence of accepted soil-water state transitions without full nonlinear plus-dq/minus-dq reruns.

The required output is not automatically a complete coupling-window derivative. It is the mathematically sufficient solver-side trajectory/transition sensitivity primitive from which a separately owned transaction/runtime layer can construct and qualify a true whole-window response.

Do not rename the current local tangent.

### Scientific definition first

Before changing production source, define the controlled perturbation exactly.

At minimum specify:

* boundary coordinate and sign;
* whether the perturbation is instantaneous flux, step-average flux, or integrated transfer;
* units;
* state variable with respect to which the endpoint response is differentiated;
* how a constant or piecewise-constant bottom-flux control over a step enters the discrete Richards residual;
* what derivative information must enter from the previous accepted state;
* what derivative information must leave the current accepted step;
* treatment of changing step duration;
* treatment of nonlinear surface-regime changes and other nonsmooth branches.

Do not infer a universal coupling derivative from the existing scalar endpoint tangent.

### Candidate bounded formulation

Investigate an O(N)-state forward-sensitivity formulation before considering any O(N^2) state-transition matrix.

For a discrete accepted step

`R(x_{k+1}, x_k, q_k) = 0`

derive the accepted-step recurrence implied by

`J_k * s_{k+1} = - (dR/dx_k) * s_k - dR/dq_k * dq_k/dq_window`

where:

* `J_k = dR/dx_{k+1}` is the accepted Richards Jacobian;
* `s_k = dx_k/dq_window` is incoming trajectory sensitivity scratch;
* `s_{k+1}` is outgoing trajectory sensitivity scratch.

This equation is a starting hypothesis, not an authorized implementation claim. Verify it against the actual SWAP discretization, storage terms, constitutive derivatives, bottom-boundary algebra and accepted timestep semantics.

Prefer reusing the accepted Jacobian/factorization. If additional derivatives or factorization data are required, make them explicit and worker-owned.

### Hard architecture constraints

* No Full Richards physical trajectory change.
* Sensitivity ON/OFF must leave accepted physical state, fluxes and mass result unchanged within the qualified mode, preferably bitwise.
* No persistent sensitivity vector per logical column unless a later runtime proves it is physically required. Default ownership is worker/job scratch for a trial/window.
* Rejected or retried steps must not advance the accepted trajectory sensitivity.
* Retry rollback must restore sensitivity scratch consistently with physical checkpoint semantics.
* Alternative soil-water solvers remain valid when this capability is unavailable.
* No HeadCalc arrays or Jacobian internals may escape the solver/interface boundary.
* No file, calendar-day, MODFLOW or one-column/one-cell assumption.
* Physics options and sensitivity numerical policy remain separate.
* Mass conservation remains hard and independent of sensitivity accuracy.
* The normal path must not require extra full nonlinear Richards trajectories merely to obtain the sensitivity.

### Boundary-mode issue

Audit the relation between the existing F-SI28 prescribed-qbot mode and the production direct-groundwater coupling path, which currently uses typed prescribed groundwater-head forcing in F-GC21.

Do not assume that a mode-2 `q -> h` tangent can be consumed directly by a mode-5 coupling trajectory.

State exactly how the eventual whole-window response operator would be used by the coupling residual/preconditioner and which boundary formulation produces it. If a valid production use requires a different physical trial formulation, stop and record that dependency rather than silently switching boundary physics.

### Qualification oracle

Use whole-window finite differences only as an oracle/reference for smooth qualified cases.

At minimum compare the composed candidate trajectory sensitivity against independently rerun `+delta q` and `-delta q` windows for:

* one accepted physical step;
* multiple equal substeps;
* multiple nonuniform substeps;
* a retry-shortened path if a valid fixture exists;
* at least one evolving hydraulic profile, not only equilibrium;
* positive, zero and negative native-qbot where physically admitted.

The production capability itself must not require those reference reruns.

Choose perturbations and comparison metrics explicitly. Demonstrate convergence/robustness rather than reporting a single perturbation size only if practical.

### Nonsmooth and unavailable behavior

Fail closed when derivative semantics are invalid or unqualified, including relevant regime switches, fallback solvers or unavailable constitutive derivative information.

Unavailable sensitivity must never invalidate an otherwise physically valid Full Richards solve. It only disables the optional sensitivity route.

### Cost evidence

Report separately:

* extra Jacobian builds;
* extra factorization work;
* extra linear/backsolves;
* extra nonlinear trajectories;
* scratch memory scaling with active nodes;
* persistent state cost.

Target the existing architectural intent: same-factorization or otherwise bounded auxiliary work, not structural full-window reruns.

### Transaction ownership boundary

Do not add a `WHOLE_WINDOW` semantic to `mod_transaction_reference` in this F-SI workunit unless live governance proves F-SI owns that contract, which is not expected from F-GC23 evidence.

The expected successful handoff is a qualified solver-side primitive plus a precise contract for the subsequent F-KT-owned transaction/runtime/kernel composition workunit.

That later F-KT workunit must separately prove:

* accepted-route sensitivity composition over `[t0,t1]`;
* rollback/retry safety;
* provenance;
* machine-readable whole-window semantic distinct from `LOCAL_TERMINAL`;
* canonical/kernel transport;
* no stale sensitivity;
* mass preservation;
* independent qualification and canonical admission.

### Stop conditions

Stop without production implementation and persist a negative result if any of the following holds:

* the existing Richards discretization does not expose enough mathematically justified derivative information for bounded forward propagation;
* required changes would alter Full Richards physical results;
* the only feasible production construction requires structural full-window finite-difference reruns;
* the required ownership belongs primarily to F-KT or F-GC rather than the solver interface;
* nonsmooth behavior cannot be isolated fail-closed;
* mass/state semantics would become coupled to sensitivity acceptance.

Do not reduce the frozen groundwater-coupling denominator to avoid the dependency.

### Required artifacts

Persist at minimum:

* machine-readable status JSON;
* scientific/numerical derivation and source mapping;
* architecture audit against all 30 SWAP Core Architecture Invariants;
* executable qualification tests if implementation occurs;
* exact source blobs and canonical SHA/tree;
* explicit nonclaims;
* dependency/handoff artifact for the next F-KT transaction-composition workunit.

### Success outcome

Only if the solver-side capability is mathematically derived, implemented without physical-result change, qualified against whole-window FD oracle cases and bounded in cost, persist a decision equivalent to:

`QUALIFIED_ACCEPTED_TRAJECTORY_BOTTOM_INTERFACE_SENSITIVITY_PRIMITIVE_READY_FOR_TRANSACTION_COMPOSITION`

Do not claim a whole groundwater-coupling-window derivative yet.

### Negative outcome

If the capability cannot be justified or ownership is wrong, persist the exact blocker and the smallest dependency needed next. No percentage claim.

### Exit report

Report compactly:

* workunit/branch;
* canonical SHA/tree;
* governing F-SI28/F-SI32 authorities;
* exact derivative definition;
* mathematical recurrence: PASS/FAIL;
* same-factorization/bounded-cost feasibility: PASS/FAIL;
* implementation performed: YES/NO;
* physical result unchanged: PASS/FAIL/NOT_TESTED;
* mass unchanged: PASS/FAIL/NOT_TESTED;
* retry/rollback sensitivity semantics: PASS/FAIL;
* alternative-solver fail-closed behavior: PASS/FAIL;
* FD whole-window oracle qualification: PASS/FAIL/NOT_RUN;
* persistent state added: YES/NO;
* production nonlinear reruns required: count;
* all 30 architecture invariants checked: YES/NO;
* next F-KT dependency if successful;
* definitive authority SHA/tree.

No overclaim. A local terminal tangent remains local terminal unless a separately qualified composition proves otherwise.
