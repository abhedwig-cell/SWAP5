# VQ-1d2 B2 reference-seam contract

**Workstream:** VQ  
**Slice:** VQ-1d2  
**Depends on:** VQ-1d1 / PR #38  
**Production code changed:** no

## Purpose

VQ-1d established a fail-closed boundary before any B1 -> B2 numerical comparison. VQ-1d1 then bound that boundary to the current corrected-reference oracle and stored evidence. VQ-1d2 closes one remaining trust gap: a future B2 candidate may not become admissible merely by declaring capability booleans.

A candidate with status `READY_FOR_VQ_B1_TO_B2` must point to a machine-readable `SWAP5-B2-reference-seam-v1` declaration. The declaration is checked against the actual repository checkout and against the candidate record.

This is a verification acceptance surface, not a prescription for the internal Fortran type layout or ABI.

## Contract files

```text
tools/vq/contracts/b2-reference-seam.schema.json
tools/vq/b2_seam_contract.py
```

The JSON schema documents the stable semantic fields. The Python validator performs fail-closed semantic and repository checks without adding a production dependency.

## Required implementation identity

The declaration must identify:

- the exact 40-character Git commit;
- an integrated callable entrypoint path;
- a non-empty entrypoint symbol/name;
- a canonical result-contract path.

Both declared repository paths must exist in the pinned checkout. The B2 admission gate additionally requires the declaration's commit, entrypoint path and result-contract path to equal the corresponding candidate fields.

## Reference policy

The reference seam must declare:

```text
reference_policy_id = reference
full_accuracy       = true
changes_physics     = false
```

The last condition is deliberate. Reference/balanced/throughput are numerical policies; changing policy may not silently change physical options or formulations.

## Explicit input separation

The seam exposes the following logical inputs independently:

```text
parameters
committed_state
forcing
numerical_config
interval [t0,t1]
```

For parameters, state, forcing and numerical configuration the declaration must state that each input is explicit and that a file/path is not required by the kernel seam. This protects the kernel/I/O boundary without dictating whether the runtime uses objects, handles, IDs, pools or SoA storage internally.

The interval must be generic `[t0,t1]`; a calendar/day boundary may not be required.

## Transaction semantics

The declaration must state:

```text
checkpoint -> trial/retry -> commit or rollback
rejected trial mutates committed state = false
trial endpoint is returned explicitly  = true
```

This is the minimum seam needed for later VQ-1e rollback, rerun and warm-start qualification. It intentionally distinguishes a trial endpoint from an implicitly committed state.

## Result and mass contract

The seam must expose:

- endpoint state;
- canonical results;
- unrounded mass accounting;
- transaction diagnostics.

Mass acceptance is hard and uses the logical identity:

```text
delta_storage - net_external
```

Rounded report values may not be used as the acceptance oracle.

## Required diagnostics

At minimum the result surface must make the following machine-auditable:

```text
accepted
execution_class
retry_count
solver_cost
balance_residual
```

Additional diagnostics are allowed. These five fields are the minimum needed to distinguish accepted/rejected work, normal/relaxed/fallback execution and hard water-balance status.

## Forbidden dependencies

A valid B2 reference seam explicitly declares the absence of:

```text
kernel file I/O
kernel path dependency
kernel knowledge of MODFLOW tile fractions
hidden calendar/day-boundary assumption
```

The contract does not prohibit adapters, runtimes or couplers from owning those concerns outside the kernel.

## Admission relationship

For a READY candidate, `tools/vq/b2_reference_gate.py` now requires all three layers:

```text
1. exact current B1 oracle and evidence identity
2. concrete integrated B2 files + legacy capability attestations
3. valid SWAP5-B2-reference-seam-v1 declaration matching the candidate
```

Failure modes distinguish a missing contract, an invalid contract and a contract/candidate identity mismatch.

The current real repository candidate remains `BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT`; it therefore declares no seam path and is not falsely promoted to B2.

## Invariant check

VQ-1d2 directly operationalizes invariants 1, 2, 3, 7, 8, 9, 13, 23, 25, 26, 28, 29 and 30. It does not yet qualify coupling-specific head/flux equality or response tangents; those remain later B2/coupling qualification surfaces.

No production physics, numerical formulation or solver policy is changed by this slice.

## Next safe production handoff

TX/HY/RT may choose its internal implementation freely, but before VQ accepts it as B2 it must provide, on one exact integrated commit:

1. the callable reference entrypoint;
2. the canonical result contract;
3. a valid reference-seam declaration;
4. the candidate repin to that same commit.

Only then may VQ switch the candidate to `READY_FOR_VQ_B1_TO_B2`, run the admission gate, and—after PASS—start the first B1.6 -> B2 numerical comparison.
