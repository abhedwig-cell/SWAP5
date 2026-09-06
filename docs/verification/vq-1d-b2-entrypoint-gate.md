# VQ-1d B2 reference-entrypoint admission gate

**Workstream:** VQ  
**Slice:** VQ-1d1..VQ-1d3  
**Production observation baseline:** `bfea91d4a26f7165daee8a9df7c969731310c47f`  
**Current qualified B1 oracle:** `B1.8`  
**Production code changed:** no

## Purpose

The corrected-reference chain now uses `B1.8` as the legacy oracle. VQ-1d defines the next edge: `B1.8 -> B2`, where B2 must be the integrated full-accuracy SWAP5 reference implementation.

VQ must not infer B2 from architecture documents, prototypes, external/unmerged source trees or a future intended API. A numerical B1 -> B2 comparison is admitted only when one exact repository commit contains a callable reference-mode entrypoint, a valid reference-seam declaration and a semantic result contract.

## B1.8 oracle handoff

`B1.5p1` established the provenance-repaired five-fix reference. `B1.6` added SWAP-009, `B1.7` added SWAP-010, and `B1.8` adds SWAP-013, the PDI `HA/H0` relational input-domain guard.

```text
snapshot                B1.8
patches                 SWAP-001, -005, -006, -007, -008, -009, -010, -013
source members          63
source bytes            1,860,493
source manifest SHA-256 e32395a6dc1c4ad0caa551739c411669f0b51117dcf68ba719cad75a82fbdcae
oracle status           QUALIFIED_NUMERICAL_BEHAVIOURAL
```

B1.8 changes invalid PDI input acceptance only; valid PDI numerical behavior is unchanged from B1.7. The B2 gate nevertheless rejects stale B1.7 candidate/evidence metadata after B1.8 admission.

## VQ-1d1 — oracle and evidence identity

`tools/vq/b2_reference_gate.py` reads the current corrected-reference oracle directly from `reference/swap-4.3.1/b1-manifest.yml` and requires the candidate to match:

- snapshot;
- oracle qualification status;
- reconstructed source-manifest SHA-256.

The candidate also pins an exact production observation commit. `observation_baseline` and `b2.commit` must be exact 40-character SHAs and must be identical.

When stored evidence is supplied, the gate regenerates its fail-closed projection and rejects drift between live candidate state and stored evidence.

## VQ-1d2 — executable reference seam

A candidate marked `READY_FOR_VQ_B1_TO_B2` must declare a machine-readable `SWAP5-B2-reference-seam-v1` path.

The seam must prove, on the same implementation commit:

- integrated callable entrypoint path and symbol;
- full-accuracy `reference` numerical policy that does not change physics;
- explicit parameters, committed state, forcing and numerical configuration;
- generic `[t0,t1]` with no required calendar boundary;
- checkpoint -> trial/retry -> commit/rollback semantics;
- rejected trials do not mutate committed state;
- endpoint state, canonical results, unrounded mass accounting and transaction diagnostics;
- absence of kernel file/path, MODFLOW tile-fraction and hidden calendar assumptions.

See `docs/verification/vq-1d2-b2-reference-seam-contract.md`.

## VQ-1d3 — semantic result contract

The seam's result path must itself satisfy `SWAP5-B2-reference-result-v1` and be bound to the same implementation commit.

Accepted results are normalized for VQ as `SWAP5-B2-reference-result-record-v1`. The validator checks committed endpoint semantics, stable physical identifiers, transaction identity, diagnostics and provenance and independently recomputes:

```text
delta_storage = end_total - start_total
net_external  = sum(signed external boundary amounts)
residual      = delta_storage - net_external
```

Rounded reporting cannot satisfy the hard mass gate. VQ-1d3 deliberately does not introduce a universal production mass tolerance.

See `docs/verification/vq-1d3-b2-canonical-result-contract.md`.

## Complete admission chain

A READY candidate must satisfy all of:

```text
current qualified B1.8 identity
  -> exact production observation/B2 commit
  -> integrated callable reference entrypoint
  -> SWAP5-B2-reference-seam-v1
  -> SWAP5-B2-reference-result-v1
  -> required B2 capabilities
  -> canonical VQ result surface
```

A missing, invalid or commit-mismatched seam/result contract is a qualification failure even if legacy capability booleans are all `true`.

## Current repository observation

The pinned production observation commit `bfea91d4a26f7165daee8a9df7c969731310c47f` contains no integrated production B2 reference seam. B1.8 admission changes corrected-reference input validation only and does not create such a seam.

The real candidate therefore remains:

```text
B1.8 corrected-reference oracle          PASS
Integrated B2 callable entrypoint        ABSENT
Reference-seam declaration               ABSENT
Semantic B2 result contract              ABSENT
Unrounded B2 mass accounting             ABSENT
Transaction diagnostics                  ABSENT
B1.8 -> B2 numerical comparison          BLOCKED
```

No synthetic B2 result is generated and no legacy implementation is relabelled as B2.

## Qualification coverage

The integrated VQ tests cover positive fixtures and fail-closed cases for:

- stale B1 snapshot/source identity;
- observation/B2 commit mismatch;
- missing entrypoint or seam;
- invalid seam semantics;
- seam/result commit mismatch;
- invalid result contract;
- missing required capability;
- stored evidence drift.

Fixture PASS qualifies gate logic only. It does not claim that production SWAP5 already satisfies the seam.

## Relationship to VQ-1e1

VQ-1e1 builds the executable transaction/generic-time verifier on top of the VQ-1d3 canonical result record. Its synthetic fixture remains explicitly `VERIFIER_HARNESS_ONLY`; real B2 transaction/time qualification cannot start until this VQ-1d admission gate passes for a production seam.

## Architecture invariants

The VQ-1d chain directly protects invariants 1, 2, 3, 7, 8, 9, 13, 23, 25, 26, 28, 29 and 30 and prepares later qualification of 10-12, 14-15 and 24.

## Qualification decision

```text
B1.8 corrected-reference oracle               PASS
VQ-1d1 oracle/evidence gate                    executable
VQ-1d2 semantic seam gate                      executable
VQ-1d3 canonical result gate                   executable
B2 integrated target availability              BLOCKED
B1.8 -> B2 numerical qualification             NOT STARTED / FAIL-CLOSED
```

## Next safe step

TX/HY/RT supplies one real integrated full-accuracy reference-mode seam. VQ then pins that exact B2 commit, switches the candidate to `READY_FOR_VQ_B1_TO_B2`, reruns the full admission chain, normalizes the first accepted result, independently recomputes mass, performs the first B1.8 -> B2 control comparison and only then runs VQ-1e production transaction/generic-time cases.
