# PPA-WU05-A24 result — RFM/Richards transactional split binding

Date: 2026-10-01
Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE
Baseline: integration/f-ci-canonical@0bf4bc0aec1d1f5d157ba6b4a88f0117c854bf6b
Qualified postimage: 52ecc62bc91001f9134d77772201438d75178b7c
Qualification run: 36874847383 — SUCCESS

Focused gates:
    PPA_WU05A24_RFM_MATRIX_SOURCE_PROVIDER=PASS
    PPA_WU05A24_REAL_RICHARDS_SPLIT=PASS
    PPA_WU05A24_REAL_RICHARDS_SPLIT_GATE=PASS

## Qualified seam
A24 wraps the existing source_sink_provider_t and adds only frozen nonnegative RFM matrix-source rates. Existing base sources and sinks are preserved exactly.

RFM endpoint/MB wall transfers are derived from accepted-state physics before the trial and remain frozen during one Richards trial. This is an explicit first-order operator split, not a monolithic nonlinear solve.

## Real Richards evidence
The production Reference Richards/B1.10 fixture was run from the same accepted origin:
- baseline source route;
- RFM wrapped source route;
- exact replay of the RFM route.

All converged. The RFM source changes the matrix candidate. The accepted base pressure head and water content remain bit-identical. RFM candidate head/theta replay is bit-identical at O0 and O2, and the integrated solver mass residual is available and within the declared tolerance.

## Negative evidence
Run 36874406617 failed only because the synthetic test provider used an internal type-bound procedure form rejected by gfortran. Production provider compiled.
Run 36874740530 failed before the A24 test because the borrowed A8 compile list included an unrelated standard-macropore runtime dependency. The A24 runner was reduced to its actual Richards dependency surface. Neither failure falsified A24 physics.

## Boundary
A24 does not remove FMR_OPTIONAL_STATE_LAYOUT_RFM runtime NOT_ADMITTED. Guard removal is a separate A25 admission decision after canonical preservation of A23+A24.

## Decision
    RFM_MATRIX_SOURCE_ABI = QUALIFIED
    REAL_RICHARDS_SPLIT_TRIAL = QUALIFIED
    ACCEPTED_ORIGIN_IMMUTABILITY = QUALIFIED
    RETRY_REPLAY = QUALIFIED
    A20_RUNTIME_GUARD_REMOVAL = READY_FOR_SEPARATE_A25
