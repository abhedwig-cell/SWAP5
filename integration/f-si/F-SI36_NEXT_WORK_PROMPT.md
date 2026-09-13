# Next executable workunit — F-SI37

Start and complete a separate solver-interface workunit:

## F-SI37 — SWAP5 Accepted-Step Directional Derivative Seam, Smooth-Route Full Richards Linearization & Fail-Closed Qualification

Ordinary ChatGPT chat, not Work mode.

Use the GitHub connector directly.

Repository: `abhedwig-cell/SWAP5`

### Numbering

Recheck the complete live F-SI namespace. At F-SI36 closeout no F-SI37 branch existed. Use F-SI37 only if still genuinely free. Never overwrite an existing workunit.

Suggested branch:

`work/f-si37-accepted-step-directional-derivative-seam`

### Start authority

Recheck live `integration/f-ci-canonical` and start from its exact current SHA/tree. Do not branch from F-SI36 merely to inherit documentation; reconstruct F-SI36 as governing evidence.

At F-SI36 start canonical was:

- SHA `379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b`
- tree `556221f62b4fde616981499eba68ef5460f5d83c`

Use live canonical if advanced.

### Governing evidence

Reconstruct at minimum:

- F-SI28 `5b514e678d0d794e5837f161033b0bac58385707`;
- F-SI32 `dfe1a285ae485e1e8348ee10492bb7808f85dd39`;
- F-SI33 `8a162a7b4aa7a67778ed9be454cfcd67d01276ce`;
- F-SI34 `b522fe150610f900f253eeea9bf78329107de362`;
- F-SI35 `15ccbf4b6bcf6895b824a68c221762bef0bc08b9`;
- F-SI36 definitive authority;
- F-GC16 restricted direct-groundwater coupling plan;
- F-GC23 negative whole-window tangent qualification;
- current F-KT transaction ownership and retry semantics.

### Why this workunit exists

F-SI36 proved that the recurrence

`J_k s_{k+1} = -(B_k s_k + r_{p,k})`

is mathematically appropriate for a fixed smooth accepted discrete route, and that the accepted TRIDAG factorization makes O(N) auxiliary work plausible. It also proved that the current canonical solver does **not** expose a complete qualified construction of `B_k s_k + r_{p,k}`.

The missing terms are real:

- storage uses the previous accepted `thetm1`;
- with canonical admitted `swkimpl=0`, face conductivities are rebuilt from the step base state and frozen during Newton, so the residual depends on the previous accepted pressure-head state through those conductivities;
- previous ponding and dynamic top physics can contribute;
- dynamic surface physics has nonsmooth regime switches;
- mode 2 and mode 5 have distinct boundary algebra;
- mode-5 accepted qbot is materialized from exact water-balance arithmetic.

Do not implement trajectory composition in F-SI37. F-SI37 owns only one accepted-step solver-side directional derivative primitive.

### Objective

Design, derive, implement if defensible, and qualify the minimum **optional accepted-step directional derivative seam** that gives a later F-KT owner enough information to propagate one scalar bottom-interface perturbation through a sequence of accepted Full Richards steps.

The primitive must remain behind `soil_water_solver_t`. HeadCalc/Jacobian arrays must never escape that boundary.

### Required derivative contract

Define the control coordinate explicitly. At minimum investigate both:

1. `SWBOTB=2`: prescribed step-average native qbot control [cm/day];
2. `SWBOTB=5`: prescribed bottom-face pressure-head control [cm].

For a scalar control direction, the optional request/result should be mathematically sufficient to carry:

- incoming derivative of base pressure head vector;
- incoming derivative of base water-content vector;
- incoming derivative of ponding state where the admitted surface process needs it;
- direct derivative of the selected bottom control for this step;
- outgoing derivative of accepted pressure head vector;
- outgoing derivative of accepted water-content vector;
- outgoing derivative of accepted ponding state if relevant;
- derivative of accepted top flux where relevant;
- derivative of accepted bottom flux/exchange where relevant;
- explicit semantic/method/status and diagnostics.

Do not overload `soil_water_interface_sensitivity_t%dh_bottom_dq_bottom`. Preserve it as `LOCAL_TERMINAL`.

Prefer a new optional request/result type with a precise name such as accepted-step/transition directional sensitivity. Alternative solvers may return unavailable.

### Exact discrete derivation

Map the derivative to the actual canonical Full Richards source, not an idealized Richards equation.

For the currently admitted explicit Full Richards route, derive `B_k s_k` term by term, including at minimum:

- storage derivative from base `water_content` / `thetm1`;
- time-level-`t_k` conductivity derivatives when `swkimpl=0`;
- hydraulic-mean derivatives for all admitted `swkmean` methods;
- top-boundary contribution for the qualified smooth surface route;
- bottom-mode-specific direct control derivative;
- derivative of the accepted mode-5 mass-consistent qbot publication;
- any source/sink terms that are state-dependent in the admitted scope.

Do not assume provider terms are state-independent without source proof.

### Provider derivative seam

The current dynamic top/provider ABI is value-only. Add no hidden coupling to B1.10 provider internals.

If a provider derivative is required, prefer an **optional sibling directional-derivative capability** or an equivalent clean solver-owned interface so:

- existing value-provider ABI remains valid;
- alternative providers/solvers can fail closed;
- unused columns pay no derivative cost;
- physics remains owned by the physical provider;
- solver code consumes only the interface, not B1.10 internals.

Qualify only smooth branches with explicit derivative semantics. Any atmospheric-head/ponded-head/runoff/evaporation-capacity switch not explicitly derived must return sensitivity unavailable, without invalidating the physical solve.

### Same-factorization target

For a qualified accepted step:

- reuse the accepted `J_k`/TRIDAG factorization where valid;
- assemble one exact directional RHS from the incoming sensitivity and direct control direction;
- perform approximately one additional O(N) backsolve per scalar direction;
- do not run extra full nonlinear Richards trajectories in production;
- keep tangent vectors/factorization capture worker/job scratch;
- add no persistent per-column sensitivity state.

Alternative-solver or alternative-linear-solver routes may fail closed unless independently qualified.

### Frozen-route semantics

The derivative is the derivative of the **accepted discrete step on its fixed smooth route**.

It is not automatically a derivative through:

- timestep-controller decision boundaries;
- retry branch changes;
- top-boundary regime changes;
- fallback-linear-solver changes;
- changes in active physical options.

State this explicitly in machine-readable semantics.

### Transaction boundary

F-SI37 must not compose multiple accepted steps and must not publish `WHOLE_WINDOW`.

Required handoff to a later F-KT workunit:

- incoming accepted sensitivity belongs to the physical checkpoint origin;
- rejected/retried trials produce no accepted outgoing sensitivity;
- only accepted solve results may be used to advance trajectory scratch;
- sensitivity remains diagnostic/numerical and never controls mass acceptance;
- F-KT will separately prove rollback, provenance and `[t0,t1]` composition.

### Qualification

If implementation occurs, add executable tests that compare the one-step directional derivative against independent centered finite differences of the physical solver for smooth fixtures.

At minimum cover, where admitted:

- mode 2 positive/zero/negative qbot;
- mode 5 at multiple prescribed heads;
- evolving, non-equilibrium profiles;
- more than one conductivity-mean method if all are claimed;
- surface-flux route with a demonstrably smooth/no-switch neighborhood;
- sensitivity ON/OFF physical candidate state, flux and mass result unchanged, preferably bitwise;
- retry/reject leaves no accepted directional result;
- unavailable provider/fallback route fails sensitivity closed but keeps physical solve valid.

Use multiple perturbation sizes and document convergence/roundoff behavior. FD is oracle only, never the production algorithm.

### Stop conditions

Stop with a negative result, no production admission, if:

- exact previous-state directional terms cannot be derived from the actual discrete implementation;
- a needed physical-provider derivative cannot be isolated behind a clean optional interface;
- the implementation would require HeadCalc arrays to escape the solver boundary;
- sensitivity ON changes accepted physical state/flux/mass;
- production construction requires extra full nonlinear trajectories;
- the mode-5 accepted exchange derivative cannot be made consistent with exact mass publication;
- nonsmooth branches cannot fail closed cleanly.

Do not reduce groundwater scope or denominator.

### Required artifacts

Persist at minimum:

- machine-readable status JSON;
- scientific derivation with exact source/blob mapping;
- new contract semantics if implemented;
- executable unit/qualification tests if implemented;
- cost evidence;
- all-30 SWAP Core Architecture Invariants audit;
- explicit nonclaims;
- executable next F-KT trajectory-composition prompt on success, or smallest dependency prompt on failure.

### Success decision

Only after implementation + executable qualification evidence:

`QUALIFIED_ACCEPTED_STEP_DIRECTIONAL_DERIVATIVE_PRIMITIVE_READY_FOR_TRANSACTION_TRAJECTORY_COMPOSITION`

Do **not** claim whole-window or groundwater-coupling sensitivity.

### Exit report

Report compactly:

- workunit/branch and definitive SHA/tree;
- canonical SHA/tree;
- derivative control coordinate(s) qualified;
- exact incoming/outgoing derivative state;
- previous-state derivative completeness: PASS/FAIL;
- provider derivative seam: PASS/FAIL;
- same-factorization reuse: PASS/FAIL;
- added backsolves/Jacobian builds/full nonlinear trajectories;
- physical ON/OFF identity: PASS/FAIL/NOT_TESTED;
- mass identity: PASS/FAIL/NOT_TESTED;
- retry/reject fail-closed: PASS/FAIL;
- alternative solver/provider fail-closed: PASS/FAIL;
- FD oracle: PASS/FAIL/NOT_RUN;
- persistent state added: YES/NO;
- all 30 invariants checked: YES/NO;
- exact next F-KT handoff.
