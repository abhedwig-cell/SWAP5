# PUB-GC GMD governance decision request

## Status

**TWO AUTHORITY VALUES REQUIRED — NO SCIENTIFIC DECISION OPEN**

Date: 2026-09-19.

The scientific PUB-GC package is closed through E7. GMD archival completion needs two controlled values.

## R1 — successor publication release identifier

Required:

```text
SWAP5_PUBLICATION_RELEASE_IDENTIFIER = <authority value>
```

Constraints:

- one exact immutable successor to `SWAP5-RB1-v1`;
- identifies the precise paper release;
- accompanied by an explicit RB1-to-successor delta/qualification record;
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
