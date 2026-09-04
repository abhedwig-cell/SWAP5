# D3c legacy-to-target migration map

**Date:** 2026-09-04

## Goal

Map the complete supplied SWAP 4.3.1 Fortran source baseline onto the SWAP5 target component boundaries without assuming one-to-one replacement of legacy files.

## Result

Status: `PUBLISHED_VERIFIED`

D3c maps all 63 `.f90` files from the supplied SWAP 4.3.1 source archive exactly once. The documentation consists of a normative migration overview plus four inventory pages:

- `docs/architecture/legacy-migration.md`;
- `docs/architecture/legacy-migration-control.md`;
- `docs/architecture/legacy-migration-hydraulic.md`;
- `docs/architecture/legacy-migration-processes.md`;
- `docs/architecture/legacy-migration-biophysics.md`.

## Key conclusions

1. `swap.f90`, `soilwater.f90`, `headcalc.f90`, `variables.f90` and `arrays.f90` are architectural decomposition seams, not candidates for one-to-one renaming.
2. Legacy I/O and output responsibilities remain available through adapters, while kernel code becomes typed and file-independent.
3. The qualified Richards mathematics in `headcalc.f90` should be retained while boundary/source contracts, attempt status, retry policy and worker scratch are separated from solver internals.
4. Global state containers are migration inventories: information is classified and retained where physically/numerically required, while broad mutable global ownership is retired.
5. Physical modules are migrated family by family and retain reference physics; optional functionality must only incur state and compute cost when active.
6. Legacy globals and monolithic control paths are retired only after reference, mass-balance and affected-invariant qualification passes.

## Migration action vocabulary

D3c uses explicit actions including `RETAIN_*`, `SPLIT*`, `DECOMPOSE*`, `ADAPTER*`, `REPLACE_INTERFACE` and `*_RETIRE*`. A retire action applies to the legacy container/control path only after extracted behaviour is qualified; it never instructs deletion of physical behaviour before equivalence is proven.

## Verification evidence

GitHub Actions run `33885392856` passed the complete publication chain for documentation commit `2ed2f6c16df4dd760e7bd03d63b06ddd293d6443`:

1. repository source/link/navigation checks: passed;
2. `mkdocs build --strict`: passed;
3. GitHub Pages deployment: passed;
4. live verification: passed for the D3c overview and all four inventory pages.

The live verifier confirmed:

- `/architecture/legacy-migration/`;
- `/architecture/legacy-migration-control/`;
- `/architecture/legacy-migration-hydraulic/`;
- `/architecture/legacy-migration-processes/`;
- `/architecture/legacy-migration-biophysics/`.

## Follow-on

The next logical step is to turn this file map into explicit migration slices with dependency/exit gates, rather than beginning broad source rewrites. The active transactional controller and `headcalc` extraction work should be mapped onto those slices and update the implementation-status register only when evidence changes.
