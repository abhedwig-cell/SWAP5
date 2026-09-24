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
