# D3a implementation status map

**Date:** 2026-09-04

> **Historical/superseded for current-state claims.** This record remains valid evidence of the 2026-09-04 documentation publication and migration state. It is no longer the current SWAP5 implementation-status authority. For the 2026-09-16 Status-A boundary, use `docs/status-a/CURRENT_STATUS.md` and the hash-anchored Status-A release-readiness authority. The historical conclusions below are intentionally preserved rather than rewritten.

## Goal

Create one evidence-based architecture-to-implementation register for the SWAP5 migration so that target design, active refactoring, partial prototypes and qualified implementation are not conflated.

## Result

Status: `PUBLISHED_VERIFIED`

D3a added `docs/architecture/implementation-status.md` as the central implementation register **for this 2026-09-04 migration snapshot** and linked it from the architecture navigation and overview.

The map uses the controlled status vocabulary:

- `BASELINE`
- `TARGET`
- `PARTIAL`
- `IN_PROGRESS`
- `QUALIFIED`

The snapshot was deliberately conservative. Active transactional and `headcalc` refactoring was recorded as `IN_PROGRESS`; architecture contracts without integrated production evidence remained `TARGET`; existing prototypes/testbanks were `PARTIAL`. Narrow qualified solver/audit work was not promoted into a broader architecture capability unless the broader capability itself had been integrated and verified at that time.

## Traceability

Each capability row records:

- status at the snapshot date;
- evidence or migration position at that date;
- the next proof then required to advance status;
- affected SWAP core architecture invariants.

The publication verifier was also extended so the D3a page was part of the live GitHub Pages acceptance gate.

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

D3a was therefore administratively closed as `PUBLISHED_VERIFIED` for its recorded 2026-09-04 state. Later canonical admissions and Status-A closure supersede it only for present-state claims, not as evidence that this publication occurred.