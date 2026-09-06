# VQ-1 integration record

**Workstream:** VQ  
**Current reference-line re-read:** `0fbcb17ddf93762fc256de6c38f511eadfd01eb4`  
**Current B1 candidate:** `B1.5p1`  
**Production code changed:** no

## Purpose

VQ provides an independent verification and reference-qualification layer for immutable SWAP 4.3.1 audit baseline `B0`, corrected reference `B1` and SWAP5 reference mode `B2`. Verification adapters may build legacy references and normalize output, but they do not repair production physics or become a production execution path.

## Minimum harness

| Layer | Responsibility |
| --- | --- |
| Reference identity | prove exact B0/B1/B2 source or artifact identity before use |
| Runner adapter | invoke pinned references outside the SWAP5 kernel |
| Case record | pin inputs, interval, capability and explicit qualification variants |
| Canonical result adapter | expose comparable state/accounting fields |
| Qualification gates | enforce reference, mass and transactional properties |
| Difference registry | classify every admitted B0/B1/B2 difference |

Unexplained differences fail. Confirmed B0 defects are not recreated in B2 for compatibility.

## Reference chain

```text
B0 exact immutable audit baseline
  -> B1 exact corrected reference
  -> B2 exact SWAP5 reference-mode commit
```

## VQ-1a: B0 identity

`tools/vq/reference_identity.py` fails closed unless the candidate archive matches the documented B0 size and SHA-256.

```text
size    8,959,314 bytes
sha256  2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
```

## VQ-1b: B0 execution and regression

The packaged Linux Intel executable is blocked in the current environment by missing `libimf.so`. VQ therefore has a provisional exact-source GNU Fortran runner. It is capability-limited and is not globally declared equivalent to the packaged Intel executable.

Case-specific evidence is stored in `tools/vq/cases/b0-official-case-rerun-2026-09-06.json`.

Current evidence:

- official full grass-growth case: repeatable PASS;
- Hupselbrook balance-only variant: published 2002 water balance reproduced at legacy precision;
- full official macropore case: not yet qualified within bounded VQ runtime, with no model failure inferred;
- 31-day macropore process-path variant: repeatable PASS;
- salinity process path: provisional PASS after explicit output-only workaround; official R preprocessing remains unavailable;
- GNU vector-CSV metadata path: unqualified portability limitation, not a confirmed B0 physical defect.

## Legacy balance boundary

`tools/vq/balance.py` normalizes `.BAL` and `.BLC` for regression. These files expose water values at `0.01 cm` precision and therefore cannot satisfy the hard invariant-13 mass gate.

## Hard mass-accounting contract

`docs/verification/mass-accounting-contract.md` and `tools/vq/contracts/mass-accounting-record.schema.json` define the unrounded VQ interchange record.

```text
delta_storage = end_storage - start_storage
net_external  = sum(signed interval-integrated external water terms)
residual      = delta_storage - net_external
```

The identity is unchanged for reference, normal, relaxed and fallback execution. Performance policy may not weaken mass conservation.

## Transactional qualification set

| ID | Property |
| --- | --- |
| `TX-ROLLBACK-01` | rejected trials leave committed state/accounting unchanged |
| `TX-COMMIT-01` | committed endpoint equals accepted trial endpoint within qualified representation tolerance |
| `TX-ACCOUNT-01` | rejected-trial fluxes never enter committed totals and accepted terms commit exactly once |
| `TX-RERUN-01` | identical committed state and inputs reproduce the physical result within qualification tolerance |
| `TX-BC-REPLAY-01` | changed boundaries can replay from the identical committed physical state |
| `TX-WARM-01` | numerical warm-start differences do not change the accepted physical result outside tolerance |

## Generic-time qualification set

`TIME-00`, `TIME-06`, `TIME-18`, `TIME-36` and `TIME-SPLIT` test midnight control, non-midnight starts, sub-day/cross-midnight windows, non-day windows and equivalent split/unsplit intervals. The target contract is generic `[t0,t1]`.

## VQ-1c: B1 provenance repair and independent repin

VQ previously rejected historical B1.2-B1.5 as exact oracles because their immutable metadata did not identify all stored patch bytes and canonical B0 preimages correctly. The reference line correctly retained those snapshots and published `B1.5p1` as a new provenance-repair snapshot with no intended numerical change.

VQ independently pins:

```text
B1.5p1 snapshot Git blob: 8980a975f4a8183bd216f03d868657568b5317d4
B0 member-manifest Git blob: be8862be45415e49fc366f98d9de76c8b14b1fae
B0 source archive SHA-256: 1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151
```

All five stored patch SHA-256 values match B1.5p1, and all five declared target preimages match the canonical B0 member manifest. The strengthened `tools/vq/b1_snapshot_identity.py` checks snapshot identity, B0 member-manifest identity, patch bytes and B0 preimages fail-closed.

```text
B1.5p1 exact identity gate: PASS
B0 -> B1.5p1 numerical qualification: NEXT GATE
```

Detailed evidence is `docs/verification/vq-1c-b1.5p1-evidence.md`.

This PASS does not yet claim numerical B0/B1 equivalence. The audit patch files are text artifacts whose line endings need a deterministic byte-aware application contract before corrected-target and executable comparisons are admitted.

## Expected differences

`docs/verification/expected-differences.json` defines comparison edges and required records. `OBSERVED` alone is never an expected passing difference. The legacy admission history remains authoritative in `docs/verification/legacy-differences.md`.

## Workstream handoff

```text
WORKSTREAM
VQ

BASELINE
current reference-line re-read: 0fbcb17ddf93762fc256de6c38f511eadfd01eb4

SCOPE
Independent B0/B1/B2 verification infrastructure, B0 regression hardening, unrounded mass-accounting contract and B1.5p1 identity qualification.

COMPONENTS/FILES TOUCHED
docs/verification, tools/vq, documentation navigation and VQ workstream status only.

INTERFACES CHANGED
No production interface. Verification interchange contracts only.

INVARIANTS AFFECTED
7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 23, 24, 25, 26, 28, 29, 30.

TEST/QUALIFICATION STATUS
B0 identity PASS. Case-specific B0 regression evidence recorded. Hard mass contract defined but not yet exposed by B2. B1.5p1 exact identity PASS. Numerical B0->B1.5p1 comparison not yet executed.

DEPENDENCIES / REQUIRED INTEGRATION
Deterministic byte-aware B1.5p1 patch application; integrated B2 reference entry point; callable TX transaction boundary; TX/HY/runtime mapping to unrounded accounting.

NEXT SAFE STEP
Implement the B1.5p1 application adapter from exact B0, verify each corrected target SHA-256, then execute the first B0 -> B1 numerical comparison using the expected-difference ledger. In parallel, TX/HY/runtime may map result objects to the VQ mass-accounting contract without changing its physical identity.
```
