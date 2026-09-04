# D3a implementation status map

**Date:** 2026-09-04

## Goal

Create one evidence-based architecture-to-implementation register for the SWAP5 migration so that target design, active refactoring, partial prototypes and qualified implementation are not conflated.

## Result

Status: `COMPLETE_PENDING_PUBLICATION_GATE`

D3a adds `docs/architecture/implementation-status.md` as the central implementation register and links it from the architecture navigation and overview.

The map uses the controlled status vocabulary:

- `BASELINE`
- `TARGET`
- `PARTIAL`
- `IN_PROGRESS`
- `QUALIFIED`

The current snapshot is deliberately conservative. Active transactional and `headcalc` refactoring is recorded as `IN_PROGRESS`; architecture contracts without integrated production evidence remain `TARGET`; existing prototypes/testbanks are `PARTIAL`. Narrow qualified solver/audit work is not promoted into a broader architecture capability unless the broader capability itself has been integrated and verified.

## Traceability

Each capability row records:

- present status;
- current evidence or migration position;
- the next proof required to advance status;
- affected SWAP core architecture invariants.

The publication verifier has also been extended so the D3a page is part of the live GitHub Pages acceptance gate.

## Completion gate

D3a becomes `PUBLISHED_VERIFIED` when the Documentation workflow succeeds through:

1. repository documentation checks;
2. `mkdocs build --strict`;
3. GitHub Pages deployment;
4. live verification of `architecture/implementation-status/`.
