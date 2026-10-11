# VQ-1c2 B1.5p1 reconstruction and first numerical edges

**Workstream:** VQ  
**Slice:** VQ-1c2  
**Latest main re-read before execution:** `d5f163534f8feb7ff7f6d1f1bcb4ce4b0d168fc5`  
**Reference snapshot:** `B1.5p1`  
**Production code changed:** no

## Purpose

VQ-1c1 established that the provenance-repaired `B1.5p1` snapshot identifies the exact stored patch artifacts and canonical B0 preimages correctly.

VQ-1c2 moves one gate further. It asks two separate questions:

1. can exact B0 be transformed deterministically into the corrected source bytes declared by `B1.5p1`;
2. do initial control-case executions show any unexplained B0 -> B1 difference on the provisional exact-source GNU path.

A PASS here still does not qualify every admitted correction numerically. Correction-triggering cases remain a separate next gate.

## Exact B0 start point

The reconstruction starts only after both B0 identities pass:

```text
B0 distribution SHA-256
2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360

nested B0 SWAP.ZIP SHA-256
1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151
```

No B0 file is edited in place. VQ expands a fresh exact copy and writes the reconstructed tree separately.

## Corrected-target gate

`tools/vq/b1_reconstruct.py` applies independent byte-exact transformations and requires a unique target sequence for every replacement. Each source file must first match its canonical B0 SHA-256 and the resulting bytes must match the `corrected_target_sha256` declared by `B1.5p1`.

| Correction | Target | Corrected target SHA-256 | Gate |
| --- | --- | --- | --- |
| `SWAP-001` | `SWAP/macropore.f90` | `f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f` | PASS |
| `SWAP-005` | `SWAP/MOD_cropdevelopment.f90` | `aef69feef8561c1b9e52cff5a217a6155f949a039769e5d793df3038f86e4210` | PASS |
| `SWAP-006` | `SWAP/MOD_meteo.f90` | `99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f` | PASS |
| `SWAP-007` | `SWAP/oxygenstress.f90` | `8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87` | PASS |
| `SWAP-008` | `SWAP/tridag.f90` | `87b9b1cd6de65e6ee1d7c1775cddff6093c12d4d0744ffcde70844f5f28c6e7a` | PASS |

All five targets reproduce the snapshot-declared corrected hashes exactly.

## Reconstructed source-tree identity

VQ writes a deterministic manifest over every reconstructed source member using:

```text
SHA256  SIZE_BYTES  PATH
```

The resulting B1.5p1 tree identity is:

```text
member count       63
source bytes       1,860,109
manifest SHA-256   c50da618aef92f99103531390e243144403060b0066e8dc3d827b79085bd9c30
```

This gives later B1 builds a direct source-tree identity rather than relying only on the names of five patches.

## GNU reference builds

B0 and reconstructed B1.5p1 were compiled through the same provisional standalone GNU path:

```text
GNU Fortran (Debian 14.2.0-19) 14.2.0
```

Observed executable hashes for this environment were:

```text
B0  d8c7f583a9202a3b5fe38d3a3bf855dcac9c179be18562dcca502340656867f2
B1  f8de764c73c6ee2a844fcc865cf2b2f6eeeae6a871d749b2c2027d1f2ebe97a1
```

These executable hashes are build-environment evidence only. They are not canonical cross-platform B0/B1 identities and do not establish Intel/GNU equivalence.

## Numerical edge 1: official grass growth

The unchanged official `2.grassgrowth` case was run for both source trees over `1980-01-01` through `1984-12-31`.

Both executions:

- returned the legacy normal-completion code `100`;
- created `swap.ok`;
- left `swap.err` empty.

After removing only the generated timestamp line:

```text
B0 result_output.csv SHA-256
0a7025b72abbb524760107ca1f0309d8e241a7aa2830bb983afe9245730dec7e

B1 result_output.csv SHA-256
0a7025b72abbb524760107ca1f0309d8e241a7aa2830bb983afe9245730dec7e
```

Result: **byte-identical control output**. No expected-difference ledger entry is required for this edge.

## Numerical edge 2: Hupselbrook balance control

Hupselbrook was run on both source trees with the same explicit GNU compatibility variant:

```text
SWCSV = 1 -> SWCSV = 0
```

No physical input or process option was changed. The output-only variant is already classified by VQ-1b and is applied symmetrically to B0 and B1.

Both runs completed normally. Normalized balance hashes are:

| Report | B0 | B1.5p1 | Result |
| --- | --- | --- | --- |
| `result.bal` | `a9cc9b18...d0e7` | `a9cc9b18...d0e7` | identical |
| `result.blc` | `1bd2631d...b77c` | `1bd2631d...b77c` | identical |

This confirms no unexplained B0 -> B1 change on this control path. As before, legacy BAL/BLC resolution is `0.01 cm`, so this comparison is not the invariant-13 hard mass gate.

## Unit qualification

`tools/vq/test_b1_reconstruct.py` covers:

- exact byte replacement;
- fail-closed wrong B0 preimage;
- fail-closed non-unique replacement target;
- deterministic source-manifest construction.

The four tests passed in the VQ execution environment.

## Qualification decision

```text
B1.5p1 identity/provenance gate                 PASS
B1.5p1 deterministic source reconstruction      PASS
all five corrected-target SHA-256 gates         PASS
B0 -> B1 grass-growth control edge              PASS, no difference
B0 -> B1 Hupselbrook balance control edge       PASS, no difference
B1.5p1 global numerical oracle                  NOT YET FULLY QUALIFIED
```

The remaining distinction is deliberate. Control cases prove that the corrected reference does not introduce an unexplained broad regression on these paths. They do not prove that each admitted correction behaves correctly when its defect is actually exercised.

## Next safe step

Continue VQ-1c with targeted B0 -> B1 qualification cases for the admitted corrections. Each case should:

1. exercise the defect or corrected code path intentionally;
2. pin exact input/source identity;
3. establish the B0 observation or failure mode;
4. establish the B1.5p1 corrected behavior;
5. classify the expected difference through the authoritative difference ledger;
6. retain mass/accounting gates wherever physically applicable.

Only after the relevant admitted differences are covered should VQ label B1.5p1 a broadly qualified numerical B1 oracle for B2 comparison.
