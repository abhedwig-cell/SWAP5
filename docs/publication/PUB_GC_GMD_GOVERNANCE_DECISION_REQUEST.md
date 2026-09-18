# PUB-GC GMD governance decision request

## Status

**TWO AUTHORITY VALUES REQUIRED — NO SCIENTIFIC DECISION OPEN**

Date: 2026-09-18.

The PUB-GC paper is scientifically closed through E7 and the GMD prearchive package is prepared. Persistent archival cannot be finalized until two controlled authority values are supplied.

## R1 — publication release identifier

Required value:

```text
SWAP5_PUBLICATION_RELEASE_IDENTIFIER = <<AUTHORITY_VALUE>>
```

Constraints:

- must identify the exact SWAP5 release described by the paper;
- must be suitable for a persistent archive and the GMD title;
- must be a new successor identity distinct from immutable `SWAP5-RB1-v1`;
- must bind one exact post-RB1 source and accompany an explicit RB1-to-successor delta/qualification record;
- should be stable after publication;
- must not be invented by the publication workstream.

Current evidence:

- immutable predecessor release authority exists: `SWAP5-RB1-v1`;
- F-RB02 final authority commit: `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`;
- F-RB02 requires every future release to enumerate its delta from RB1 and qualify its own candidate;
- `SWAP5-RB1-v1` may not move or be reinterpreted;
- no release/tag has been published for the current canonical;
- no authorized successor release identifier for the PUB-GC submission has been found.

Therefore R1 is not a request to invent a general versioning scheme. It is the narrower decision that names the next immutable successor release under the already-established F-RB02 rule.

## L1 — SWAP5 publication-archive licence / redistribution authority

Required statement:

```text
SWAP5_PUBLICATION_ARCHIVE_LICENCE = <<AUTHORIZED_STATEMENT>>
```

The decision may confirm the official SWAP version-4 terms for the SWAP5 publication archive or provide another authorized statement.

Verified upstream authority, which does **not** by itself substitute for L1:

- official SWAP version 4: LESSER GNU GENERAL PUBLIC LICENSE version 3;
- TTUTIL427.LIB: LGPL 2.1;
- exact SWAP 4.3.1 package contains the same licence statement.

Current repository README deliberately does not create a separate licensing decision.

## No other governance decision is needed for archive preparation

Once R1 and L1 exist, the remaining sequence is mechanical:

1. bind exact publication commit;
2. create release/tag metadata consistent with R1;
3. add/archive licence metadata consistent with L1;
4. create persistent exact-version archive;
5. obtain DOI/PID;
6. fill title and Code/Data Availability;
7. run strict submission gate.

## Response form for the controlling authority

A minimal authority record can be expressed as:

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

This file is a request template only and carries no release or legal authority by itself.
