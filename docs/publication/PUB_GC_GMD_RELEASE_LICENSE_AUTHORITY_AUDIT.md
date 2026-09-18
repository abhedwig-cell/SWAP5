# PUB-GC GMD release and licence authority audit

## Status

**A1 RELEASE IDENTIFIER UNRESOLVED / A2 LEGACY LICENCE VERIFIED, SWAP5 ARCHIVE DECLARATION STILL GOVERNANCE-BOUND**

Date: 2026-09-18.

Canonical basis at audit start:

`integration/f-ci-canonical@ff56b8c1565821cf1d23f980e754905d8920371e`

This audit narrows the GMD archival blockers without inventing a publication version or a repository licence.

## 1. A1 — release/version authority

### Repository evidence

No GitHub release/tag has been published for the current canonical, and no `CITATION.cff`, `.zenodo.json` or root publication licence metadata exists on the audited canonical surface.

However, repository history contains an explicit immutable release authority that must govern any successor release:

```text
release id: SWAP5-RB1-v1
authority branch: release/f-rb02-restricted-production-baseline-v1-final-authority
final authority commit: b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0
workunit: F-RB02
```

`F-RB02_CLOSEOUT.json` states:

> SWAP5-RB1-v1 is immutable. Later integration/f-ci-canonical development does not alter RB1. A future release must enumerate its delta from RB1 and qualify its own candidate.

It also permits an optional future external tag only on the exact final RB1 metadata-authority commit. Therefore **SWAP5-RB1-v1 cannot be moved, reused or reinterpreted as the PUB-GC publication release**.

The current paper uses substantial post-RB1 development, including the completed groundwater-coupling/application and publication evidence. A new exact-head successor release authority is therefore required.

The Status-A release-readiness baseline additionally provides this positive governance fact:

```text
READY_FOR_STATUS_A_RELEASE_CANDIDATE_BOUNDARY
```

and explicitly permits creation of a Status-A / release-candidate tag or release authority.

That permission is **not** a naming rule. It does not choose:

- a semantic version;
- a date version;
- a Status-A tag spelling;
- a publication-only identifier;
- whether the current post-Status-A canonical should inherit the historical Status-A label.

### A1 disposition

**BLOCKED_SUCCESSOR_RELEASE_AUTHORITY / IDENTIFIER DECISION.**

Release governance is no longer unknown: F-RB02 establishes the predecessor rule.

The current PUB-GC release must:

1. be a **new successor release**, distinct from immutable `SWAP5-RB1-v1`;
2. bind exactly one frozen source/repository postimage;
3. enumerate its delta from RB1;
4. qualify that exact successor candidate;
5. make no broader semantic-version or completeness claim unless separately authorized.

What remains unresolved is the exact successor release identifier and the authority approving it. The publication workstream must not invent `v5.0.0`, `v0.x`, a date tag, `Status-A` or another label merely for GMD.

Once that authority provides the identifier, the remaining mechanical actions are straightforward:

1. bind the identifier to the exact submission commit;
2. create the tag/release;
3. record it in the manuscript title and reproducibility manifest;
4. archive that exact release persistently.

## 2. A2 — software licence authority

### 2.1 Official SWAP project authority

The official SWAP website currently states that SWAP version 4 is free software distributed under the **LESSER GNU GENERAL PUBLIC LICENSE version 3**, with a small number of TTUTIL files distributed under LGPL 2.1.

Authoritative project pages checked 2026-09-18:

- `https://swap.wur.nl/faq.html`;
- `https://swap.wur.nl/downloads.html`;
- official SWAP 4 licence page.

The official downloads page identifies SWAP 4.3.1 as the June 2026 development release.

### 2.2 Exact historical distribution authority

The exact externally governed distribution used in SWAP5 qualification is:

```text
SWAP_4.3.1.zip
size:    8,959,314 bytes
SHA-256: 2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
```

Its embedded licensing material was inspected without redistributing the archive.

Embedded file identities:

| member | bytes | SHA-256 |
| --- | ---: | --- |
| `SWAP_4.3.1/license/License.txt` | 919 | `a91468a75fcaf481cc8c214e65574ab9bbcb5e389d3a08d1c651c335214d5a4d` |
| `SWAP_4.3.1/license/GNU_General_Public_License_version_3.md` | 35,568 | `ff08a0e8b0d9ef0db1b5923e2b720b8607cbf38395295054d8126e02870e72ef` |
| `SWAP_4.3.1/readme_4.3.1.txt` | 5,093 | `519b92608cf1786353072653cde76ade12b820f003d6ea79a062172ea8f17e96` |

The embedded `License.txt` states the same project licence terms as the official website. The embedded README identifies the package as SWAP version 4.3.1, release date 30 June 2026, developed by Wageningen University and Research and copyrighted by Wageningen Environmental Research.

This closes uncertainty about the **historical SWAP 4 licence source**.

### 2.3 What this does not decide

The public SWAP5 repository is a modernized successor containing substantial new and restructured source code. Its root README deliberately says:

> The licence files originate from the SWAP 4.3.1 distribution. Repository documentation does not create a separate licensing decision from the SWAP project.

No explicit root licence declaration currently states that the complete SWAP5 publication archive is redistributed under the same terms, nor does repository visibility by itself create that legal declaration.

The publication workstream therefore must distinguish:

```text
A2a — upstream/historical SWAP 4 licence authority
      VERIFIED

A2b — explicit licence/redistribution declaration for the SWAP5 publication archive
      BLOCKED_GOVERNANCE_OR_LEGAL_DECISION
```

### A2 disposition

The previous single A2 blocker was too coarse.

**Verified:** the governing SWAP 4 source line is explicitly licensed by the official SWAP project under the stated LGPL terms.

**Still required:** an authorized WUR/WENR/SWAP-project statement that the SWAP5 publication archive may be distributed under those terms (or an explicitly chosen alternative). The publication workstream may then add the corresponding root licence metadata and archive declaration.

## 3. GMD consequence

Current GMD policy requires the exact code version to be persistently archived and identified, with a clear licence statement and all run/pre/postprocessing material needed for reported results.

Therefore:

- A1 still blocks the final title/version binding;
- A2b still blocks the final public archive licence statement;
- A3 DOI/PID remains downstream of A1/A2b;
- no new hydrological experiment is required.

## 4. Minimum governance decisions still needed

A controlled authority needs to provide only two decisions.

### Decision R1 — successor release identity

Provide the exact **new successor** publication release identifier/tag label for the submission commit. It must not reuse or move `SWAP5-RB1-v1`, and its release record must enumerate the post-RB1 delta as required by F-RB02.

### Decision L1 — SWAP5 archive licence

Confirm either:

1. SWAP5 publication archive inherits the official SWAP version-4 licence terms, with TTUTIL retaining its separately stated LGPL 2.1 terms; or
2. specify the alternative authorized licence/redistribution statement.

No other scientific or numerical decision is needed to proceed to persistent archival.

## 5. Actions unlocked immediately after R1/L1

After those two authorities exist, the repository work can proceed with a bounded successor-release workunit and then mechanically:

- create root licence/archive metadata consistent with L1;
- create the governed release/tag consistent with R1;
- freeze exact publication revision;
- produce the public archive manifest;
- create/publish the persistent archive and obtain DOI/PID;
- bind version/PID/licence into title, Code availability and reproducibility manifest;
- run the final GMD submission gate.
