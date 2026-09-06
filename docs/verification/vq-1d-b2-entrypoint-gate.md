# VQ-1d B2 reference-entrypoint admission gate

**Workstream:** VQ  
**Slice:** VQ-1d / VQ-1d1  
**Current qualified B1 oracle:** `B1.7`  
**Production code changed:** no

## Purpose

VQ-1d is the fail-closed handoff from the corrected legacy oracle to the future integrated full-accuracy SWAP5/B2 reference implementation. VQ must not infer B2 from architecture documents, prototypes, external source trees or intended APIs.

The corrected-reference chain currently uses `B1.7`, which adds the qualified SWAP-010 model-7 capacity-derivative consistency correction to B1.6. B1.7 is identified by:

```text
snapshot                B1.7
patches                 SWAP-001, -005, -006, -007, -008, -009, -010
source members          63
source bytes            1,860,091
source manifest SHA-256 62939097cfcdb59f8fe8c9161356fc703d7c54d6dd61ab3c31b19c2cfea6a5ba
oracle status           QUALIFIED_NUMERICAL_BEHAVIOURAL
```

## VQ-1d admission boundary

`tools/vq/b2_reference_gate.py` rejects numerical B1 -> B2 comparison unless a candidate supplies:

1. the exact current qualified B1 oracle;
2. matching reconstructed B1 source-manifest identity;
3. an exact B2 observation/implementation commit;
4. status `READY_FOR_VQ_B1_TO_B2`;
5. integrated callable reference entrypoint;
6. semantic result-contract path;
7. explicit `reference` numerical policy;
8. generic `[t0,t1]`;
9. explicit committed-state and forcing inputs with separate numerical configuration;
10. canonical results, unrounded mass accounting and transaction diagnostics;
11. the VQ-1d2 reference-seam contract and VQ-1d3 result contract when READY.

The gate does not prescribe internal SWAP5 object layout.

## VQ-1d1 oracle/evidence consistency

The current B1 identity is read from `reference/swap-4.3.1/b1-manifest.yml`; it is not hardcoded in the B2 gate. Candidate snapshot, qualification and reconstructed source-manifest hash must match that manifest.

The declared production observation baseline and B2 commit must match. Stored gate evidence is compared with a projection of the live candidate assessment.

```text
expected BLOCKED + candidate/evidence consistent  -> CI PASS
oracle/evidence drift                             -> CI FAIL
real READY candidate satisfying all contracts     -> admission PASS
```

This distinction allows an honestly absent B2 implementation to remain fail-closed without treating absence as a physics failure, while preventing stale evidence from remaining green after a B1 oracle update.

## Current repository observation

The pinned B2 observation commit is still a pre-B2 repository state and contains no integrated production reference entrypoint. Later B1.7 corrected-reference admission changes the legacy oracle but does not manufacture a B2 implementation.

Current state:

```text
B1.7 corrected-reference oracle          PASS
candidate/evidence oracle synchronization PASS
Integrated B2 callable entrypoint        ABSENT
B2 reference seam                        ABSENT
Semantic B2 result contract              ABSENT
B1.7 -> B2 numerical comparison          BLOCKED
```

No synthetic B2 result is generated and no legacy implementation is relabelled as B2.

## Relationship to VQ-1d2 and VQ-1d3

VQ-1d1 protects identity/evidence synchronization. VQ-1d2 makes the input/reference seam semantic and executable. VQ-1d3 makes the output/result semantics and canonical VQ result record executable.

A future READY chain is therefore:

```text
current B1 oracle
 -> exact B2 commit
 -> integrated reference entrypoint
 -> SWAP5-B2-reference-seam-v1
 -> SWAP5-B2-reference-result-v1
 -> canonical VQ result record
```

## Invariant check

VQ-1d/1d1 directly protects invariants 1, 2, 3, 7, 8, 9, 13, 23, 25, 26, 29 and 30. VQ-1d1 particularly enforces invariant 30 by making oracle/evidence synchronization executable.

## Qualification decision

```text
B1.7 corrected-reference oracle               PASS
VQ-1d adapter admission implementation         PASS
VQ-1d1 oracle/evidence consistency gate        PASS when integrated CI is green
B2 integrated target availability              BLOCKED
B1.7 -> B2 numerical qualification             NOT STARTED / FAIL-CLOSED
```

## Next safe step

TX/HY/RT supplies an actual callable full-accuracy SWAP5 reference seam and semantic result contract on one exact commit. VQ then repins the candidate to READY, validates the full chain, normalizes an accepted result, independently recomputes mass and only then starts B1.7 -> B2 numerical comparison and VQ-1e.
