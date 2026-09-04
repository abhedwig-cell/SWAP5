# D3e M3 gate evidence

**Date:** 2026-09-04

## Goal

Evaluate the active transactional interval refactoring against the M3 exit gate and identify the minimum remaining implementation and qualification work before M3 may be declared complete.

## Result

Status: `COMPLETE_PENDING_PUBLICATION_GATE`

D3e adds `docs/architecture/m3-gate-evidence.md` as the evidence dossier for migration slice M3.

The assessment deliberately does not promote the M3 implementation-status row. The current verdict is `IN_PROGRESS_NOT_READY_TO_EXIT` / `NO_EXIT_YET`.

## Evidence already recognised

- explicit trial-result structure including `BareSoilTrialResult`;
- replacement of the broad full snapshot by `sd_full_result`;
- reuse of `sd_half2_result%endpoint` and removal of redundant `sd_h_half_end`, `sd_theta_half_end` and `sd_pond_half_end` copies;
- progressive separation of transaction execution from legacy `swap.f90` control flow;
- explicit solver-attempt status as a runtime/solver seam;
- retry-policy extraction from legacy `SoilWaterStateVar(2)` / `TimeControl(5)` coupling;
- active extraction of orchestration for one complete transactional interval;
- supporting sub-day/API evidence from prior 6-hour synchronization and coupling testbanks.

The supporting testbank results are not treated as direct proof of the M3 rollback/retry gate.

## Remaining minimum cuts

D3e identifies four bounded cuts:

1. **M3-C1 authoritative commit owner**: one code path alone may replace committed physical state.
2. **M3-C2 committed accounting versus attempt accounting**: rejected-attempt storage and integrated fluxes must never enter committed accounting.
3. **M3-C3 warm-start side channel**: numerical warm-start ownership must be separate from authoritative physics.
4. **M3-C4 generic-time acceptance**: qualify a non-midnight start and non-day interval through the complete transaction path.

C1 and C2 are the immediate priority because rollback and retry mass-balance qualification are not meaningful until those ownership boundaries are hard.

## Qualification set

The dossier defines M3-T01 through M3-T10 covering normal commit, forced rejection, retry flux accounting, deterministic rerun, warm-start independence, non-midnight/non-day intervals, retry diagnostics, physics-policy invariance and retry water balance.

## Publication gate

D3e becomes `PUBLISHED_VERIFIED` only when the Documentation workflow passes:

1. repository source/link/navigation checks;
2. `mkdocs build --strict`;
3. GitHub Pages deployment;
4. live verification of `architecture/m3-gate-evidence/`, including the exit matrix, C1/C2 and `NO_EXIT_YET` verdict.

## Follow-on

After publication, the next implementation step should be M3-C1 followed immediately by M3-C2. D3e should be updated only when new code/test evidence changes a gate status.