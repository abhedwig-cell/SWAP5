# VQ-1d2 B2 reference-seam contract

**Workstream:** VQ  
**Slice:** VQ-1d2  
**Depends on:** VQ-1d1 oracle/evidence consistency  
**Current corrected-reference oracle:** `B1.7`  
**Production code changed:** no

## Purpose

VQ-1d established a fail-closed boundary before any B1 -> B2 numerical comparison. VQ-1d1 binds that boundary to the current corrected-reference oracle and stored evidence. VQ-1d2 closes the remaining trust gap in the input side: a future B2 candidate may not become admissible merely by setting capability booleans.

A candidate with status `READY_FOR_VQ_B1_TO_B2` must point to a machine-readable `SWAP5-B2-reference-seam-v1` declaration. The declaration is checked against the actual checkout and the candidate record. It is a verification acceptance surface, not a prescription for Fortran type layout, ABI or memory layout.

## Contract files

```text
tools/vq/contracts/b2-reference-seam.schema.json
tools/vq/b2_seam_contract.py
```

## Required implementation identity

The declaration identifies the exact 40-character Git commit, integrated callable entrypoint path and symbol, and semantic result-contract path. Declared repository paths must exist. Candidate, seam, entrypoint, result contract and reference policy must agree.

## Reference policy

```text
reference_policy_id = reference
full_accuracy       = true
changes_physics     = false
```

Reference/balanced/throughput remain numerical policies. A solver policy may not silently change physical options or formulations.

## Explicit input separation

The seam exposes independently:

```text
parameters
committed_state
forcing
numerical_config
interval [t0,t1]
```

Parameters, state, forcing and numerical configuration are explicit and do not require a file/path at the kernel boundary. The interval is generic `[t0,t1]`; a calendar/day boundary is not required.

## Transaction semantics

The seam declares:

```text
checkpoint -> trial/retry -> commit or rollback
rejected trial mutates committed state = false
trial endpoint returned explicitly     = true
```

This is the minimum executable boundary needed for later rollback, same-state rerun and warm-start qualification.

## Result and mass boundary

The seam exposes endpoint state, canonical results, unrounded mass accounting and transaction diagnostics. Mass uses the hard logical identity:

```text
delta_storage - net_external
```

Rounded reporting values cannot be the acceptance oracle. VQ-1d3 further requires the declared result path to satisfy `SWAP5-B2-reference-result-v1` on the same exact implementation commit.

## Diagnostics

At minimum:

```text
accepted
execution_class
retry_count
solver_iterations
solver_cost
fallback_used
balance_residual
```

Diagnostics describe the numerical route and do not define the physical result.

## Forbidden dependencies

A valid reference seam declares the absence of kernel file I/O, kernel path dependence, kernel knowledge of MODFLOW tile fractions and hidden calendar/day-boundary assumptions. Adapters, runtimes and couplers may own those concerns outside the kernel.

## Admission relationship

For a READY candidate the gate requires:

```text
1. exact current B1.7 oracle and synchronized evidence
2. concrete integrated B2 files + capability attestations
3. valid SWAP5-B2-reference-seam-v1 declaration
4. valid semantic result contract bound to the same commit
```

The current real candidate remains `BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT`; no seam path is invented.

## Invariant check

This slice operationalizes invariants 1, 2, 3, 7, 8, 9, 13, 23, 25, 26, 28, 29 and 30. It does not yet qualify coupling-specific head/flux equality or response tangents.

## Next safe production handoff

TX/HY/RT may choose its internal implementation freely, but VQ accepts it as B2 only when one exact integrated commit provides the callable reference entrypoint, semantic result contract, valid reference-seam declaration and candidate repin. Only then may VQ start the first B1.7 -> B2 numerical comparison.
