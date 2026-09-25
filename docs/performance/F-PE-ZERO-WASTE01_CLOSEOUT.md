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
