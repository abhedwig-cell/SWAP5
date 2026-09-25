# F-PE-ZERO-WASTE01 — H03 / production-bootstrap P0 closeout checkpoint

Date: 2026-09-25

Source head for production behavior: `a03c964c3120d816774032a06a421fd1e85b1835`

Measurement-only head including H17A: `48102256d2e16d61eacc40f0d71022dae42cd0ad`

Status: `CLOSEOUT_H03_PRODUCTION_BOOTSTRAP_P0`

## Scope of this closeout

This closeout applies to the exact SWAP5 Reference / serialized MultiSWAP production-bootstrap route characterized by the H03 workload and the qualified directional counterpart.

It does not claim that every optional SWAP physics combination is globally free of avoidable work.

The governing principle remains:

> work that is not required for the requested result should not execute.

No approximation, tolerance relaxation, water-balance concession or accepted-state weakening is included.

## End-to-end result against the original zero-waste baseline

Current paired runtime on the source head reports:

Reference:

- mean candidate/baseline ratio: `0.697316579`;
- median ratio: `0.710481145`;
- mean shared-runner improvement: `30.268342%`;
- mean delta: `-3819.457680 ns/interval`;
- nonlinear iterations per solve: unchanged;
- constitutive evaluations per solve: unchanged;
- verdict: PASS.

Directional:

- mean candidate/baseline ratio: `0.739752522`;
- median ratio: `0.754719577`;
- mean shared-runner improvement: `26.024748%`;
- mean delta: `-3720.515200 ns/interval`;
- nonlinear iterations per solve: unchanged;
- constitutive evaluations per solve: unchanged;
- verdict: PASS.

These are paired observations for one shared runner and workload, not portable universal SWAP5 speedup guarantees.

## Qualified P0 removals and reuse

The current route includes qualified removal or suppression of:

- duplicate and then all full Reference workspace resets on the hot path;
- overwrite-before-read scratch clears;
- repeated TRIDAG capture resizing;
- unnecessary accepted-direction temporary zero vectors and copies;
- serialized registry O(N^2) validation on the stable production owner;
- repeated execution-order construction;
- repeated template lookup on the planned route;
- O(N^2) receipt validation/lookup through indexed handling where receipts are used;
- unused serialized worker-assignment diagnostics;
- unused column/summary/runtime diagnostics on the production owner;
- unnecessary serialized atomic concurrency tracking when such diagnostics are not requested;
- repeated parameter-object allocation/deallocation;
- repeated equal-shape geometry allocation;
- repeated MvG preprocessing under prepared-parameter authority;
- repeated full raw/prepared compatibility scans under the explicit immutable-owner contract;
- repeated prepared-hydraulics copying through bounded borrowed binding;
- unnecessary constitutive components on qualified candidate and directional phases;
- inactive attempt-context capture/restore;
- repeated state-binding allocation through workspace-owned capacity reuse.

The exact physical/reference gates remain authoritative.

## Multi-iteration confirmation

The current multi-iteration Reference characterization passes at O0/O2 with:

- initial full constitutive evaluations: 1;
- candidate full evaluations: 0;
- candidate demand evaluations: 3;
- capacity-only evaluations: 2;
- terminal candidate evaluations: 1;
- candidate capacity reuse claims: 0.

This confirms that current demand-specialized logic is not limited to the one-iteration H03 trajectory.

## Negative or deferred findings retained

The following candidates are explicitly not authorized by this closeout:

### Transaction-state clone elimination

Fresh full/half states remain required by current exact transaction isolation.

### Directional trajectory ownership transfer

H-DIR04 `move_alloc` ownership transfer was neutral-to-negative in isolated paired runtime and remains rolled back.

### Persistent groundwater forcing reuse

Several reuse candidates failed freshness/lifecycle requirements and remain rejected without an explicit generation contract.

### Initial full constitutive replacement by K+C

Component timing showed K+C slower than the current full provider. The intuitive narrowing is rejected.

### H17A request/result adapter vectors

Measurement-only result:

- N=60: fresh 49.42 ns/solve versus reuse 23.67 ns;
- N=200: fresh 136.94 ns versus reuse 66.63 ns;
- N=1000: fresh 474.69 ns versus reuse 382.95 ns.

The isolated benefit is too small on current realistic node counts to justify broader solver request/result ownership changes.

Classification: `MEASURABLE_BUT_LOW_PRIORITY`.

### Directional attempt context

Directional attempt context is not pure waste. Accepted trajectory state can mutate during advance and must be restored after outer rejection. The kernel already skips context capture when `attempt_context_required()` is false.

## Large-N coupled orchestration reopen result

The original H03 closeout reopen criterion for large-N coupled orchestration has been triggered and has produced a separate exact-P0 result.

### GWPLAN01 application-plan materialization

`GWPLAN01` is admitted as an exact canonical fast path.

The admitted path is used only when predictors and cell areas are exactly pointwise aligned with the already-qualified canonical groundwater topology. Otherwise the historical generic validation and lookup path remains authoritative.

Same-runner exact-parent/candidate qualification at N=10,000 reported:

- parent mean plan-materialization time: 0.508457828667 s;
- candidate mean: 0.006707316667 s;
- paired ratio: 0.0131914906;
- isolated shared-runner reduction: 98.680851%;
- all F-GC49A semantic, fallback, fail-closed and O0/O2 gates PASS;
- PPA-WU01 production bootstrap PASS.

This is an isolated operation/workload result, not a portable whole-application speed claim.

Classification: `GWPLAN01 = ADMITTED_EXACT_P0_LARGE_N_STRUCTURAL_FAST_PATH`.

### GWTOPO01 topology materialization

`GWTOPO01` is admitted as an exact canonical topology fast path.

The fast path is used only when strict monotonicity proves all relevant tile and cell identity fields unique and the input is already in canonical tile/cell order. Otherwise the historical generic pairwise validation, lookup and sort route remains authoritative.

Exact-parent/candidate same-runner qualification at N=10,000 reported:

- parent mean topology-materialization time: 0.175890985333 s;
- candidate mean: 0.000727786 s;
- paired ratio: 0.00413771063;
- isolated shared-runner reduction: 99.586229%;
- F-GC48 semantic, fallback, fail-closed and O0/O2 gates PASS;
- downstream F-GC49A PASS;
- PPA-WU01 O0/O2 production bootstrap PASS.

The first fast-path candidate exposed an out-of-bounds membership-cursor defect under F-GC48 bounds checking. That technical failure was repaired before admission with explicit bounds-before-dereference logic. Historical first-failure precedence was also restored and regression-tested.

This is an isolated operation/workload result, not a portable whole-application speed claim.

Classification: `GWTOPO01 = ADMITTED_EXACT_P0_LARGE_N_STRUCTURAL_FAST_PATH`.

### GWCTX01 application-context handle uniqueness

`GWCTX01` is admitted as an exact linear uniqueness proof for participant handles.

The production context bind route previously performed a pairwise duplicate-handle scan. At N=10,000 that is 49,995,000 equality checks before registry/ledger validation.

The admitted path first proves at runtime that handles are positive and strictly increasing. Only under that proof is the duplicate scan omitted. Any proof failure keeps the historical duplicate validation and failure semantics unchanged.

Qualification:
- FGC49D O0 PASS;
- FGC49D O2 PASS;
- FGC49D O0/O2 output identity PASS;
- production application context ABI gate PASS;
- explicit duplicate-handle fallback fail-closed;
- PPA-WU01 O0/O2 PASS.

Isolated N=10,000 scan observations:
- pairwise duplicate scan: about 30–42 ms on the shared runners used;
- strict-increase proof: about 6–14 microseconds;
- this is an isolated structural validation result, not a portable whole-application speed claim.

Classification: `GWCTX01 = ADMITTED_EXACT_P0_LINEAR_HANDLE_UNIQUENESS_PROOF`.

After GWPLAN01, GWTOPO01 and GWCTX01, the remaining application-context bind work is linear and must be remeasured before further production edits.

### GWCTX03 compact application-context cell representation

`GWCTX03` is admitted as an exact compact owned representation for application-context cells.

The context previously copied full `groundwater_application_cell_plan_t` objects even though after bind it only consumed topology identity plus tile_begin/tile_count. The admitted representation stores only those fields. Mutable linear terms remain separately context-owned.

Qualification:
- FGC49D O0/O2 PASS;
- FGC49D output identity PASS;
- production application context ABI PASS;
- PPA-WU01 O0/O2 PASS.

At N=10,000, dedicated qualification measured the full cell-plan copy at about 1.274 ms versus about 0.056 ms for the compact representation on the same runner/workload.

Classification: `GWCTX03 = ADMITTED_EXACT_P0_COMPACT_CONTEXT_CELL_VIEW`.

Together, GWPLAN01, GWTOPO01, GWCTX01 and GWCTX03 remove the dominant measured large-N structural and representation waste from canonical groundwater context construction.

## Remaining current P0 interpretation

After the current tranche, no large, high-confidence pure-waste hotspot remains on the qualified H03 / production-bootstrap Reference route.

The remaining visible work is dominated increasingly by required numerical computation rather than obvious software overhead.

Small residual adapter allocations, scalar branches and representation copies may remain measurable, but new production edits must now meet a higher bar:

1. clear necessity proof that work is avoidable;
2. realistic-path runtime significance after current cleanup;
3. bounded semantic surface;
4. paired evidence.

Operation-count reduction alone is no longer sufficient.

## Reopen criteria

Reopen this P0 route only if one of the following appears:

- a fresh profile on realistic production cases shows a new avoidable hotspot;
- optional physics activates a materially different waste path;
- large-N coupled orchestration exposes repeated structural work not covered by the execution-plan/registry tranche;
- a multi-iteration workload materially changes current cost ranking;
- a new ownership or generation contract makes a previously rejected reuse candidate exact and bounded.

## Next performance boundary

For the qualified H03 / production-bootstrap route, further effort should compete against:

- exact solver algorithm improvements;
- RossFast;
- ROM / reduced-order representations;
- coarser but separately governed spatial or vertical schematization;
- later application-qualified P2 acceleration with explicit error budgets.

P0 zero-waste remains the prerequisite, but it is no longer the dominant unexploited performance source on this route.

## Closeout verdict

`F-PE-ZERO-WASTE01 H03 / production-bootstrap P0 = CLOSED_WITH_REOPEN_CRITERIA`

The broader SWAP5 codebase remains subject to the same zero-waste principle as new physics, workloads and coupling routes are admitted.
