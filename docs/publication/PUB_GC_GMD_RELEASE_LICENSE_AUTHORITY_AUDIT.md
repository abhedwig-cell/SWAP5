# PUB-GC GMD release and licence authority audit

## Status

**A1 RELEASE IDENTIFIER UNRESOLVED / A2 UPSTREAM TERMS OBSERVED, SWAP5 ARCHIVE DECLARATION STILL AUTHORITY-BOUND**

Date: 2026-09-19.

Current-canonical basis:

`integration/f-ci-canonical@faf33c1fb023a164a6456da160422685c32a88c4`.

This audit narrows the remaining GMD submission blockers without inventing a release identifier, software licence, DOI or redistribution permission.

## A1 — successor publication release identity

A frozen predecessor authority exists:

```text
release id: SWAP5-RB1-v1
authority branch: release/f-rb02-restricted-production-baseline-v1-final-authority
final authority commit: b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0
```

F-RB02 states that `SWAP5-RB1-v1` is immutable and that later canonical development does not alter RB1. A future release must enumerate its delta from RB1 and qualify its own candidate.

The PUB-GC manuscript uses substantial post-RB1 development, including the production coupling/application surface and E1–E7 publication evidence. Therefore RB1 cannot be moved, reused or silently reinterpreted as the paper's release.

The current Status-A release-readiness authority reports:

`READY_FOR_STATUS_A_RELEASE_CANDIDATE_BOUNDARY`.

This permits creation of a successor release authority. It does not choose its name.

### A1 decision still required

A controlling authority must provide one stable identifier for the exact publication release. Until then:

- do not invent a semantic version;
- do not move `SWAP5-RB1-v1`;
- do not put an invented version in the final GMD title;
- do not create a persistent archive claiming to be the final paper release.

## A2 — software licence / redistribution authority

The repository README intentionally says that licence files originate from SWAP 4.3.1 and that repository documentation does not create a separate licensing decision from the SWAP project.

The exact historical SWAP 4.3.1 distribution used as reference authority has frozen identity:

- SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- size 8,959,314 bytes.

Historical package evidence records licence material associated with SWAP version 4 and TTUTIL. That upstream observation is useful provenance, but the publication workstream is not the legal/governance authority that can declare which terms apply to the derived SWAP5 publication archive.

### A2 decision still required

A controlling authority must state:

1. the licence to state for the public SWAP5 publication release;
2. whether the complete governed publication revision may be redistributed under that licence;
3. how the non-redistributed historical SWAP 4.3.1 reference asset may be provided to editors/reviewers if requested.

The decision may confirm upstream terms, but this audit does not do so on its own authority.

## A3 — persistent archive

GMD requires persistent public archives identifying the precise code/data versions used, normally through a DOI or equivalent persistent identifier.

A3 is mechanical after A1 and A2:

1. bind exact publication commit;
2. create the governed successor release;
3. archive that exact release and publication evidence;
4. obtain DOI/PID;
5. bind title, Code and data availability, and reproducibility manifest to that identity.

GitHub's moving development branch is not substituted for the frozen persistent archive.

## Current conclusion

The remaining archive blocker is **governance/metadata, not science**.

No new hydrological experiment, positive Hupsel trajectory, solver change or tolerance change can resolve A1/A2/A3.


## External official evidence update — 2026-09-19

The upstream licence evidence has now been verified against public official WUR/SWAP sources.

- The official SWAP 4 technical addendum states that SWAP source code and executable are distributed under **GNU GENERAL PUBLIC LICENSE Version 2, June 1991**.
- The WUR research-software licensing guidance states that research software reuse terms should be made explicit and that WUR does not mandate one single software licence.
- Evidence and URLs are frozen in `PUB_GC_GMD_LICENSE_EXTERNAL_EVIDENCE.md` and `PUB_GC_GMD_LICENSE_EXTERNAL_EVIDENCE.json`.

### Effect on A2/L1

This removes uncertainty about **upstream SWAP 4 licence provenance**.

It does **not** authorize this publication workstream to declare the exact SWAP5 publication candidate under a particular SPDX expression or redistribution statement. That final release declaration remains authority-bound.

The remaining L1 decision is therefore narrow: confirm the exact licence/redistribution wording for candidate tree `9ca065553765e38eec4d4ceb611ec80d866dbae3`, including the treatment of the separately governed SWAP 4.3.1 reference asset.
