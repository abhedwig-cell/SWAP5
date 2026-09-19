# PUB-GC GMD external licence evidence packet

## Status

**UPSTREAM_SW4_GPLV2_EVIDENCE_CONFIRMED — SWAP5 RELEASE DECLARATION STILL AUTHORITY_REQUIRED**

Date: 2026-09-19.

This record narrows L1 using public official WUR/SWAP sources. It is an evidence packet, not a legal decision and not a SWAP5 licence declaration.

## Official upstream SWAP evidence

### SWAP 4 technical addendum

Official SWAP/WUR document:

https://swap.wur.nl/Documents/SWAP%204%20-%20Technical%20addendum%20to%20the%20SWAP%20documentation.pdf

The addendum states that SWAP source code and executable are publicly available and freely usable, and that the software is distributed under the terms of **GNU GENERAL PUBLIC LICENSE Version 2, June 1991**.

The same report is registered by Wageningen University & Research:

https://research.wur.nl/en/publications/swap-4-technical-addendum-to-the-swap-documentation/

Report DOI:

https://doi.org/10.18174/540451

This is strong upstream provenance for SWAP 4 licensing.

### Current official SWAP download page

https://swap.wur.nl/downloads.html

The current official SWAP site publicly distributes the latest major/development branches and source-containing packages. This confirms that SWAP distribution remains an official WUR-maintained public software surface.

## WUR research-software licensing guidance

Official WUR support guidance:

https://support.wur.nl/esc?id=kb_article&sysparm_article=KB0017455

The guidance explains that research software requires an explicit licence to define reuse rights and states that WUR does not require one specific software licence, while recommending research software be made as open as possible.

This matters for L1: upstream GPLv2 evidence does not itself create a new SWAP5 publication-release declaration. The exact SWAP5 archive still needs an authorized licence/redistribution statement.

## What this evidence resolves

Resolved:

- upstream SWAP 4 has explicit official GPL version 2 licensing evidence;
- the GPL observation is not merely inferred from files copied into the SWAP5 repository;
- current official WUR guidance confirms that software licensing is an explicit release decision, not something publication documentation should silently infer.

Not resolved:

- whether the exact SWAP5 publication candidate is to be declared under `GPL-2.0-only`, `GPL-2.0-or-later`, another compatible formulation, or a separately governed arrangement;
- who has authority to make that declaration for the SWAP5 publication archive;
- whether all archive contents are redistributable under the same statement;
- the reviewer-access route for the separately governed historical SWAP 4.3.1 distribution.

## Narrow L1 decision now required

The controlling authority can now answer a much narrower question:

> Given the official SWAP 4 GPL version 2 provenance and the exact frozen SWAP5 publication candidate, what exact licence/redistribution statement is authorized for the SWAP5 publication archive?

The publication workstream should not convert the upstream GPL evidence into a SWAP5 licence declaration on its own.

## Candidate binding

Unversioned publication candidate:

`release/pub-gc-gmd/PUB_GC_GMD_UNVERSIONED_CANDIDATE.json`

Scientific source tree:

`9ca065553765e38eec4d4ceb611ec80d866dbae3`

Source/canonical merge:

`781c829943c9e5880e5ab83281112e66f439ecf2`

The licence decision must apply to this exact candidate unless governance explicitly selects a different publication candidate.
