# PPA-WU05-C3R formula reconciliation matrix

Date: 2026-10-01

## Authority correction

The earlier matrix understated repository authority. SWAP5 already contains a qualified deterministic
reconstruction contract for corrected reference snapshot **B1.5p1**.

Canonical identities used by C3R/C3Q are now:

- B0 distribution SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`
- nested B0 SWAP.ZIP SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`
- B0 oxygenstress.f90 SHA-256: `2db206bf28e883a22a1419d4729e03c1bb6b1ec777f544511ffe95bdbf9e5735`
- corrected B1.5p1 oxygenstress.f90 SHA-256: `8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87`
- reconstructed B1.5p1 source manifest SHA-256: `c50da618aef92f99103531390e243144403060b0066e8dc3d827b79085bd9c30`
- source members: 63
- source bytes: 1,860,109

The repository's `tools/vq/b1_reconstruct.py` proves that B1.5p1 differs from B0 oxygenstress only by
the admitted SWAP-007 replacement and verifies the corrected target hash.

## Consequence for formula authority

For every oxygenstress formula outside the SWAP-007 replacement hunk, **B1.5p1 formula bytes are
identical to canonical B0 formula bytes**.

Therefore the previous broad label `FAMILY-CORROBORATED` is no longer the right authority model.
The complete canonical B0 source archive plus the one exact SWAP-007 transformation define the
corrected oxygenstress source exactly.

The public SWAP-model/SWAP source used during early reconstruction is demoted to corroborating
historical evidence only. It is no longer needed as the authority for C3Q.

## Remaining reconciliation task

The remaining task is mechanical rather than provenance-uncertain:

1. reconstruct exact B1.5p1 oxygenstress bytes through existing VQ tooling;
2. compare each pure-kernel formula block to those exact bytes;
3. classify intentional numerical-policy replacements separately;
4. run physical response parity.

No new source upload and no source-family inference are required.
