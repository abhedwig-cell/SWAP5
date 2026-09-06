# VQ-1d B2 reference-entrypoint admission gate

**Workstream:** VQ  
**Slice:** VQ-1d  
**Production observation baseline:** `5576279c915f4d4fbccf3ff182aa480306489080`  
**Current qualified B1 oracle:** `B1.6`  
**Production code changed:** no

## Purpose

The corrected-reference chain now uses `B1.6` as the legacy oracle. VQ-1d is the next edge: `B1.6 -> B2`, where B2 must be the integrated full-accuracy SWAP5 reference implementation.

VQ must not infer B2 from architecture documents, prototypes, an external/unmerged source tree or a future intended API. A numerical B1 -> B2 comparison is admitted only when the repository contains an exact, callable reference-mode entrypoint and an explicit result contract on a pinned Git commit.

## B1 oracle handoff

`B1.5p1` first established the provenance-repaired five-fix corrected-reference oracle. `B1.6` adds the separately qualified SWAP-009 PDI Kelvin-sign correction and is now the current corrected reference.

B1.6 is pinned by:

```text
snapshot                B1.6
patches                 SWAP-001, -005, -006, -007, -008, -009
source members          63
source bytes            1,860,085
source manifest SHA-256 aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0
oracle status           QUALIFIED_NUMERICAL_BEHAVIOURAL
```

The B2 admission gate rejects a stale B1 oracle such as B1.5p1.

## Admission contract

`tools/vq/b2_reference_gate.py` evaluates a machine-readable candidate record and fails closed unless all of the following are true:

1. the B1 oracle is exactly the current qualified `B1.6` snapshot;
2. B2 is pinned to an exact 40-character Git commit SHA;
3. the candidate status is `READY_FOR_VQ_B1_TO_B2`;
4. an integrated callable reference entrypoint path is declared and exists on that checkout;
5. a canonical result-contract path is declared and exists;
6. the numerical policy is explicitly identified as the reference policy;
7. the entrypoint accepts a generic `[t0,t1]` interval;
8. committed physical state, forcing and numerical configuration are explicit inputs rather than hidden global/file state;
9. parameters/state/forcing/numerical policy/results remain separable at the adapter boundary;
10. the returned result supports canonical comparison, unrounded mass accounting and transaction diagnostics.

The corresponding required capability flags are:

```text
callable_reference_entrypoint
generic_interval_t0_t1
committed_state_input
forcing_input
numerical_config_separate
canonical_result_output
unrounded_mass_accounting
transaction_diagnostics
```

The gate intentionally does not prescribe the internal SWAP5 object layout. It only defines the minimum verification surface needed to exercise the architecture invariants.

## Current repository observation

The production observation baseline contains no integrated production B2 entrypoint that VQ can honestly execute and pin. B1.6 admission changes legacy reference/tooling state only and does not create such a production seam.

`tools/vq/cases/b2-reference-candidate.json` therefore states:

```text
B1.6 corrected-reference oracle          PASS
Integrated B2 callable entrypoint        ABSENT
B2 reference-policy selector             ABSENT
Canonical B2 result contract             ABSENT
Unrounded B2 mass accounting             ABSENT
Transaction diagnostics                  ABSENT
B1.6 -> B2 numerical comparison          BLOCKED
```

No synthetic B2 result is generated and no legacy implementation is relabelled as B2.

## Unit qualification

`tools/vq/test_b2_reference_gate.py` covers:

- an explicitly blocked candidate fails closed;
- a stale B1.5p1 oracle fails after B1.6 admission;
- a nominally ready candidate without an integrated entrypoint fails;
- a candidate missing a required capability fails;
- a complete integrated fixture with all required fields/files passes admission.

The fixture PASS qualifies the gate logic only. It does not claim that the real SWAP5 repository already provides those production capabilities.

## Relationship to architecture invariants

This gate directly protects invariants 1, 2, 3, 7, 8, 9, 13, 23, 25, 26, 29 and 30: B2 must be the actual common kernel/reference path, time is generic, committed physical state is explicit, numerical policy remains separate from physics, hard mass uses unrounded accounting, and qualification may not rely on hidden legacy/file assumptions.

## Qualification decision

```text
B1.6 corrected-reference oracle               PASS
VQ-1d adapter admission gate implementation   PASS
B2 integrated target availability             BLOCKED
B1.6 -> B2 numerical qualification            NOT STARTED / FAIL-CLOSED
```

This is the correct state until TX/HY/RT integrate a real reference-mode seam.

## Next safe step

The production integration workstream supplies an actual callable SWAP5 reference-mode entrypoint and canonical result contract. VQ then:

1. pins the exact B2 commit;
2. updates `b2-reference-candidate.json` to `READY_FOR_VQ_B1_TO_B2` without weakening any capability requirement;
3. reruns `tools/vq/b2_reference_gate.py`;
4. only after a PASS executes the first B1.6 -> B2 control comparison;
5. subsequently adds VQ transaction, generic-time, warm-start and unrounded hard-mass qualification gates.
