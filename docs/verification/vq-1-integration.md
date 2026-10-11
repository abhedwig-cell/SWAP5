# VQ-1 integration record

**Workstream:** VQ  
**Latest main re-read:** `95f7f0499e75558eb611263821df8a469dde7f26`  
**Current B1 reference:** `B1.5p1`  
**Production code changed:** no

## Purpose

VQ provides an independent verification and reference-qualification layer for immutable SWAP 4.3.1 audit baseline `B0`, corrected reference `B1` and SWAP5 reference mode `B2`. Verification adapters may build legacy references and normalize output, but they do not repair production physics and do not become a production execution path.

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
  -> B1.5p1 qualified corrected reference
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

## VQ-1c1: B1 provenance repair and independent repin

Historical B1.2-B1.5 remain immutable failed-provenance records. The reference line published `B1.5p1` as a provenance-repair snapshot without changing the intended five corrections.

The strengthened `tools/vq/b1_snapshot_identity.py` pins the snapshot blob, canonical B0 member-manifest blob, every stored patch SHA-256 and every declared B0 target preimage.

```text
B1.5p1 exact identity gate: PASS
```

Detailed evidence is `docs/verification/vq-1c-b1.5p1-evidence.md`.

## VQ-1c2: deterministic reconstruction and broad control edges

`tools/vq/b1_reconstruct.py` reconstructs B1.5p1 directly from the exact B0 distribution without editing B0 in place.

All five corrected targets reproduce the snapshot-declared SHA-256 exactly. The full reconstructed source tree has explicit VQ identity:

```text
members            63
source bytes        1,860,109
manifest SHA-256    c50da618aef92f99103531390e243144403060b0066e8dc3d827b79085bd9c30
```

Two broad B0 -> B1 control edges were executed on the same provisional GNU path:

1. official `2.grassgrowth`, 1980-1984: normal completion for both; normalized `result_output.csv` byte-identical with SHA-256 `0a7025b72abbb524760107ca1f0309d8e241a7aa2830bb983afe9245730dec7e`;
2. Hupselbrook with the same symmetric output-only `SWCSV=0` GNU compatibility variant: normal completion for both; normalized `.BAL` and `.BLC` byte-identical.

These edges contain no unexplained difference. Detailed evidence is `docs/verification/vq-1c2-b1.5p1-reconstruction.md`.

## VQ-1c3: admitted correction-triggering gates

`tools/vq/b1_targeted_qualification.py` binds every targeted reproducer to the exact B0/B1.5p1 source fragment before running the correction-specific gate.

| Correction | Gate | B0 | B1.5p1 | Result |
| --- | --- | --- | --- | --- |
| `SWAP-001` | strict shape + real macropore smoke | 5000/112 non-conformable assignment | active copy + zero tail; normal smoke completion | PASS |
| `SWAP-005` | signaling-NaN guard-order reproducer | SIGFPE on inactive `i+1` access | inactive record not evaluated | PASS |
| `SWAP-006` | signaling-NaN sentinel reproducer | SIGFPE after scan enters unused record | scan bounded to `1:ifnd` | PASS |
| `SWAP-007` | unchanged full grass case with strict FPE traps | SIGFPE in oxygen-stress call chain | legacy normal completion | PASS |
| `SWAP-008` | actual `bandec`/`banbks` harness + language contract | numerically works here but consumes `INTENT(OUT)` inputs | same solution with defined `INTENT(INOUT)` contract | PASS |

For `SWAP-001`, an additional actual SWAP macropore case shortened to `1998-01-01..1998-01-02`, with symmetric `SWCSV=0`, gives the exact strict 5000/112 B0 mismatch while B1.5p1 completes normally.

`SWAP-008` deliberately does **not** require a numerical difference: the admitted correction changes dummy-argument definedness, not the band-solver arithmetic.

The machine-readable result is `tools/vq/cases/b1-5p1-targeted-qualification-2026-09-06.json`; detailed evidence is `docs/verification/vq-1c3-b1.5p1-targeted-qualification.md`.

## B1.5p1 oracle decision

The combined VQ-1c result is now:

```text
B1.5p1 provenance/identity                    PASS
B1.5p1 deterministic reconstruction           PASS
all corrected-target SHA-256 gates            PASS
broad control edges                            PASS
all five admitted correction-triggering gates PASS
```

VQ therefore qualifies B1.5p1 as the **numerical/behavioural corrected-reference oracle** for B2 regression.

This status has explicit boundaries:

- it is not a claim of exhaustive coverage of every SWAP 4.3.1 feature/option combination;
- it does not make the provisional GNU runner globally equivalent to the packaged Intel executable;
- legacy `.BAL/.BLC` remains too rounded for the SWAP5 machine-precision hard mass gate;
- hard mass conservation is evaluated independently through the unrounded B2 accounting contract.

## Expected differences

`docs/verification/expected-differences.json` now contains explicit B0 -> B1.5p1 entries for all five admitted corrections. The authoritative admission history remains `docs/verification/legacy-differences.md`.

A difference is acceptable only when its observed behaviour is inside the registered correction scope. `OBSERVED` alone is never an expected passing difference.

## Workstream handoff

```text
WORKSTREAM
VQ

BASELINE
latest main re-read: 95f7f0499e75558eb611263821df8a469dde7f26

SCOPE
Independent B0/B1/B2 verification infrastructure; B0 regression hardening; B1.5p1 identity, deterministic reconstruction, control edges and admitted correction-triggering qualification; unrounded mass-accounting contract.

COMPONENTS/FILES TOUCHED
docs/verification and tools/vq. No production physics, solver, runtime or coupling code.

INTERFACES CHANGED
No production interface. Verification interchange contracts only.

INVARIANTS AFFECTED
7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 23, 24, 25, 26, 28, 29, 30.

TEST/QUALIFICATION STATUS
B0 identity PASS. Case-specific B0 regression evidence recorded. B1.5p1 exact identity PASS. Deterministic B1.5p1 reconstruction PASS. Broad control edges PASS. All five admitted correction-triggering gates PASS. B1.5p1 qualified by VQ as numerical/behavioural corrected-reference oracle. Legacy hard machine-precision mass evidence remains unavailable and is not inferred from BAL/BLC.

DEPENDENCIES / REQUIRED INTEGRATION
Reference-line metadata should adopt the completed VQ B1.5p1 qualification after this slice is integrated. Next VQ execution depends on an integrated B2/SWAP5 reference-mode entry point, callable TX transaction boundary and TX/HY/runtime mapping to unrounded accounting.

NEXT SAFE STEP
Start VQ-1d: define the B1.5p1 -> B2 reference adapter and first executable SWAP5 reference comparison. Keep transaction, generic-time, warm-start and hard unrounded mass gates fail-closed until the required B2 interfaces are available.
```
