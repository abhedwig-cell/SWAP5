# VQ-1d3 canonical B2 reference-result contract

**Workstream:** VQ  
**Slice:** VQ-1d3  
**Depends on:** VQ-1d2 reference-seam contract  
**Current corrected-reference oracle:** `B1.8`  
**Production code changed:** no

## Purpose

VQ-1d2 defines the admissible input/seam boundary for a future integrated SWAP5/B2 reference implementation. VQ-1d3 closes the output half: the result returned by the reference seam must have explicit, transaction-safe and independently verifiable semantics before VQ may start a B1.8 -> B2 numerical comparison.

A file merely named `result.schema.json` is not evidence. A READY candidate must point to a semantic result declaration with contract id:

```text
SWAP5-B2-reference-result-v1
```

The declaration is validated by `tools/vq/b2_result_contract.py` and is bound through the VQ-1d2 seam to the same exact implementation commit.

## Two-layer design

VQ deliberately separates the production result contract from the normalized comparison record.

### Production-facing semantic contract

`SWAP5-B2-reference-result-v1` states what the integrated implementation guarantees without prescribing Fortran derived types, C ABI structs, Python classes or internal memory layout.

```text
tools/vq/contracts/b2-reference-result-contract.schema.json
tools/vq/b2_result_contract.py
```

### VQ canonical normalized record

Adapters normalize an accepted B2 reference interval to `SWAP5-B2-reference-result-record-v1`:

```text
tools/vq/contracts/b2-reference-result-record.schema.json
tools/vq/b2_result_record.py
```

This is the comparison surface for B1.8 -> B2 and later reference -> normal/relaxed/fallback qualification. It is not a required production serialization format.

## Required result semantics

### Interval

The result identifies the exact requested generic interval `[t0,t1]`: t0/t1 are explicit, no calendar boundary is required and the returned interval equals the requested interval.

### Endpoint state

The canonical endpoint is the accepted committed physical state at `t1`. A rejected trial may expose a provisional endpoint internally for diagnostics or warm start, but may not replace the canonical committed endpoint. Stable variable identifiers prevent VQ from inferring physical meaning from array position.

### Physical results

Canonical physical values require stable result IDs, explicit units/basis, unrounded values, exclusion of rejected trials and exactly-once accounting across retries. Reference, normal, relaxed and fallback execution classes use the same physical result schema and mass identity; execution policy may change solver effort, not physics.

## Mass accounting

The canonical result embeds the existing VQ mass record:

```text
tools/vq/contracts/mass-accounting-record.schema.json
```

For every accepted interval VQ independently recomputes:

```text
delta_storage = storage.end_total - storage.start_total
net_external  = sum(signed_amount for external boundary terms)
residual      = delta_storage - net_external
```

The implementation-reported residual is diagnostic. Rounded `.BAL`/`.BLC` style output cannot satisfy the B2 mass gate.

`tools/vq/b2_result_record.py` exposes the independently recomputed residual and deliberately reports:

```text
mass_tolerance_applied = false
```

VQ-1d3 therefore does not invent a universal acceptance tolerance. A hard mass PASS requires a separately qualified tolerance/provenance record and an actual admitted B2 result.

## Transaction semantics

A canonical accepted result contains at least:

```text
accepted
accepted_trial_id
trial_count
retry_count
commit_count
rollback_count
rejected_trials_excluded_from_committed_totals
```

For an accepted interval:

```text
accepted       = true
commit_count   = 1
retry_count    = trial_count - 1
rollback_count = retry_count
```

The mass and transaction records identify the same accepted trial. Rejected-trial totals may not leak into committed results. This output surface is directly usable by TX-ROLLBACK-01, TX-COMMIT-01 and TX-ACCOUNT-01.

## Diagnostics

Minimum diagnostics are:

```text
accepted
execution_class
retry_count
solver_iterations
solver_cost
fallback_used
balance_residual
```

Diagnostics describe the route used to obtain the accepted physical result. The diagnostic residual must be consistent with the residual VQ independently recomputes; it is not itself the acceptance oracle.

## Provenance

Every canonical result binds:

```text
implementation_commit
numerical_policy
result_contract_version
case_id
```

The semantic result declaration is bound to the same exact implementation commit as the VQ-1d2 seam.

## Canonical record consistency checks

`tools/vq/b2_result_record.py` rejects, among other things, non-committed endpoints, duplicate variable/result IDs, non-finite values, interval mismatch, accepted-trial mismatch, retry/trial or rollback/retry mismatch, more or fewer than one commit, rejected-trial leakage, non-finite storage/boundary terms, execution-class inconsistency, residual inconsistency and missing provenance.

## Complete admission chain

A READY candidate now needs:

```text
exact B2 commit
   -> integrated reference entrypoint
   -> SWAP5-B2-reference-seam-v1
   -> SWAP5-B2-reference-result-v1
   -> canonical VQ result record
   -> independent mass residual recomputation
```

Candidate, seam, entrypoint path, result-contract path, implementation commit and reference policy must remain mutually consistent.

## Current repository state

```text
B1.8 corrected-reference oracle        PASS
integrated B2 entrypoint                ABSENT
reference seam declaration              ABSENT
semantic B2 result contract             ABSENT
B1.8 -> B2 numerical comparison         BLOCKED
```

No synthetic production seam or result is introduced.

## Architecture invariants

This slice directly operationalizes invariants 3, 7, 8, 9, 13, 23, 25, 26, 29 and 30 and prepares qualification of 10-12, 14-15 and 24.

## Next safe step

After VQ-1d1/1d2/1d3 integrate, TX/HY/RT can implement the real reference seam against these acceptance surfaces. VQ then pins the exact integrated B2 commit, validates seam and result contract, normalizes the first accepted B2 record, independently recomputes mass, executes the first B1.8 -> B2 control comparison, and runs VQ-1e transaction/rerun/warm-start/generic-time qualification.
