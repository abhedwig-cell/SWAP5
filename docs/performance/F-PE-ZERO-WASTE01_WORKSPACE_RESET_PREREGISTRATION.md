# F-PE-ZERO-WASTE01 — workspace reset elimination preregistration

Date: 2026-09-25

## Purpose

This work unit starts the SWAP5 zero-waste performance line: computation that is not required for the accepted numerical/physical result must not remain on a production hot path merely because its individual cost is small.

This is a performance-repair work unit, not an approximate-physics work unit. It does not relax solver tolerances, water-balance criteria, timestep policy, constitutive relations, transaction semantics, or accepted-state ownership.

## Baseline and authority

- repository: `abhedwig-cell/SWAP5`
- baseline branch: `work/f-pe-profile03-h03-e2e`
- pinned baseline commit: `82d9938976fd92ff3230e7739539e467c3243225`
- work branch: `work/f-pe-zero-waste01`
- inherited H03 status: qualified candidate; no reopening of constitutive-reuse qualification here
- current Status-A authority remains frozen separately; this branch is not canonical admission.

Relevant prior evidence is `docs/performance/F-PE-PROFILE01_COMPUTE_CORE_PREREGISTRATION.md`.

## Prior measured finding

PROFILE01 measured three full Reference Richards workspace resets per Reference solve on P01-A. Source/control-flow attribution classified two of those three resets as bounded redundant work.

The current path at this baseline is:

1. `mod_reference_richards_legacy_binding.f90` calls `initialize_reference_workspace(ws%richards,n)`;
2. `initialize_reference_workspace` performs a full `reset_reference_workspace`;
3. the binding immediately calls `reset_reference_workspace(ws%richards)` again;
4. `HeadCalc` calls `initialize_reference_workspace(fsi_ws,numnod)` again, which performs another full reset.

For the first repair slice, only step 3 is removed. This is the narrowest provable redundancy: no state mutation occurs between the reset performed inside initialization and the immediately following explicit reset.

## ZW01-H1 hypothesis

Removing the explicit second reset in `src/adapter/mod_reference_richards_legacy_binding.f90` will:

- reduce workspace full-reset count per Reference solve from 3 to 2 on the FKT22 observation path;
- reduce reset count per three-solve full/half interval from 9 to 6;
- preserve pressure head, water content, nonlinear iteration behavior, solver status and accepted transaction outcome;
- preserve poison/scratch independence because one clean reset still occurs before state binding and solve execution;
- not change any scientific formula or solver policy.

## Qualification gates

Q1. Compile the existing FKT22 production runtime path at O0 and O2.

Q2. Existing physical/runtime FKT22 oracle remains PASS.

Q3. Reset counters change exactly:
- per Reference solve: `3 -> 2`
- per external three-solve interval: `9 -> 6`

Q4. Reset zeroed-byte accounting remains positive and interval aggregation remains exactly three times the per-solve value.

Q5. No change to H03 constitutive-call reduction or its source semantics.

Q6. Runtime is measured only after Q1-Q5 pass. A speedup is useful but is not required to classify the removed call as waste. No portable whole-SWAP speed claim may be made from this slice.

## Failure rules

- If physical state, nonlinear trajectory, transaction outcome or poison/scratch independence changes, revert the repair and classify the explicit reset as not safely removable under the current ownership contract.
- Do not relax a test oracle to obtain PASS.
- Counter expectations may change only in the preregistered direction above.
- Do not remove the HeadCalc-side initialization/reset in this slice. That is a separate second repair requiring its own validity proof.

## Scope boundary

Touched production source is restricted to the Reference Richards legacy binding. Test changes may update only the reset-count expectations needed to observe the preregistered removal. No F-AHL, RossFast, MultiSWAP approximate mode, MODFLOW coupling semantics, constitutive formula, timestep controller or transaction architecture changes are authorized.

## Status

```text
RECONCILE        = COMPLETE
BIND AUTHORITY    = COMPLETE
PREREGISTER       = COMPLETE
ZW01-H1 REPAIR    = NEXT
QUALIFY           = PENDING
RUNTIME           = PENDING
CANONICAL ADMIT   = NOT CLAIMED
```


## ZW01-H2 preregistration — separate shape assurance from reset

H1 removes only the immediately repeated explicit reset. The remaining second avoidable reset is caused by `HeadCalc` calling `initialize_reference_workspace` on a workspace that the owning Reference binding has already initialized and cleaned for the solve.

The repair will make the existing ownership distinction explicit:

- `ensure_reference_workspace_shape(workspace,n)`: ensure allocation/shape/payload metadata only; do not clear scratch;
- `initialize_reference_workspace(workspace,n)`: preserve existing public semantics by calling shape assurance and then one full reset;
- `HeadCalc` with a caller-supplied `fsi_workspace`: use shape assurance only;
- `HeadCalc` with its own local workspace: retain full initialization/reset.

This avoids weakening the general initialization contract and limits the optimization to the caller-owned workspace route whose pre-clean condition is already established by the binding.

### H2 expected observation

Provided-workspace Reference path:

- full resets per solve: `2 -> 1`;
- full resets per three-solve interval: `6 -> 3`.

The one retained reset is the clean-scratch establishment at solve start in the owning binding.

### H2 safety gates

- existing FKT22 O0/O2 physical/runtime oracle PASS;
- no change in pressure head, water content, nonlinear iteration count, solver status, accepted/rejected outcome, or H03 constitutive counts;
- local-workspace `HeadCalc` path still performs full initialization/reset;
- shape mismatch/reallocation remains supported;
- poison/scratch independence remains qualified;
- runtime attribution only after semantic gates pass.

H2 is forbidden from changing transaction ownership or relying on dirty scratch from a prior solve.


## H2 qualification checkpoint

Candidate head: `da869df8582e252f3b0bb795ba069a3a86f9b86a`.

Observed CI:

- `F-PE-PROFILE01 compute-core observation`: PASS;
- `F-PE-PROFILE01 reset microbenchmark`: PASS;
- `PUB-P2E01 E0 paired pilot`: PASS;
- Documentation: PASS;
- F-CI canonical qualification: still running at this checkpoint.

The three PUB-ME D1/D3/D5 failures are not interpreted as physical regressions. Their runners contain explicit fail-closed guards rejecting any workunit that changes `src` or `reference` relative to their own immutable publication execution bases. This zero-waste workunit deliberately changes production source, so those publication-specific immutable-workunit guards are outside the H2 qualification claim.

F-CI96 F-ROSS12 postimage preservation likewise failed at its exact postimage/successor reconciliation step after a production-source change. It is retained as a preservation-scope signal, not silently reclassified as a successful unchanged-postimage replay.

### Current H2 verdict

```text
H1 immediate duplicate reset removal = PASS
H2 caller-owned HeadCalc reset removal = PASS on focused compute/runtime oracle
resets per Reference solve             = 1 expected and observed by passing PROFILE01 gate
reset microbenchmark                   = PASS
paired independent pilot               = PASS
documentation                          = PASS
canonical qualification                = PENDING
publication immutable-workunit guards  = EXPECTED_SCOPE_FAILURES
```

No canonical-admission or whole-model speedup claim is made at this checkpoint.


## H04 zero-waste audit checkpoint — provider tuple granularity

A fresh exact-source audit of the H03 postimage shows that H04 must not be treated as a simple "split the provider" repair.

Current explicit-provider use is phase dependent:

1. Pre-Newton evaluation:
   - conductivity `K` is consumed immediately;
   - capacity `C` is retained and, after H03, reused at the first Newton iteration;
   - water content `theta` is not immediately consumed;
   - `dK/dh` is reserved by the common ABI and the admitted swkimpl=0 default provider merely zeroes it.

2. Candidate/backtracking evaluation after `h` changes:
   - `theta` is consumed immediately;
   - `C` is retained for a subsequent Newton iteration if the candidate has not converged;
   - `K` can still be relevant to boundary handling, including the provider-backed free-drainage lower boundary;
   - `dK/dh` remains reserved/zero for the admitted default route.

Therefore:
- H04 is not presently N4 redundancy at the whole-call level;
- unconditional `dK/dh` array zeroing is a bounded zero-work candidate for the admitted swkimpl=0 route, but expected payoff is small;
- lazy or phase-specific theta/K/C evaluation could save work, especially on a final converged candidate where no next-iteration capacity is needed, but that requires control-flow-aware measurement and cannot be inferred safely from local use alone;
- a global abstract-provider ABI split is not authorized by this audit.

Next H04 work, if pursued, must instrument component demand by phase and convergence outcome before changing the provider contract.


## ZW01-H5 preregistration — overwrite-before-read zeroing

Exact-source audit identified two whole-array clears in `HeadCalc` that are stronger zero-waste candidates than reset-dependent duplication.

### H5a residual preclear

Immediately before the first `vector_F(1)`, `fsi_ws%residual = 0` clears the complete array. `vector_F` then assigns:

- element 1 explicitly;
- elements 2 through NN-1 explicitly;
- element NN explicitly;

before residual is consumed by the subsequent dot product/convergence logic. Additional boundary/macropore terms modify already assigned active entries. Therefore prior residual content is irrelevant for the active `1:NN` range.

Hypothesis: remove the preclear without changing any observable result.

### H5b provider_root_sink preclear

`fsi_ws%provider_root_sink = 0` is executed before optional root-sink provider evaluation.

- if the provider is active, the provider interface has `intent(out)` for the complete root-sink array and overwrites it before use;
- if the provider is inactive, `root_sink_term()` returns literal zero and does not read `provider_root_sink`.

Therefore the preclear is not needed for either control path.

### H5 gates

- existing FKT22 O0/O2 physical/runtime oracle PASS;
- PROFILE01 compute observation PASS;
- no changes in H03 constitutive counts, nonlinear iterations, solver status or accepted state;
- no relaxation of poison/scratch tests;
- no claim yet for `dfdh_upper/lower` clears, because linear-solver boundary indexing must be proved separately.

H5 is a pure removal of overwrite-before-read memory writes. No physics or numerical policy change is authorized.


## H2 implementation refinement after contract audit

A broader API audit found that the first H2 implementation made every caller-supplied `HeadCalc` workspace shape-only, which was wider than the preregistered production-binding claim. That implementation has been narrowed before admission.

Final intended ownership split:

- the Reference binding uses `ensure_reference_workspace_shape` before optional factorization-capture preparation, because allocation/shape is required there but clearing is not;
- `HeadCalc` retains its general contract and always calls `initialize_reference_workspace`, including for caller-supplied workspaces;
- the production binding therefore still reaches exactly one full reset per solve;
- arbitrary direct callers retain the historical clean-workspace initialization behavior.

This is a safety refinement, not a changed performance target. The 3 -> 1 reset goal remains unchanged while the public behavioral surface is narrower.


## ZW01-H6 preregistration — remove clears made redundant by the retained clean-scratch reset

After the H2 refinement, `HeadCalc` again guarantees one full `initialize_reference_workspace` reset before solver scratch is used.

Two subsequent clears are therefore duplicate writes on every Reference solve:

- `fsi_ws%unsaturated_flags(1:3) = .false.` immediately after initialization;
- for `SwKimpl == 0`, full-array zeroing of `dfdh_upper` and `dfdh_lower` before their active coefficients are assigned.

The first is directly redundant because the retained workspace reset already sets all unsaturated flags false and no intervening operation modifies them.

For the tridiagonal arrays, the retained reset establishes zero boundary/scratch values before the coefficient loop. The loop then assigns the active off-diagonal coefficients required by the current solve. H6 therefore removes only the duplicate whole-array preclear; it does not change coefficient formulas or the later per-iteration SwKimpl=1 updates.

### H6 gates

- existing FKT22 O0/O2 physical/runtime oracle PASS;
- alternative-solver behavior remains covered by existing qualification; no band-matrix mapping is changed;
- reset count remains one per Reference solve;
- no constitutive, nonlinear-iteration, timestep or transaction-policy changes;
- any poison/scratch-independence failure reclassifies the clear as required and forces revert.

H6 deliberately depends on the retained one-reset-per-solve invariant. If that invariant changes in a future workunit, this removal must be requalified.


## ZW01-H7 preregistration — minimal solve preparation instead of full scratch zeroing

The remaining one full workspace reset still writes every scratch array before every Reference solve. Exact control-flow audit shows that most of these arrays are fully overwritten before their first active read on the explicit production route.

### Arrays classified overwrite-before-read for solve preparation

- `residual(1:NN)`: assigned completely by `vector_F` before convergence use;
- `delta_head(1:NN)`: written by the linear solver before backtracking use;
- `sink/source(1:n)`: fully written by either provider or legacy source/sink construction;
- `provider_theta/provider_k/provider_capacity/provider_dkdh`: full `intent(out)` provider tuple whenever provider path is active, otherwise not consumed as provider scratch;
- `provider_root_sink`: full `intent(out)` when active, otherwise not read;
- `dconductivity_dhead(1:NN)`: written before use on SwKimpl=1; not used on admitted SwKimpl=0 path;
- `old_head(1:NN)`: assigned at Newton-iteration entry before use;
- `vertical_flux`: initialized from its first active face then propagated before use on routes that consume it;
- `band_matrix(1:NN,1:3)` and `band_rhs(1:NN)`: fully materialized before alternative band solve;
- `band_pivots`: solver output;
- `nonconverged_balance/nonconverged_head`: explicitly cleared before convergence classification;
- `dfdh_main(1:NN)`: fully rebuilt by `jacobian_F` before linear solve.

### Values that remain explicit solve-start authority

Minimal solve preparation must still establish:

- workspace shape/allocation;
- generation increment;
- reset diagnostics object;
- `poisoned=.false.`;
- `unsaturated_flags=.false.`;
- `has_warm_start=.false.` unless a future admitted warm-start contract says otherwise;
- tridiagonal boundary sentinels required by current indexing;
- any factorization-capture metadata/scratch required by its own preparation contract.

### Poison gate

H7 is admissible only if a direct Reference solve succeeds from a workspace whose scratch arrays were first filled with NaNs / invalid sentinels using `poison_reference_workspace`, and produces bit-identical physical output to the clean baseline.

The poison test is stronger than a normal repeated-run test: any omitted initialization that is actually read before overwrite should propagate NaN/invalid state or alter the result.

### Scope

H7 does not remove `reset_reference_workspace`; the full-reset API remains available for callers/tests requiring an explicitly zeroed workspace. H7 introduces a separate solve-preparation operation for the hot path.

No physics, tolerance, timestep, transaction, H03, F-AHL or approximate-mode change is authorized.


## H7 quantitative reset-volume consequence

The existing `reference_workspace_payload_bytes` accounting gives the normal compact-workspace full-reset payload:

```text
payload_bytes(n) = 196*n + 28
```

for the current type sizes and compact `tridag_gamma(n)` layout. This reproduces the earlier measured four-node payload exactly:

```text
n=4    -> 812 bytes
n=60   -> 11,788 bytes
n=200  -> 39,228 bytes
n=1000 -> 196,028 bytes
```

PROFILE01 measured two redundant full resets at approximately 5.41 us per 1000-node Reference solve on the shared runner, implying roughly 2.7 us per full reset on that runner class. H1/H2 removed the first two full resets; H7 removes the remaining bulk reset from the production solve hot path while retaining only a handful of scalar/sentinel writes.

Therefore the reset-specific zero-waste line removes approximately three full payload writes per Reference solve relative to the original PROFILE01 path:

```text
original PROFILE01: 3 * (196*n + 28) bytes written per solve
H7 candidate:       0 full-reset payload bytes per solve
```

At n=1000 this is about 588 kB of avoidable bulk writes per Reference solve. This is a data-movement statement, not yet a whole-model speedup claim.


## ZW01-H8 preregistration — tridiagonal factorization-capture overwrite elimination

Exact control-flow audit of `prepare_reference_tridag_factorization_capture` and `reference_tridag` identifies additional overwrite-before-read bulk writes.

### H8a capture preparation

When sensitivity capture expands `tridag_gamma` from n to 2n, the new array is currently zero-filled. When an already-expanded array is reused, it is also zero-filled.

For the capture path, `reference_tridag` subsequently writes:
- `gamma(2:n)` during forward elimination;
- `gamma(n+1:2*n)` as the complete beta-factor capture.

`gamma(1)` is not consumed by the backsolve; `reference_tridag_backsolve` uses `gamma(i+1)`.

Therefore bulk zero-fill during capture preparation is not required for the factorization result.

### H8b reference_tridag capture preclear

When `size(gamma) >= 2*n`, `reference_tridag` currently clears `gamma(n+1:2*n)` before immediately assigning:
- `gamma(n+1)` from the first beta;
- `gamma(n+i)` for every i=2..n.

This is a complete overwrite-before-read and may be removed.

### H8c optional beta_factor preclear

When the optional separate `beta_factor` is present, the routine clears `beta_factor(1:n)` and then assigns every entry 1..n before successful return. The clear is redundant on the successful factorization path. Because early singular return can leave a partial factorization, H8c is deferred unless callers explicitly treat output as unavailable on nonzero ierror.

H8 implementation in this workunit is limited to H8a/H8b. H8c remains audit-only.

Gates:
- existing sensitivity/accepted-direction tests remain PASS;
- FKT22 requested-trajectory path remains bit-identical;
- no extra backsolve or Jacobian changes;
- poison-workspace gate remains PASS.


## H7 poison qualification result

Dedicated workflow `F-PE-ZERO-WASTE01 poisoned workspace`, run `36069496764`, completed PASS.

The oracle executed the same direct Reference solve twice:

1. normal workspace;
2. workspace first allocated and then poisoned with NaNs / invalid sentinels using `poison_reference_workspace`.

Both solves:
- converged;
- produced bit-identical pressure head and water content;
- produced bit-identical ponding, top flux and bottom flux;
- retained identical nonlinear-iteration count;
- reported zero full workspace resets;
- reported zero full-reset payload bytes.

Therefore the H7 minimal solve preparation is qualified for this direct Reference route against poisoned prior scratch. The evidence supports the overwrite-before-read classification for the tested path and falsifies dependence on zero-filled bulk scratch there.

This remains bounded evidence, not a claim that every future solver path may omit arbitrary initialization.


## ZW01-H9 preregistration — compact factorization-release zero-fill

`release_reference_tridag_factorization_capture` currently allocates a compact n-entry gamma array and immediately zero-fills it before replacing the expanded capture array.

On the next normal TRIDAG solve:
- gamma(2:n) is assigned during forward elimination before back substitution;
- gamma(1) is not consumed.

Therefore the compact-array zero-fill is overwrite-before-read and may be removed without changing the release semantics or the compact allocation policy.

H9 intentionally does not yet retain the expanded 2n allocation across solves. Retaining capacity could avoid repeated allocation/deallocation, but current `reference_tridag` infers capture mode from array size, so capacity and behavior are coupled. Decoupling those is a separate design/performance work item.


## ZW01-H10 preregistration — retain TRIDAG capture capacity, decouple capacity from capture mode

The current sensitivity path grows `tridag_gamma` from n to 2n in `prepare_reference_tridag_factorization_capture` and shrinks it back to n in `release_reference_tridag_factorization_capture`. Repeated sensitivity solves therefore allocate/deallocate twice per solve even when active node count is unchanged.

H10 separates storage capacity from solver behavior:

- add an explicit workspace boolean `tridag_factorization_capture_active`;
- preparation ensures 2n capacity only when not already available, then sets capture active;
- release only sets capture inactive and retains 2n capacity for reuse;
- `reference_tridag` accepts an optional explicit capture-mode argument; existing callers retain historical size-based behavior when the argument is absent;
- `HeadCalc` passes the workspace capture-active flag, so retained 2n capacity does not cause unwanted beta-factor writes on normal solves.

Expected effect after first sensitivity solve at fixed n: zero further n↔2n allocation/deallocation churn for factorization capture.

Gates: accepted-direction/sensitivity outputs remain bit-identical, no additional beta capture on normal solves, H7 poison gate PASS, FKT22 trajectory gate PASS, and no change in nonlinear/Jacobian counts.


## ZW01-H10 preregistration — skip macropore-only convergence diagnostic arrays on swmacro=0

Exact HeadCalc use audit finds that `nonconverged_balance` and `nonconverged_head` are written during every Newton convergence check but are read only inside the later macropore-specific block guarded by `swmacro == 1`.

Current behavior on the standard explicit Reference/MultiSWAP path:

- explicit physical configuration rejects active macropores;
- therefore `swmacro=0`;
- both diagnostic arrays are nevertheless fully cleared each Newton iteration;
- individual entries are then written true when balance/head criteria fail;
- none of those array values are read on `swmacro=0`.

H10 removes those clears and per-node diagnostic writes when `swmacro=0`, while preserving the scalar `flnonconv` convergence decision exactly. For `swmacro=1`, existing array semantics remain unchanged.

Expected benefit is O(N * nonlinear_iterations) logical-array writes removed on the standard explicit route.

Gates:
- physical state and mass identity;
- unchanged nonlinear iteration count and accepted/rejected outcome;
- poison workspace PASS;
- macropore path source semantics unchanged;
- no tolerance or convergence-rule change.

This is a pure diagnostics-data-movement elimination, not a numerical approximation.


## ZW01-H11 preregistration — remove directional-wrapper full reset

The production groundwater/accepted-direction path calls `solve_with_accepted_step_direction`. On the eligible Reference route this wrapper currently performs:

1. `initialize_reference_workspace(ref_ws%richards,n)`;
2. `prepare_reference_tridag_factorization_capture(ref_ws%richards)`;
3. `ref_solver%solve(...)`.

After H7, the Reference solver itself performs minimal solve preparation and no full bulk reset. Therefore step 1 in the directional wrapper reintroduces a full reset solely to ensure allocation/shape before factorization capture.

The wrapper does not require zero-filled general scratch. Its pre-solve responsibility is only:
- ensure workspace allocation/shape;
- ensure expanded factorization capture storage exists.

H11 replaces the wrapper's full initializer with `ensure_reference_workspace_shape`. The solver remains responsible for solve-start preparation.

Expected effect on eligible directional/MODFLOW-style solves:
- full workspace resets before physical solve: `1 -> 0`;
- factorization capture remains available;
- accepted-direction values, nonlinear trajectory and physical result remain identical.

Required gates:
- FKT22 requested-trajectory/accepted-direction route PASS;
- accepted backsolve counts unchanged;
- poison-workspace gate PASS;
- paired runtime benchmark includes directional route before any MODFLOW-level speed claim;
- no change to direction eligibility, tangent equations or state ownership.

This is pure ownership cleanup: the wrapper ensures capacity, the solver prepares a solve.


## ZW01-H11 preregistration — shape-stable physical-state copy allocation reuse

`copy_b110_physical_state` currently deallocates `target%pressure_head` and `target%water_content` on every copy and immediately reallocates them to the source shape. For shape-stable MultiSWAP columns this creates allocator churn without changing transaction semantics or copy semantics.

H11 keeps the deep copy itself, because it is part of state isolation. It changes only storage reuse:

- if source array is allocated and target is allocated with identical shape, copy into existing target storage;
- if shapes differ, reallocate target;
- if source array is unallocated, deallocate target to preserve exact allocation-state semantics;
- apply the same principle to optional snow and soil-temperature state where type/shape permits safe reuse.

No aliasing is introduced. Source and target remain independent deep states.

Gates: clone isolation remains PASS, candidate/committed state remains independent, physical results remain bit-identical, and the existing PROFILE01 H02 clone microbenchmark is rerun to measure whether allocator reuse matters on repeated copies.


## ZW01-H12A preregistration — avoid zero temporary source/sink direction arrays

The accepted-direction service currently allocates two temporary length-N arrays on every eligible directional solve:

- `source_direction(n)`
- `sink_direction(n)`

Both are immediately zero-filled. Optional incoming direction arrays are then copied over them when present.

For the standard groundwater participant route:
- accepted trajectory direction is requested;
- `incoming_source_direction` is absent;
- `incoming_sink_direction` is also absent unless smooth drainage-qbot projection is active.

Therefore the common groundwater route pays two allocations plus two full zero writes per accepted directional evaluation merely to represent zero source/sink derivatives.

H12 will:
- preserve the existing array path when either incoming direction array is present;
- use a no-allocation zero-direction branch when both are absent;
- preserve all directional equations and signs exactly.

Expected benefit: remove 2 allocations, 2 deallocations and 2*N real zero writes per eligible accepted-direction evaluation on the common no-directional-source/sink route.

Gates:
- accepted trajectory direction values bit-identical;
- additional backsolve/Jacobian/nonlinear counts unchanged;
- drainage smooth-projection route unchanged when incoming sink direction is present;
- poison and FKT22 trajectory gates PASS;
- paired directional runtime measured before broader claim.


## H11 result — negative, no production change retained

Callsite audit after the H11 candidate showed that `copy_b110_physical_state` is currently invoked into freshly allocated polymorphic carriers/clones at all observed callsites. The proposed shape-stable target reuse therefore does not remove allocator churn from the current hot path: the target storage does not yet exist to be reused.

The H11 production edit was reverted. This is retained as a negative result: optimizing the helper's inout allocation policy without first changing higher-level carrier reuse would add code complexity without material runtime benefit.

Future state-copy performance work should target ownership/lifetime of reusable carriers or avoid unnecessary snapshots, while preserving deep-copy transaction isolation. The clone semantics themselves remain N1/N2 and are not classified as waste.


## ZW01-H12B preregistration — persistent zero-root source/sink buffer

When root extraction is active, each physical solve currently allocates `source_sink_root_zero(size(self%qrot))`, fills it with zero, binds it into the generic source/sink provider, and separately binds the real root sink through the root-sink provider. The zero vector is shape-invariant across the interval and contains no state-dependent information.

H12 moves this zero vector to persistent model storage and initializes it once during `prepare_interval` together with `qrot`.

Expected effect: one allocation/zero-fill per interval preparation instead of one allocation/zero-fill per full/half/retry physical solve.

Semantics remain unchanged: source/sink provider still receives a distinct all-zero root term, while the dedicated root-sink provider receives the actual root extraction sink. No aliasing between the two is introduced.


## ZW01-H13 preregistration — remove accepted-direction scratch vector preclears

The accepted-direction tangent assembly currently performs two full vector clears:

- `vertical_flux(1:n+1)=0`;
- `head_gradient(1:n+1)=0`.

Exact use audit shows:

- `vertical_flux(2:n)` is assigned by the hydraulic-mean directional loop;
- `vertical_flux(n+1)` is assigned explicitly from the bottom-node constitutive direction;
- only indices 2..n+1 are subsequently read;
- `vertical_flux(1)` is never read in this routine.

Likewise:

- `head_gradient(2:n)` is fully assigned by the gradient loop;
- only indices 2..n are subsequently read;
- indices 1 and n+1 are not consumed by the tangent RHS.

Therefore both full preclears are overwrite-before-read for all consumed entries and may be removed.

Expected benefit: remove roughly 2*(n+1) real writes per accepted-direction evaluation.

Gates:
- accepted-direction outputs bit-identical;
- tangent backsolve count unchanged;
- bottom-head and bottom-flux control routes unchanged;
- F-SI37 moving and independent qualification PASS.


## H7 safety refinement — free-drainage dK/dh sentinel

Further boundary-mode audit found one route where the former full-reset zero value was semantically consumed:

- in `jacobian_F`, bottom modes 7/-2 add `0.5*dconductivity_dhead(NN)`;
- `dconductivity_dhead` is physically populated only for `SWKIMPL=1`;
- under `SWKIMPL=0`, historical full-reset behavior made this contribution exactly zero.

After H7 bulk-reset removal, relying on stale scratch for this implicit zero would be unsafe.

The repair is not to restore array clearing. Instead the Jacobian adds this term only when `SWKIMPL=1`. This makes the existing numerical semantics explicit and removes hidden dependence on reset state.

Required follow-up:
- free-drainage SWKIMPL=0 poison case;
- existing SWKIMPL=1 preservation;
- no change to other bottom modes.


## ZW01-H14 preregistration — persistent zero direction for smooth drainage-qbot projection

The smooth drainage-qbot projection path currently allocates `projection_zero_direction(n)` and fills it with zero on every physical solve. The vector represents an invariant zero perturbation and depends only on active-node shape.

H14 stores one zero-direction vector on the serialized model and prepares it once per interval/shape when smooth drainage-qbot projection is active. The projection routine receives the same all-zero values, but full/half/retry solves no longer allocate and initialize a temporary vector individually.

Expected effect: remove one allocation, one deallocation and N real zero writes per physical solve on the smooth drainage-qbot projection route. This route is directly relevant to coupled groundwater execution.

Gates: projected groundwater level bit-identical, drainage response diagnostics unchanged, accepted-direction drainage route unchanged, and existing groundwater/drainage qualification remains green.


## ZW01-H15 preregistration — reuse shape-stable forcing buffers across intervals

`fmr_serialized_prepare_interval` currently deallocates and reallocates `qdra`, `qssdi`, `qrot` and related zero buffers every interval, even when the active-node count and drainage-level count are unchanged. In long MODFLOW/MultiSWAP runs this creates allocator traffic at every coupling interval.

H15 changes only storage lifetime:

- retain each buffer when its required shape is unchanged;
- reallocate only on shape change;
- overwrite all active values from the new forcing every interval;
- preserve separate zero-root and zero-projection buffers;
- no forcing value is carried forward implicitly.

This is not forcing caching. Values are refreshed every interval; only memory capacity is reused.

Expected benefit: remove repeated deallocate/allocate operations from the normal fixed-layout MultiSWAP interval path.


## ZW01-H16 preregistration — reuse interval control storage

`fmr_serialized_prepare_interval` currently deallocates `drainage_response_controls` and `legacy_swbotb2_control` at every interval start, then reallocates them later in the same routine when the corresponding forcing is present.

H16 reuses existing storage when the required layout is unchanged:

- `drainage_response_controls`: retain allocation when length matches, overwrite every element from current forcing;
- `legacy_swbotb2_control`: retain the allocated scalar control object when still present and assign current forcing values into it;
- deallocate only when the feature becomes absent or array shape changes.

No control value is cached across intervals. This only removes allocator churn.


## ZW01-H17 preregistration — reuse scalar soil-temperature forcing storage

`soil_temperature_forcing` is an allocatable scalar object that is deallocated at every interval start and reallocated immediately when soil temperature remains active. Its values must change with forcing, but its storage need not.

H17 retains the allocated object while the feature remains active, overwrites it from current forcing each interval, and deallocates only when the feature becomes inactive. No forcing value is retained implicitly.


## Paired-runtime harness reconciliation

Audit of `run_fpe_zero_waste01_paired_runtime.sh` found that its baseline initially replaced only workspace, linear solver, HeadCalc and Reference binding with the pinned PROFILE03 baseline. The accepted-direction service and serialized Reference backend were compiled from the candidate branch for both variants.

That design is sufficient for H1-H10 solver-local attribution but cannot measure H12A/H12B/H13-H17, because those changes live in the directional service and serialized backend and would be present on both sides of the pair.

The harness is therefore expanded before using it for bundle-level claims: baseline builds must also use the pinned baseline versions of `mod_reference_richards_accepted_step_directional_service.f90` and `mod_fmr_serialized_reference_backend.f90`; candidate builds use current branch versions. Physical checksum, nonlinear iteration count and constitutive evaluation count remain equality gates.


## ZW01-H18 preregistration — move drainage sink direction into request

`compose_fmr_qbot_drainage_sink_direction` already materializes an allocatable `drainage_sink_direction`. The runtime then allocates a second vector of identical length in `direction_request%incoming_sink_direction` and copies every element into it. The temporary is not read afterwards.

H18 replaces allocate+copy with `move_alloc(drainage_sink_direction, direction_request%incoming_sink_direction)` when the composed direction is available.

Expected effect: remove one allocation, one full length-N copy and one later temporary deallocation per eligible smooth drainage-qbot directional solve.

Semantics are unchanged: ownership of the already-computed vector moves into the request; values and shape are identical and no alias remains.

Gates: drainage directional values bit-identical, accepted-direction result bit-identical, no change in backsolve/Jacobian/nonlinear counts, existing groundwater/drainage directional qualification PASS.


## Recovery checkpoint — zero-waste runtime expansion

Checkpoint head at write start: `2159d93aea44fbb304c84eedea6f99750fb9cf6e`.

### Qualified / already evidenced on earlier postimages

- H7 minimal Reference solve preparation: dedicated poisoned-workspace equivalence PASS;
- production compute-core observation PASS with zero full workspace resets;
- paired pilot PASS;
- bulk reset payload eliminated from the tested Reference hot path.

### Current candidate stack requiring current-head replay

- H8/H9: remove TRIDAG factorization-capture overwrite-before-read clears;
- H10: retain 2n TRIDAG capture capacity and decouple capacity from capture mode;
- H12A: avoid zero temporary source/sink direction arrays when no incoming direction exists;
- H12B: persist zero-root source/sink buffer across physical solves;
- H13: remove accepted-direction vertical-flux/head-gradient preclears;
- H14: persist smooth drainage-qbot zero-direction buffer;
- H15: reuse shape-stable qdra/qssdi/qrot/zero-buffer capacity across intervals;
- H16: reuse drainage-response and legacy SWBOTB2 control storage across intervals;
- H17: reuse scalar soil-temperature forcing storage;
- drainage directional handoff: move the computed sink-direction allocation into the request rather than allocate+copy;
- paired-runtime harness expanded so baseline also freezes the directional service and serialized backend.

### Negative result retained

- H11 shape-stable reuse inside `copy_b110_physical_state` was reverted because all audited hot-path targets are freshly allocated before the helper is called. No material allocation saving would result without a higher-level lifetime redesign.

### Pending gates at this checkpoint

Current-head CI was queued at checkpoint time. Required before closure:

- capture-capacity lifecycle;
- poisoned workspace;
- compute-core observation;
- F-SI37 moving preservation and F-VQ89 independent qualification for directional changes;
- paired Reference and directional runtime;
- relevant application/runtime preservation including PPA-LOW02 and evaporation successors;
- documentation.

Exact-postimage publication/canonical guards that reject any changed production source remain scope guards rather than equivalence evidence and must not be counted as model regressions without inspecting their failure mode.


## ZW01-H19 preregistration — eliminate duplicate execution-order materialization

The serialized MultiSWAP runtime computes `execution_order` once, then `build_aggregate` and `finalize_runtime_diagnostics` each allocate a second length-N `local_order` array and copy the same order into it. `build_aggregate` also calls `fmr_count_templates`, which allocates another length-N template-id buffer even though the provided execution order is already grouped by template id.

H19 removes these duplicate metadata allocations on the primary path:

- iterate directly through the provided `execution_order` without copying it;
- when no order is provided, iterate natural index order without materializing an identity array;
- when sorted execution order is present, count template transitions directly instead of allocating the temporary id set;
- retain `fmr_count_templates` only as fallback for callers without an execution order.

Expected effect for N columns: remove two N-integer allocations/copies plus one N-int64 temporary allocation from end-of-batch aggregation on the normal serialized MultiSWAP path. No column execution order or diagnostics semantics change.


## ZW01-H20 preregistration — avoid zero-length commit-receipt allocation on valid requests

`fmr_run_serialized_physical_multiswap` currently allocates `commit_receipts(0)` whenever the optional output is present. On a valid receipt request it then immediately deallocates that zero-length array and allocates the requested final size.

H20 preserves the empty allocated result on rejected receipt-request paths, but on a valid receipt request allocates the final-size array directly once.

Expected effect: remove one allocation and one deallocation per valid receipt-enabled serialized MultiSWAP call. Receipt validation, ordering and returned values remain unchanged.


## ZW01-H21 preregistration — eliminate duplicate template lookup per column

`execute_column` currently calls `column_is_routable`, which performs `find_template_index`, and after success calls `find_template_index` again for the same column and template registry.

H21 resolves `template_index` once in `execute_column` and uses that resolved index for both routability checks and dispatch.

Expected effect: remove one linear template-registry scan per column per serialized MultiSWAP call. This is O(Ncolumns * Ntemplates) avoidable comparison work in the current path.

No routing semantics change: backend id, parameter/forcing handle bounds and template compatibility checks remain identical.


## ZW01-H21 preregistration — remove registry state-claim scratch allocation

`registry_structure_valid` currently allocates `state_claimed(size(states))`, zero-fills it, and marks each referenced state handle while validating columns.

The same routine already performs a nested `i/j` column loop to reject duplicate `column_id` values. State-handle uniqueness can be checked in that existing loop at essentially no additional asymptotic cost:

- keep bounds validation for each state handle;
- in the existing duplicate-column loop, also reject equal `state_handle`;
- remove the temporary logical `state_claimed` array and its zero-fill.

Expected effect: remove one length-|states| allocation, deallocation and logical zero-fill per serialized MultiSWAP dispatch.

Semantics are unchanged: duplicate state ownership remains rejected before physical execution, and no public diagnostics/interface type changes.
