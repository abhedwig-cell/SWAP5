# F-CI02 Canonical reference root

## Decision

F-CI uses `integration/f-ci-canonical` as the only active canonical integration line.
The branch was created from exact repository root:

`main@fafeebdece209abcc320b24a3c8c2757800b2e0e`

No A23, S13b, M3 or other historical production source was merged into this root.

## Current legacy oracle

The only admitted legacy oracle for forward integration is B1.10:

- admission commit: `5a25526e77a4e1ba3b8f2755cb1e59ca0700ee96`
- corrected-reference family: `SWAP-4.3.1-corrected`
- source members: 63
- source bytes: 1,863,575
- source manifest SHA-256: `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`
- reconstruction: `tools/vq/b1_10_reconstruct.py`
- qualification/admission: `tools/vq/b1_10_admission_gate.py`

The machine-readable pin is `integration/f-ci/canonical-source-manifest.json`.

## Transactional lineage

`integration/a23bk-transactional-rebase` is pinned at
`763f276a96ee1722a465bacd3a710172a5f38107` (A23BU).

Its merge base with the B1.10 lineage is
`2d05eeab9d766d51bc7c436ea1e45f9b49940e92`, the B1.6 admission.
Therefore A23BU is a qualified forward-port candidate, not a canonical source root.
A direct merge is prohibited by the F-CI manifest.

## Reuse classification

- B1.10 corrected source and reconstruction identity: `CANONICAL_SOURCE`
- A23BU materialized transaction/runtime postimages: `QUALIFIED_FORWARD_PORT_CANDIDATE`
- VQ gates/contracts: `QUALIFIED_TEST_OR_CONTRACT`
- S13b/HeadCalc production source without an exact pinned cumulative postimage: `BLOCKED_BY_MISSING_PROVENANCE`
- M3 contracts/tests/evidence without exact production postimage: `QUALIFIED_TEST_OR_CONTRACT`
- historical loose patches and chat-only outcomes: not production source

## F-CI02 focused gate

Run:

```bash
python tools/fci/fci02_reference_root_gate.py
```

The gate fails closed unless the branch descends from the exact pinned `main` root,
the B1.10 admission identity and source-manifest values match the F-CI manifest,
the A23 divergence is explicitly pinned to B1.6, direct A23 merge remains disabled,
and the existing B1.10 VQ admission gate passes.

For a metadata-only diagnostic when the B0 archive/runtime required by the existing
VQ admission gate is intentionally unavailable, run:

```bash
python tools/fci/fci02_reference_root_gate.py --skip-vq-gate
```

A metadata-only PASS is not a replacement for the full F-CI02 gate.

## Holds carried into F-CI03

1. No production physics or solver formula changes during the transaction forward-port.
2. No selective step-doubling or performance policy activation.
3. B1.10 corrected-reference changes must survive intact.
4. Rejected trials must never mutate committed physical state.
5. Numerical scratch remains worker-owned.
6. Reporting/output state is not physical continuation state.
7. The kernel boundary must stay free of file-I/O dependencies.
8. Generic `[t0,t1]` must not be inferred from legacy whole-day projection.
9. Mass conservation remains a hard acceptance gate.

## F-CI02 exit condition

F-CI02 is complete when the canonical branch, manifest, gate and this decision record
are pinned in Git and the full focused gate is reproducibly executable. Actual A23
forward-porting starts only in F-CI03.
