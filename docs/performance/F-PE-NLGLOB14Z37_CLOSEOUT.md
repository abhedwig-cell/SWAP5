# F-PE-NLGLOB14Z37 closeout — compiled Fortran manager timing

Date: 2026-09-30

Final status:

`Z37_FORTRAN_TIMING_REGRESSION`

Qualification authority:

- workflow run `36770830831`;
- job `110076480952`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z37 closes negatively on timing, not on physics.

The compiled manager path is approximately 30% slower in the frozen microbenchmark while still executing about 20% less deterministic linear-solver work.

The bottleneck is therefore the current per-operation manager/request/materialization overhead, not the reduced nonlinear dimension itself.

## Direct successor

Open:

`F-PE-NLGLOB14Z38 — zero-waste persistent manager fast path`.

Freeze the exact Z37 timing benchmark unchanged and optimize only orchestration overhead.

Priority removals:

1. repeated reduced parameter allocations;
2. repeated reduced state allocations;
3. repeated workspace initialization/allocation;
4. repeated tail scratch allocation;
5. redundant full result copying;
6. full request reconstruction when only active view changes.

The persistent manager fast path must preserve:

- full accepted-state authority;
- explicit fallback/bypass;
- full-shaped published candidate;
- no-leak rollback semantics;
- typed active-dimension/fallback diagnostics.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z37

BRANCH: `research/f-pe-nlglob14z37-fortran-manager-timing`

RESULT POSTIMAGE BEFORE CLOSEOUT: `7edd267b9c7740c403ccdf0914ea4336542aa3c3`

QUALIFICATION STATUS: `Z37_FORTRAN_TIMING_REGRESSION`

NEXT SAFE STEP: Z38 persistent zero-waste manager fast path, then exact Z37 benchmark replay.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
