# B1.5p1 provenance repair

**Workstream:** VQ / corrected-reference maintenance  
**Trigger:** VQ-1c, GitHub issue #19  
**Numerical change relative to B1.5:** none intended  
**Historical snapshots rewritten:** no

## Why B1.5p1 exists

VQ-1c applied a fail-closed identity check to the corrected-reference snapshots. That check found that several immutable B1 snapshot records did not match the exact bytes of their stored `fix.patch` artifacts. SWAP-007 also carried an incorrect B0 `oxygenstress.f90` SHA in its dossier/helper even though the correction transformation itself still maps the canonical B0 source to the documented corrected source hash.

The affected historical snapshots remain untouched. `B1.5p1` is a new provenance-correct oracle with the same intended patch set as `B1.5`.

## Exact repair

| Patch | Historical declared patch SHA | Exact stored `fix.patch` SHA | Canonical B0 target | Corrected target |
| --- | --- | --- | --- | --- |
| SWAP-001 | `6dd75db2603f71def58db0a0f5c77bfcd2fba2688add837436fd0d09713e5770` | same | `1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b` | `f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f` |
| SWAP-005 | `9c3839ac0674d7c5c3eb2de797684c7baf83fdc3a18d64de68c9746de9878e66` | `243720f59a0d9154fa4ba4acf1fce68096999bd0f8eafa452bfb40cef5572553` | `c2df137291357553541d4d7026b8859242c32565affe173c66a685d565190ccf` | `aef69feef8561c1b9e52cff5a217a6155f949a039769e5d793df3038f86e4210` |
| SWAP-006 | `558eb084befac713aec0b923d45182a1efcbed44d71ed00e6faf024b6540718a` | `4530d489701f0356dd06d8cc3752b3cb6322cf864cea0c330ce1448f7dfa5b2f` | `5a095c16ec82fa544f7dd20ba568ba3a2b72906bff7dd3505af16e6722d86822` | `99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f` |
| SWAP-007 | `e65b703b73b530915414265c3b647a403f995adc568390ed5da4ecb55be75b96` | `3ac9580bc162f8a4c90b83d59452e7b40bd1e0c82ba92e7a2c1ac58f154af5f0` | `2db206bf28e883a22a1419d4729e03c1bb6b1ec777f544511ffe95bdbf9e5735` | `8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87` |
| SWAP-008 | `8f97ff20e63a7765bfe8e225e2682029bafadc0eeb80ad0e4ce1564fb8c94f4c` | same | `6aa6bb863ec296f47afda35a9871b16105087d0eed485e37f13f5f5cdad96651` | `87b9b1cd6de65e6ee1d7c1775cddff6093c12d4d0744ffcde70844f5f28c6e7a` |

For SWAP-007 the historical B0 hash was `2db206bf28e883a22a1419d4729e03c1bb6b9c6bcf560d2221248f3b12f75`; that value is not the canonical B0 file identity. The canonical verifier added with B1.5p1 uses the B0 manifest value shown above and reproduces the already documented corrected target hash.

## Interpretation

This repair changes reference provenance metadata, not the intended corrected source semantics. It does not add or remove a legacy bugfix, does not alter SWAP5 production code and does not alter any physical model equation.

The invalid historical snapshot identities remain useful as audit history but must not be used as exact executable oracles. The first corrected-reference snapshot intended to pass the exact artifact/preimage identity gate is `B1.5p1`.

## Verification handoff

After this change reaches `main`, VQ must rebase or otherwise inspect the new snapshot and rerun its fail-closed B1 identity gate. Numerical B0 -> B1 comparison remains blocked until that independent gate reports PASS.
