# F-CI05 Qualification

## Result

`PASS_PHYSICAL_PREIMAGE_ADAPTER_BLOCKED_PENDING_CONTROLLED_SOURCE_PORT`

F-CI05 qualifies the exact B1.10 physical adapter preimage and explicitly does not admit a physical adapter implementation.

## Exact local source evidence

The available SWAP 4.3.1 package contains nested source archive:

`SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP`

Observed nested SHA-256:

`1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`

This equals the B1.10 pinned source archive identity. The archive contains 63 Fortran source files. All six physical seam hashes in `F-CI05_B1_10_PHYSICAL_SEAM.json` passed byte-exact verification.

The outer packaging SHA is recorded only as evidence and is not promoted to canonical source identity.

## GitHub Actions

Workflow run: `34082009045`

- `fci03-transaction-substrate`: PASS
- `fci04-canonical-runtime`: PASS
- `fci05-b1-10-physical-preimage`: PASS

The F-CI05 CI job runs the static form of `tools/fci/fci05_b1_10_physical_preimage_gate.py`, which verifies the B1.10 source/archive pins and fails if any pinned legacy physical seam becomes a patch target in the B1 corrected-reference chain.

Archive mode of the same gate can additionally verify an actual source distribution when the archive is available.

## Admission decision

The exact B1.10 source is now sufficiently pinned to begin a controlled source port. A canonical physical adapter is not yet admissible because the exact legacy source still has hidden/global continuation, saved HeadCalc scratch/history, trial-time output side effects, file-bound forcing paths and incomplete accepted-flux exposure.

The next source-changing unit must therefore operate directly from this exact B1.10 preimage, not from A23-generated B1.6 source.
