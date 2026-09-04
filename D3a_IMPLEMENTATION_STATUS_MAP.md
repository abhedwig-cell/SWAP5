# D3a implementation status map

**Date:** 2026-09-04

## Goal

Create one evidence-based architecture-to-implementation register for the SWAP5 migration so that target design, active refactoring, partial prototypes and qualified implementation are not conflated.

## Result

Status: `PUBLISHED_VERIFIED`

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

## Publication evidence

GitHub Actions run `33884248051` completed successfully for documentation commit `123b46b974e3552558450d0763e7922d9d651e9f`.

The acceptance chain passed:

1. repository documentation checks;
2. `mkdocs build --strict`;
3. GitHub Pages deployment;
4. live verification of the published site.

The live verifier explicitly confirmed:

- `https://abhedwig-cell.github.io/SWAP5/`
- `https://abhedwig-cell.github.io/SWAP5/architecture/overview/`
- `https://abhedwig-cell.github.io/SWAP5/architecture/implementation-status/`
- `https://abhedwig-cell.github.io/SWAP5/architecture/invariants/`
- `https://abhedwig-cell.github.io/SWAP5/development/publication/`

D3a is therefore administratively closed as `PUBLISHED_VERIFIED`.
