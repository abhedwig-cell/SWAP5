# VQ-1d B2 reference-entrypoint admission gate

**Workstream:** VQ  
**Slice:** VQ-1d  
**Production observation baseline:** `402f278f94eb15261289bf6c2a259e7840e9c155`  
**Current qualified B1 oracle:** `B1.9`  
**Production code changed:** no

## Purpose

The corrected-reference chain now uses `B1.9` as the legacy oracle. VQ-1d is therefore the edge `B1.9 -> B2`, where B2 must be the integrated full-accuracy SWAP5 reference implementation.

VQ must not infer B2 from architecture documents, prototypes, an external/unmerged source tree or a future intended API. A numerical B1 -> B2 comparison is admitted only when the repository contains an exact, callable reference-mode entrypoint and explicit result contract on a pinned commit.

## B1 oracle handoff

B1.9 adds SWAP-012 to qualified B1.8. The correction is isolated from historical SWAP-011 content and fixes only the `prhead` inverse for hydraulic models 3 and 5-12.

```text
snapshot                B1.9
patches                 SWAP-001, -005, -006, -007, -008, -009, -010, -013, -012
source members          63
source bytes            1,863,300
source manifest SHA-256 5e28510813e5748bae52ffd5c08027bb55b63858aa994ea90635b632826de657
oracle status           QUALIFIED_NUMERICAL_BEHAVIOURAL
```

The B2 gate rejects stale B1 oracles, including B1.8 after B1.9 admission.

## Admission contract

`tools/vq/b2_reference_gate.py` fails closed unless:

1. the B1 oracle is exactly current qualified B1.9;
2. B2 is pinned to an exact commit SHA;
3. candidate status is `READY_FOR_VQ_B1_TO_B2`;
4. an integrated callable reference entrypoint exists;
5. a canonical result contract exists;
6. reference numerical policy is explicit;
7. the entrypoint accepts generic `[t0,t1]`;
8. committed state, forcing and numerical configuration are explicit inputs;
9. data categories remain separable at the adapter boundary;
10. canonical results include unrounded mass accounting and transaction diagnostics.

Required capability flags remain:

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

## Current repository observation

The pinned production observation baseline still contains no integrated B2 entrypoint/result contract that VQ can honestly execute. B1.9 changes corrected legacy inverse behaviour and verification tooling only; it does not create a production B2 seam.

```text
B1.9 corrected-reference oracle          PASS
Integrated B2 callable entrypoint        ABSENT
B2 reference-policy selector             ABSENT
Canonical B2 result contract             ABSENT
Unrounded B2 mass accounting             ABSENT
Transaction diagnostics                  ABSENT
B1.9 -> B2 numerical comparison          BLOCKED
```

No synthetic B2 result is generated and no legacy implementation is relabelled as B2.

## Relationship to architecture invariants

The gate protects invariants 1, 2, 3, 7, 8, 9, 13, 23, 25, 26, 29 and 30. In particular, B2 must be the actual common-kernel reference path; time must be generic; committed physical state and numerical policy must be explicit; and hard mass qualification requires unrounded accounting.

## Qualification decision

```text
B1.9 corrected-reference oracle               PASS
VQ-1d adapter admission gate implementation   PASS
B2 integrated target availability             BLOCKED
B1.9 -> B2 numerical qualification            NOT STARTED / FAIL-CLOSED
```

## Next safe step

Once TX/HY/RT provide a real callable SWAP5 reference-mode seam and canonical result contract, VQ pins the exact B2 commit, changes the candidate to `READY_FOR_VQ_B1_TO_B2`, reruns the admission gate, and only after PASS starts B1.9 -> B2 numerical, transaction, generic-time, warm-start and hard-mass qualification.
