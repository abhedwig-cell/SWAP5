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
