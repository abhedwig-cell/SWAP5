# VQ-1d3 canonical B2 reference-result contract

**Workstream:** VQ  
**Slice:** VQ-1d3  
**Stacked baseline:** VQ-1d2 reference-seam contract  
**Production code changed:** no

## Purpose

VQ-1d2 defines the admissible input/seam boundary for a future integrated SWAP5/B2 reference implementation. VQ-1d3 closes the other half of that boundary: the result returned by the reference seam must have explicit, transaction-safe and independently verifiable semantics before VQ may start a B1.6 -> B2 numerical comparison.

A file merely named `result.schema.json` is not evidence. A READY candidate must point to a semantic result declaration with contract id:

```text
SWAP5-B2-reference-result-v1
```

The declaration is validated by `tools/vq/b2_result_contract.py` and is bound through the VQ-1d2 seam to the same exact implementation commit.

## Two-layer design

VQ deliberately separates the production result contract from the normalized comparison record.

### Production-facing semantic contract

`SWAP5-B2-reference-result-v1` states what the integrated implementation guarantees. It does not prescribe Fortran derived types, C ABI structs, Python classes or the internal memory layout.

Machine-readable declaration schema:

```text
tools/vq/contracts/b2-reference-result-contract.schema.json
```

Semantic validator:

```text
tools/vq/b2_result_contract.py
```

### VQ canonical normalized record

Adapters normalize an accepted B2 reference interval to:

```text
SWAP5-B2-reference-result-record-v1
```

Schema:

```text
tools/vq/contracts/b2-reference-result-record.schema.json
```

Validator:

```text
tools/vq/b2_result_record.py
```

This normalized record is the comparison surface for B1.6 -> B2 and later reference -> optimized/fallback qualification. It is not a required production serialization format.

## Required result semantics

The result contract requires all of the following.

### Interval

The result identifies the exact requested generic interval `[t0,t1]`.

```text
t0 explicit                         true
t1 explicit                         true
generic [t0,t1]                     true
calendar boundary required          false
returned interval matches request   true
```

No day, midnight, month or year boundary is implicit.

### Endpoint state

The canonical endpoint is the accepted committed physical state at `t1`.

A rejected trial may expose a provisional endpoint for diagnostics or warm start internally, but it may not replace the canonical committed endpoint.

Stable variable identifiers are required so VQ does not infer physical meaning from array position.

### Physical result values

Canonical physical result values require:

```text
stable result ids
explicit units/basis
unrounded values
rejected trials excluded
retry totals counted exactly once
```

The result contract is shared by reference, normal, relaxed and fallback execution classes. An execution policy may change solver effort or retry history, but it may not silently change the physical result schema or mass identity.

## Mass accounting

VQ-1d3 embeds the existing VQ mass-accounting record as the authoritative mass section:

```text
tools/vq/contracts/mass-accounting-record.schema.json
```

For every accepted interval VQ independently recomputes:

```text
delta_storage = storage.end_total - storage.start_total
net_external  = sum(signed_amount for external boundary terms)
residual      = delta_storage - net_external
```

The implementation-reported residual remains diagnostic. Rounded `.BAL`/`.BLC` style output cannot satisfy the hard B2 mass gate.

`tools/vq/b2_result_record.py` returns the independently recomputed residual but deliberately reports:

```text
mass_tolerance_applied = false
```

VQ-1d3 therefore does not invent a universal acceptance tolerance. A mass PASS still requires a separately qualified tolerance/provenance record.

## Transaction semantics

A canonical accepted B2 result contains at least:

```text
accepted
accepted_trial_id
trial_count
retry_count
commit_count
rollback_count
rejected_trials_excluded_from_committed_totals
```

For the accepted interval record:

```text
accepted       = true
commit_count   = 1
retry_count    = trial_count - 1
rollback_count = retry_count
```

The mass record and transaction record must identify the same accepted trial. Rejected-trial physical totals may not leak into committed results.

This makes the output surface directly usable by TX-ROLLBACK-01, TX-COMMIT-01 and TX-ACCOUNT-01.

## Diagnostics

The minimum canonical diagnostic surface contains:

```text
accepted
execution_class
retry_count
solver_iterations
solver_cost
fallback_used
balance_residual
```

Diagnostics describe the route used to obtain the accepted physical result. They do not define or substitute for that physical result.

The diagnostic balance residual must be consistent with the residual independently recomputed from the canonical mass record. Acceptance is still based on the independently recomputed value plus a qualified mass tolerance.

## Provenance

Every canonical B2 result binds:

```text
implementation_commit
numerical_policy
result_contract_version
case_id
```

The semantic result declaration itself is also bound to the exact implementation commit. The VQ-1d2 seam validator rejects a result contract for a different commit.

## Canonical record consistency checks

`tools/vq/b2_result_record.py` rejects records with, among other things:

- non-committed endpoint state;
- duplicate endpoint variable ids;
- duplicate result ids;
- non-finite physical values;
- result/mass interval mismatch;
- accepted-trial identity mismatch;
- retry/trial count mismatch;
- rollback/retry count mismatch;
- rejected trials included in committed totals;
- non-finite storage or boundary terms;
- inconsistent execution class between diagnostics and mass accounting;
- diagnostic residual inconsistent with the independently recomputed residual;
- missing implementation/policy/case provenance.

## Relationship to VQ-1d2

VQ-1d3 strengthens, rather than replaces, the reference-seam gate.

A READY candidate now needs the complete chain:

```text
exact B2 commit
   -> integrated reference entrypoint
   -> SWAP5-B2-reference-seam-v1
   -> SWAP5-B2-reference-result-v1
   -> canonical VQ result record
   -> independent mass residual recomputation
```

The seam and result contract must name the same implementation commit. The candidate, seam, entrypoint path, result-contract path and reference policy remain mutually consistent.

## Current repository state

The real candidate remains intentionally:

```text
B1.6 corrected-reference oracle        PASS
integrated B2 entrypoint                ABSENT
reference seam declaration              ABSENT
semantic B2 result contract             ABSENT
B1.6 -> B2 numerical comparison         BLOCKED
```

No synthetic production seam or result is introduced by VQ-1d3.

## Architecture invariants

This slice directly operationalizes invariants 3, 7, 8, 9, 13, 23, 25, 26, 29 and 30 and supports later qualification of 10-12, 14-15 and 24.

In particular:

- physical state/results are separated from numerical diagnostics;
- rejected trials cannot contaminate committed outputs;
- generic time is explicit;
- mass is independently recomputable from unrounded values;
- execution policy does not redefine physics;
- reference provenance is exact and machine-checkable.

## Next safe step

After VQ-1d1, VQ-1d2 and VQ-1d3 integrate, the production TX/HY/RT workstream can implement the real reference seam against these acceptance surfaces.

When that occurs VQ will:

1. pin the exact integrated B2 commit;
2. validate the seam and semantic result contract;
3. normalize the first accepted B2 result record;
4. independently recompute its mass residual;
5. execute the first B1.6 -> B2 control comparison;
6. proceed to VQ-1e transaction, rerun, warm-start and generic-time qualification.
