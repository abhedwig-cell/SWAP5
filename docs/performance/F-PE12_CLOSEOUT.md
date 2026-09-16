# F-PE12 - Dual-target performance recovery closeout

Date: 2026-09-16

Status: **CLOSED_NO_PRODUCTION_MUTATION**

Protocol result:

```text
RECONCILE = COMPLETE
CLASSIFY  = COMPLETE
IMPLEMENT = NO_SAFE_APPLICABLE_IMPLEMENTATION_FROM_RECOVERED_AUTHORITIES
QUALIFY   = COMPLETE_AS_RECOVERY_AND_GOVERNANCE_QUALIFICATION
CLOSE     = COMPLETE
```

## Scope

F-PE12 recovered and classified SWAP performance work from late August and early September 2026 against two targets:

- Target A: SWAP 4.3.1 stable legacy maintenance/performance line;
- Target B: current SWAP5 post-Status-A line.

Energy Balance and RossFast remained excluded. No new physics, solver admission, transaction policy or mass policy was introduced.

## Final authorities

SWAP5 mapping authority:

- canonical branch: `integration/f-ci-canonical`
- canonical commit at closeout: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`
- canonical tree: `9b3ee78c9ff5dfde12345ef4e472e74d41ac0da3`
- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`

The canonical commit was rechecked immediately before closeout and had not moved from the commit against which F-PE12 mapped the current production surfaces.

Target-A authority remains the immutable SWAP 4.3.1 B0 plus explicitly admitted correction authorities. B1.10 does not contain SWAP-011.

## Final disposition matrix

| Recovered item | Historical classification | Target A | Target B current admitted production | F-PE12 action |
| --- | --- | --- | --- | --- |
| SWAP-011 dK/dh defect | A correctness | correctness authority, optimized E7 provenance blocked | implicit-conductivity hotspot outside admitted typed profile | no mutation |
| E3 per-node K/dKdh reuse | intermediate design prototype | superseded by later E5/E6/E7 lineage | design concept only | no mutation |
| E5/E6/E7 optimized SWAP-011 | B, technically qualified historical candidate | blocked until exact E7 bytes are recovered | B design candidate deferred outside current admitted typed profile | no mutation |
| SWAP-012 inverse correction | A correctness | correction, not speed patch | no independent current performance action established | no mutation |
| WFT300 | C for exact-semantics path | route/output divergence in recovered cases | not an exact-semantics candidate | excluded |
| hidden last-call K cache | C | unsafe hidden identity/lifetime semantics | unsafe hidden identity/lifetime semantics | excluded |
| duplicate-QROMBD OxygenStress optimization | D | isolated exact patch/qualification not recovered | no admitted current oxygen route | no mutation |
| fast no-stress OxygenStress exit | D | isolated exact patch/qualification not recovered | no admitted current oxygen route | no mutation |
| S9 shared OxygenStress data | B within S8-S9 lineage | D for direct stable-baseline admission because parent architecture is required | E, no current admitted OxygenStress cache/path | no mutation |
| A23ap cumulative oxygen prefix | B within A23ao-A23ap lineage | D because cumulative production-facade rebase remains open | E, no current admitted oxygen-reproduction path | no mutation |
| clay-start optimization | D | exact candidate/evidence not recovered | no mapped executable candidate | no mutation |
| O5 coarse-sand work beyond WFT300 | D | separate exact candidate not recovered | no mapped executable candidate | no mutation |
| Marius handoff beyond SWAP-011 | D | exact artifact provenance not recovered | no mapped executable candidate | no mutation |

The table distinguishes historical validity from current-target applicability. A candidate being historically qualified does not automatically make it admissible against either present target.

## Hydraulic conclusion

The most important recovered performance lineage is SWAP-011.

The E5/E6/E7 implementation is not a failed experiment. Recovered evidence shows broad correctness and route qualification plus meaningful timing improvement versus the numerical-reference derivative implementation. The blocker is exact artifact provenance, not lack of technical evidence.

F-PE12 therefore preserves issue #12 as the Target-A unlock. The exact final E7 package or patch must be recovered and byte-verified. Reconstructing it from prose, E2/E3 notes or expected file names is prohibited.

For current SWAP5, the qualified typed production route rejects `swkimpl /= 0`. The legacy compatibility HeadCalc still contains SWKIMPL=1 K/dKdh work, so the historical idea is not classified as globally obsolete. It is a deferred B design candidate outside the current Status-A typed production profile. F-PE12 does not broaden solver admission to manufacture a performance target.

## Final E7 provenance search

At final closeout, F-PE12 performed three bounded File Library search passes using the expected exact artifact names and distinctive aliases, including:

```text
SWAP_4.3.1_E7_SW011_upstream_package.zip
SWAP_4.3.1_SW011_overdracht_Marius.docx
SWAP_4.3.1_SW011_overdracht_Marius_bundle.zip
SWAP-011_fix.patch
E7 SW011 upstream package
SW011 overdracht Marius
READY_PATCH_UPSTREAM SWAP-011
```

No exact E7 patch/package artifact was returned. The searches did return older/reference material such as D2 qualification and the E3 semantic prototype, which cannot substitute for the final E7 payload.

This search result does not prove that the original artifact no longer exists outside the accessible File Library. It establishes only that F-PE12 did not recover it from the available sources. The authoritative provenance status therefore remains:

```text
PATCH_PAYLOAD_PENDING
```

and the anti-reconstruction rule remains binding.

## OxygenStress-adjacent conclusion

Later S9 and A23ap evidence was recovered and is useful, but it does not backfill the missing evidence for the earlier duplicate-QROMBD and fast no-stress changes.

S9 is an architecture/memory optimization in an explicit-context lineage. A23ap is a locally bitwise-qualified O(Nroot^2) to O(Nroot) prefix-work transformation in a specific oxygen-reproduction route. Both are bounded by parent-lineage or rebase dependencies for Target A and neither route exists in the current admitted SWAP5 root-water-uptake production owner.

No oxygen production code is created by F-PE12.

## Qualification of the F-PE12 result

F-PE12 qualification is governance/recovery qualification because no executable candidate was produced.

Verified at closeout:

1. current canonical remained `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`;
2. the work branch remained based directly on that canonical and was not behind it;
3. the branch delta contained documentation/evidence records only before the closeout record itself;
4. no production source file was changed;
5. no SWAP 4.3.1 source file was changed;
6. no EB or RossFast source was changed;
7. no new performance speedup claim was made without executable timing evidence;
8. historical measurements are reported only within their recovered qualification scope;
9. no D-class candidate was reconstructed to force an IMPLEMENT result.

A new performance benchmark is neither required nor meaningful in this workunit because there is no new executable postimage to compare.

## Repository records produced

- `docs/performance/F-PE12_DUAL_TARGET_RECOVERY_CHECKPOINT.md`
- `docs/performance/F-PE12_TARGET_MAPPING_CHECKPOINT.md`
- `docs/performance/F-PE12_HYDRAULIC_REUSE_TARGET_MAPPING.md`
- `docs/performance/F-PE12_OXYGEN_ADJACENT_RECOVERY.md`
- `docs/performance/F-PE12_CLOSEOUT.md`

The later target-mapping and closeout records supersede preliminary classifications where deeper recovery produced a narrower conclusion. In particular, the current SWAP5 hydraulic candidate is deferred B outside the admitted typed profile, not globally class E.

## Reopen gates

F-PE12 itself is closed. New work should reopen only a concrete decision surface:

1. **SWAP-011 Target A provenance recovery**: exact final E7 payload recovered and byte-verified;
2. **SWAP5 implicit-conductivity admission**: SWKIMPL=1 semantics independently admitted on the explicit typed solver path, followed by a fresh performance capability;
3. **earlier OxygenStress artifact recovery**: exact isolated patch plus matching qualification package recovered;
4. **S6-S9 architecture nomination**: complete parent chain intentionally proposed as a separate legacy architecture workunit;
5. **A23 lineage completion**: cumulative A23y-through-A23ap production-facade rebase recovered and independently qualified.

Clay-start, separate O5 runtime work and other D items require exact new evidence before they may become implementation candidates.

## Final verdict

```text
F-PE12 = CLOSED_NO_PRODUCTION_MUTATION
SCIENTIFIC_SCOPE_CHANGE = NONE
PRODUCTION_SOURCE_CHANGE = NONE
LEGACY_SOURCE_CHANGE = NONE
NEW_SPEEDUP_CLAIM = NONE
OPEN_EXTERNAL_GATE = SWAP-011 exact E7 provenance recovery
```
