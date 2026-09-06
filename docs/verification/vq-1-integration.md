# VQ-1 integration record

**Workstream:** VQ  
**Integration baseline:** `ce280e110c637a087d2a1aabd70fca5f1d494e48`  
**Integration branch:** `vq/vq-1-integration`  
**Production code changed:** no

## Purpose

VQ provides an independent verification and reference-qualification layer for the immutable SWAP 4.3.1 audit baseline (`B0`), the corrected SWAP 4.3.1 reference lineage (`B1`) and SWAP5 reference mode (`B2`).

The VQ layer may build reference executables, translate legacy output and evaluate qualification gates, but it does not repair production physics and does not become a hidden production execution path.

## Minimum harness

The integrated VQ harness separates six responsibilities:

| Layer | Responsibility |
| --- | --- |
| Reference identity | prove exact B0/B1/B2 source or artifact identity before outputs are admitted |
| Runner adapter | invoke a pinned reference implementation outside the SWAP5 kernel |
| Case record | pin inputs, interval, runner capability and any explicit qualification-only variant |
| Canonical result adapter | expose comparable state/accounting data instead of relying on arbitrary text diffs |
| Qualification gates | evaluate reference equivalence, mass accounting and transaction properties |
| Difference registry | require every accepted B0/B1/B2 difference to be explicitly classified |

An unexplained difference fails qualification. A confirmed B0 bug is not recreated in B2 merely for compatibility.

## Reference chain

```text
B0 exact immutable audit baseline
  -> B1 exact provenance-qualified corrected snapshot
  -> B2 exact SWAP5 reference-mode commit
```

B0 is controlled by the documented distribution and source hashes. A B1 snapshot is usable as an oracle only when every declared patch artifact and B0 preimage passes the VQ identity gate. B2 comparisons must pin the exact qualified B1 snapshot and exact SWAP5 commit.

## VQ-1a: B0 identity

`tools/vq/reference_identity.py` fails closed unless a supplied distribution matches the exact B0 size and SHA-256 in `docs/verification/reference-baseline.json`.

The archive used for VQ evidence matches:

```text
size    8,959,314 bytes
sha256  2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
```

## VQ-1b: B0 execution and regression

The packaged Linux Intel executable cannot run in the current VQ environment because `libimf.so` is unavailable. VQ therefore has a provisional exact-source GNU Fortran runner. This runner is capability-limited and is **not** declared equivalent to the packaged Intel executable.

Current case-specific evidence is stored in:

```text
tools/vq/cases/b0-official-case-rerun-2026-09-06.json
```

Key results:

- full official grass-growth case: repeatable PASS on the provisional GNU path;
- Hupselbrook balance-only variant: package-published 2002 water balance reproduced at legacy report precision;
- full official macropore case: not yet qualified within the bounded VQ execution window; no model failure inferred;
- 31-day macropore execution-path variant: repeatable PASS;
- salinity scenarios: provisional process-path PASS after explicit output-only workaround; official R preprocessing remains unavailable in the current environment;
- GNU vector CSV metadata path: unqualified portability limitation, not a confirmed B0 model defect.

## Legacy balance boundary

`tools/vq/balance.py` normalizes `.BAL` and `.BLC` output for regression use. These reports expose values at only `0.01 cm` precision.

They therefore provide regression/accounting evidence only. They cannot satisfy the hard SWAP5 mass-conservation gate.

## Hard mass-accounting contract

`docs/verification/mass-accounting-contract.md` and `tools/vq/contracts/mass-accounting-record.schema.json` define the VQ-side unrounded accounting contract.

VQ independently recomputes:

```text
delta_storage = end_storage - start_storage
net_external  = sum(signed interval-integrated external water terms)
residual      = delta_storage - net_external
```

The same identity applies to reference, normal, relaxed and fallback execution. Performance policy may not weaken mass conservation.

## Transactional qualification set

| ID | Property | Blocking condition |
| --- | --- | --- |
| `TX-ROLLBACK-01` | rejected trial rollback | committed state/accounting changes after rejection |
| `TX-COMMIT-01` | accepted endpoint commit | committed endpoint differs from accepted trial endpoint outside qualified tolerance |
| `TX-ACCOUNT-01` | exactly-once accounting | rejected-trial fluxes enter committed totals or accepted fluxes are double-counted |
| `TX-RERUN-01` | same-state rerun | identical committed physical start and inputs yield a non-qualified physical difference |
| `TX-BC-REPLAY-01` | changed-boundary replay | replay cannot begin from the identical committed physical state |
| `TX-WARM-01` | warm-start independence | changing/removing numerical warm-start data changes the accepted physical result outside qualified tolerance |

These gates remain specified until an integrated B2/TX interface exposes the required state and accounting data.

## Generic-time qualification set

| ID | Interval |
| --- | --- |
| `TIME-00` | midnight-to-midnight control |
| `TIME-06` | non-midnight six-hour interval |
| `TIME-18` | eighteen-hour interval crossing midnight |
| `TIME-36` | non-day interval crossing calendar boundaries |
| `TIME-SPLIT` | equivalent split versus unsplit interval where no physical event changes the contract |

The kernel qualification target is generic `[t0,t1]`; day boundaries are not assumed fundamental.

## VQ-1c: current B1.4 provenance gate

At the integration baseline, `reference/swap-4.3.1/snapshots/B1.4.yml` declares four admitted corrections. VQ hashes the stored patch bytes before any numerical B0 -> B1 comparison.

| Patch | Snapshot-declared SHA-256 | Observed stored patch | Gate |
| --- | --- | --- | --- |
| SWAP-001 | `6dd75db2...5770` | same | PASS |
| SWAP-005 | `9c3839ac...8e66` | `243720f5...553` | FAIL |
| SWAP-006 | `558eb084...718a` | `4530d489...5b2f` | FAIL |
| SWAP-007 | `e65b703b...5b96` | `3ac9580b...f5f0` | FAIL |

SWAP-007 additionally declares B0 `SWAP/oxygenstress.f90` SHA-256 `2db206bf...12f75`, while independent extraction from the exact B0 source archive gives `2db206bf...e5735`.

Therefore:

```text
B1.4 exact oracle pin: FAIL
B0 -> B1.4 numerical qualification: BLOCKED
```

This is tracked in GitHub issue #19. Published B1 snapshots are immutable by policy, so VQ does not silently edit B1.4 to make the hashes agree.

## Expected differences

`docs/verification/expected-differences.json` defines the machine-readable comparison edges and required fields. The authoritative legacy admission history remains `docs/verification/legacy-differences.md`.

`OBSERVED` alone is never an expected passing difference.

## Workstream handoff

```text
WORKSTREAM
VQ

BASELINE
ce280e110c637a087d2a1aabd70fca5f1d494e48

SCOPE
Independent B0/B1/B2 verification infrastructure, B0 regression hardening, unrounded mass-accounting contract and fail-closed B1 provenance gate.

COMPONENTS/FILES TOUCHED
docs/verification, tools/vq, documentation navigation and VQ workstream status only.

INTERFACES CHANGED
No production interface. Verification interchange contracts only.

INVARIANTS AFFECTED
7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 23, 24, 25, 26, 28, 29, 30.

TEST/QUALIFICATION STATUS
B0 identity PASS. Case-specific B0 regression evidence recorded. Hard mass contract defined but not yet exposed by B2. B1.4 provenance gate FAIL, so numerical B0->B1 qualification is blocked.

DEPENDENCIES / REQUIRED INTEGRATION
Provenance-correct immutable B1 snapshot; integrated B2 reference entry point; callable TX transaction boundary; TX/HY/runtime mapping to unrounded accounting.

NEXT SAFE STEP
Reference-line work resolves issue #19 by creating a provenance-correct immutable B1 snapshot. VQ then reruns the exact identity gate before any numerical B0->B1 comparison. In parallel, TX/HY/runtime may map proposed result objects to the VQ mass-accounting contract without changing the contract's physical identity.
```
