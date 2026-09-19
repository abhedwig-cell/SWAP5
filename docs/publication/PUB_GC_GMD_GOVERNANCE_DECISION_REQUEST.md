# PUB-GC GMD governance decision request

## Status

**TWO AUTHORITY VALUES REQUIRED — NO SCIENTIFIC DECISION OPEN**

Date: 2026-09-19.

The scientific PUB-GC package is closed through E7. GMD archival completion needs two controlled values.

## Technical candidate already frozen

The publication workstream has now frozen an **unversioned technical publication candidate** without assigning a release name:

```text
scientific source / canonical merge:
781c829943c9e5880e5ab83281112e66f439ecf2

Git tree:
9ca065553765e38eec4d4ceb611ec80d866dbae3

candidate authority:
release/pub-gc-gmd/PUB_GC_GMD_UNVERSIONED_CANDIDATE.json

complete RB1 -> candidate src/reference delta:
release/pub-gc-gmd/PUB_GC_GMD_RB1_TO_CANDIDATE_DELTA.json
```

The PR #351 subject head and canonical merge have the same tree. That tree passed F-CI canonical qualification, Documentation, F-GC42, E7 and the GMD pre-submission gate. Later moving-canonical work is not silently included.

Accordingly R1 no longer requires technical candidate selection or delta reconstruction. It requires only the controlled release identity for this exact candidate (or an explicit instruction to create a different candidate).

## R1 — successor publication release identifier

Required:

```text
SWAP5_PUBLICATION_RELEASE_IDENTIFIER = <authority value>
```

Constraints:

- one exact immutable successor to `SWAP5-RB1-v1`;
- binds to the frozen publication candidate tree above unless governance explicitly requests a different candidate;
- identifies the precise paper release;
- uses the already persisted complete RB1-to-candidate source/reference delta and qualification record;
- stable after publication;
- not invented by the publication workstream.

## L1 — SWAP5 publication-archive licence / redistribution statement

Required:

```text
SWAP5_PUBLICATION_ARCHIVE_LICENCE = <authorized statement>
```

The statement must govern the actual SWAP5 publication archive. Upstream SWAP 4 licence evidence may inform the decision but is not itself a SWAP5 publication-release decision.

The statement should also specify the allowed access route, if any, for the separately governed historical SWAP 4.3.1 reference distribution during review.

## Minimal authority response

```text
R1 release identifier:
<exact value>

L1 SWAP5 publication archive licence/redistribution statement:
<exact authorized statement>

Authority:
<name/role or governing record>

Effective date:
<date>
```

Once R1/L1 exist, archive creation, DOI binding, title update and final Code/Data wording are mechanical.


## Current decision surface

After the technical freeze, the unresolved authority surface is intentionally minimal:

```text
R1:
Assign the final publication release identifier to tree
9ca065553765e38eec4d4ceb611ec80d866dbae3
(source commit / canonical merge 781c829943c9e5880e5ab83281112e66f439ecf2).

L1:
State the authorized SWAP5 publication-archive licence / redistribution terms
and the permitted reviewer-access route, if any, for the separately governed
SWAP 4.3.1 reference distribution.
```

A DOI/PID is mechanical only after these two authority values exist.
