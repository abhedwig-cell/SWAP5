# VQ-1d B2 reference-entrypoint admission gate

**Workstream:** VQ  
**Slice:** VQ-1d  
**Observation baseline:** `953f426db5ebd6bf52b718967b0b283fb749bc4a`  
**Qualified B1 oracle:** `B1.5p1`  
**Production code changed:** no

## Purpose

VQ-1c qualified `B1.5p1` as the numerical/behavioural corrected-reference oracle. VQ-1d is the next edge in the reference chain: `B1.5p1 -> B2`, where B2 must be the integrated full-accuracy SWAP5 reference implementation.

VQ must not infer B2 from architecture documents, prototypes, an external/unmerged source tree or a future intended API. A numerical B1 -> B2 comparison is admitted only when the repository contains an exact, callable reference-mode entrypoint and an explicit result contract on a pinned Git commit.

## Current repository observation

At the pinned observation baseline the repository remains documentation-led. `docs/architecture/implementation-status.md` explicitly records that several active production refactors are not yet mirrored into this repository as integrated source. The full-accuracy SWAP5 reference mode is `PARTIAL`, not an end-to-end qualified runtime entrypoint.

The repository therefore contains no production B2 entrypoint that VQ can honestly execute and pin.

This is a verification boundary, not a model failure.

## Admission contract

`tools/vq/b2_reference_gate.py` evaluates a machine-readable candidate record and fails closed unless all of the following are true:

1. the B1 oracle is exactly `B1.5p1` and carries the VQ qualification `QUALIFIED_NUMERICAL_BEHAVIOURAL`;
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

## Current machine-readable candidate

`tools/vq/cases/b2-reference-candidate.json` pins the current observation and states:

```text
B2 status: BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT
B2 commit: 953f426db5ebd6bf52b718967b0b283fb749bc4a
entrypoint: absent
result contract: absent
reference policy selector: absent
required runtime capabilities: not yet demonstrated
```

The corresponding VQ decision is:

```text
B1.5p1 corrected-reference oracle       PASS
Integrated B2 callable entrypoint        ABSENT
B2 reference-policy selector             ABSENT
Canonical B2 result contract             ABSENT
Unrounded B2 mass accounting             ABSENT
Transaction diagnostics                  ABSENT
B1 -> B2 numerical comparison            BLOCKED
```

No synthetic B2 result is generated and no legacy implementation is relabelled as B2.

## Unit qualification

`tools/vq/test_b2_reference_gate.py` covers four admission behaviours:

- an explicitly blocked candidate fails closed;
- a nominally ready candidate without an integrated entrypoint fails;
- a candidate missing one required capability fails;
- a complete integrated fixture with all required fields/files passes admission.

The fixture PASS only qualifies the gate logic. It does not claim that the real SWAP5 repository already provides those production capabilities.

## Relationship to the architecture invariants

This gate directly protects:

- invariant 1: B2 must be the actual common SWAP5 kernel/reference path, not a parallel verification implementation;
- invariant 2: VQ consumes a callable typed boundary rather than introducing legacy file I/O into the kernel;
- invariant 3: forcing, physical state and numerical configuration remain distinguishable;
- invariants 7 and 8: the comparison surface must expose committed-state and transaction semantics;
- invariant 9: the entrypoint is generic over `[t0,t1]`;
- invariant 13: hard mass qualification requires unrounded accounting;
- invariant 23: reference numerical policy is explicit and separate from physics;
- invariant 25: the full-accuracy reference mode remains a first-class execution policy;
- invariant 26: transaction/runtime diagnostics are part of qualification evidence;
- invariant 29: the adapter cannot depend silently on midnight, day length or legacy file invocation;
- invariant 30: admission is an explicit executable gate rather than an architectural assumption.

## Qualification decision

```text
VQ-1d adapter admission gate implementation   PASS
B2 integrated target availability             BLOCKED
B1.5p1 -> B2 numerical qualification          NOT STARTED / FAIL-CLOSED
```

This is the correct state until TX/HY/RT integrate a real reference-mode seam.

## Next safe step

The production integration workstream supplies an actual callable SWAP5 reference-mode entrypoint and canonical result contract. VQ then:

1. pins the exact B2 commit;
2. updates `b2-reference-candidate.json` to `READY_FOR_VQ_B1_TO_B2` without weakening any capability requirement;
3. reruns `tools/vq/b2_reference_gate.py`;
4. only after a PASS executes the first B1.5p1 -> B2 control comparison;
5. subsequently adds the VQ-1e transaction, generic-time, warm-start and unrounded hard-mass qualification gates.
