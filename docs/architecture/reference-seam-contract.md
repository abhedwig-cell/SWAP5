# KRS-1 kernel reference-seam contract

**Workstream:** KRS — Kernel Reference Seam  
**Slice:** KRS-1  
**Baseline:** `fafeebdece209abcc320b24a3c8c2757800b2e0e`  
**Status:** contract only; no production physics implementation

## Purpose

KRS-1 creates the first production-facing source boundary for the future SWAP5 kernel without pretending that the migrated physical kernel already exists. The repository was documentation-led before this slice. A VQ seam could therefore not honestly point to production source.

The new Fortran module `src/kernel/swap5_kernel_seam.f90` defines one compile-checked trial boundary while keeping `SWAP5_KERNEL_IMPLEMENTATION_STATUS = DEFERRED_NO_KERNEL_IMPLEMENTATION`.

KRS-1 is therefore an integration seam, **not B2 admission**.

## One-kernel contract

There is deliberately one abstract `swap5_kernel_t`, not separate reference, balanced and throughput kernels. Numerical execution policy belongs to `swap5_numerical_config_t`; changing policy must not create a second physical model.

The trial signature is conceptually:

```text
trial(
  interval,
  parameters,
  committed_state,
  forcing,
  numerics,
  scratch,
  result
)
```

with the following ownership:

| Argument | Intent | Owner / meaning |
| --- | --- | --- |
| `interval` | input | caller-selected positive `[t0,t1]` in seconds on a caller-defined time origin |
| `parameters` | input | immutable/shared physical parameters |
| `committed_state` | input | authoritative physical starting state |
| `forcing` | input | interval forcing/boundary data |
| `numerics` | input | numerical configuration, including future reference/balanced/throughput policy |
| `scratch` | input/output | worker/job-owned temporary numerical storage |
| `result` | input/output | caller/runtime-owned proposed trial result storage |

No commit occurs in this interface. Runtime/policy decides whether the proposed endpoint is accepted; rejected results never become committed physical history.

## Time semantics

`swap5_interval_t` carries `t0_seconds` and `t1_seconds`. Seconds are a physical unit, not a calendar control unit. The origin is caller-defined, so the kernel contract contains no requirement to start at midnight, align to a day, or respect month/year boundaries.

A kernel trial requires `t1 > t0`. Reporting, forcing segmentation, solver substeps, events and coupling windows remain separate responsibilities.

## Data-layout freedom

The six domain types are abstract. KRS-1 therefore does not prescribe a one-object-per-column production layout. Concrete implementations may use SoA storage, IDs, pools, batches and worker scratch while exposing this logical contract.

Result and scratch objects are caller-owned rather than allocated by the trial call. This avoids making per-trial heap allocation part of the kernel API and keeps MultiSWAP batching/vectorisation options open.

## Explicit exclusions

The kernel seam contains no:

- file or path input;
- Fortran file-unit contract;
- parsing or serialization;
- hidden saved model state;
- calendar clock access;
- MODFLOW cell/tile composition;
- runtime retry or fallback policy;
- concrete Richards implementation;
- mass-balance tolerance;
- B2 qualification claim.

The source guard checks several of these exclusions mechanically at the seam boundary.

## Qualification

KRS-1 has two focused gates:

1. `tests/kernel/check_kernel_seam_source.py` checks the required ownership/intents and rejects file-I/O primitives, hidden `SAVE` state, MODFLOW composition and calendar-clock access in the seam module.
2. `tests/kernel/test_kernel_seam_contract.f90` implements temporary derived fixture types and a dummy kernel only to prove the abstract interface compiles and dispatches correctly. It verifies a non-midnight/non-day interval, committed-state non-mutation, worker-scratch mutation and caller-owned result mutation.

The fixture is not SWAP physics and is never admissible as B2.

## VQ relationship

VQ-1d must remain blocked after KRS-1 because the production source still lacks:

- a concrete physical kernel implementation;
- a full-accuracy implementation bound to `swap5_kernel_t`;
- the production result/mass/transaction surface required by VQ-1d3;
- a non-synthetic VQ production adapter.

KRS-1 only provides the source-level integration point those later components must implement.

## Architecture-invariant check

| Invariant | KRS-1 assessment |
| --- | --- |
| 1 | PASS at contract level: one kernel seam, no policy-specific kernel variants. |
| 2 | PASS at seam level: no file/path/I/O inputs. |
| 3 | PASS: parameters, state, forcing, numerics, scratch and result are distinct domains. |
| 4 | PRESERVED: no state layout or per-column duplication is prescribed. |
| 5 | PASS at contract level: scratch is separately worker/job mutable. |
| 6 | PRESERVED: abstract logical API leaves SoA/pools/batches open. |
| 7 | PARTIAL: committed state is input-only and trial result is separate; real rollback still needs runtime/implementation proof. |
| 8 | PRESERVED: numerical configuration is separate; warm-start storage is not made physical state. |
| 9 | PASS at contract level: generic positive `[t0,t1]`, no day boundary. |
| 10 | PRESERVED: arbitrary coupling-window durations fit the same interval type. |
| 11 | PRESERVED: no coupling special case is introduced. |
| 13 | PRESERVED, not qualified: no tolerance or rounded balance is introduced. |
| 16 | PRESERVED: caller-owned result/scratch avoid mandatory per-trial allocation. |
| 20 | PRESERVED: the kernel seam does not hard-code a Richards implementation. |
| 23 | PASS at contract level: numerical policy is separate from physical parameter/state domains. |
| 25 | PRESERVED: reference is a future numerical policy on the same kernel. |
| 26 | PRESERVED: result is an explicit domain available for diagnostics. |
| 28 | PASS at boundary level: no MODFLOW/tile composition. |
| 29 | PASS at seam level: no file, path, midnight/day or direct MODFLOW assumption. |
| 30 | PASS for this slice: contract, exclusions, tests and VQ non-admission are explicit. |

## Next safe production step

The next KRS slice should bind a **real migrated kernel trial implementation** to `swap5_kernel_t` while keeping commit/retry orchestration outside the trial. Until that exists, `DEFERRED_NO_KERNEL_IMPLEMENTATION` and the VQ B2 blocker remain mandatory.
