# F-PE-ELASTIC60 — closeout

Date: 2026-09-30

Status: CLOSED_PRODUCTION_ADMITTED

Canonical admission:
`integration/f-ci-canonical@72a6c24878fd5f287fa1d42c89126c41e9ad67d7`

Admission PR:
`#893 — F-PE-ELASTIC60: admit mode-7 Richards defect indicator`

Qualified owner evidence:
- branch postimage: `2113f790995ec4bec81a7e17eced9d30ab0fb7b2`;
- qualification run: `36692957387`;
- qualification job: `109814173023`;
- admission gate on final PR head: PASS;
- Validate and build on final PR head: PASS.

## Admitted capability

The production Reference Richards temporal defect indicator now admits:

`bottom_mode = 7`

within the existing indicator envelope and specifically the qualified
`swkimpl=0` / conductivity-implicit-mode-0 path.

The production change is bounded to
`src/solver/mod_reference_richards_temporal_indicator.f90` and expands only
the boundary-mode availability condition.

The mode-7 operator adds no bottom stiffness, consistent with the production
`swkimpl=0` linearization and the independent ELASTIC53/60 oracle evidence.

## Preserved boundaries

Still fail closed / not admitted:
- mode 7 with `swkimpl=1`;
- unsupported top-boundary/provider/process envelopes;
- unavailable or invalid temporal history;
- non-converged candidates.

Mode 2 and mode 5 temporal-indicator semantics remain preserved.

## Not admitted by ELASTIC60

ELASTIC60 does not admit:
- a numeric temporal head budget;
- the empirical alpha normalization as a production default;
- C-SAFE production controller integration;
- default-on mode-7 temporal control;
- optional-process combinations outside the existing indicator envelope.

Those remain separate policy/application work.

## Supporting research chain

The admission is backed by the bounded evidence chain:
- ELASTIC53 — mode-7 defect-indicator research candidate;
- ELASTIC54 — global conservative scaling calibration/holdout;
- ELASTIC55 — four-profile holdout with zero envelope failures;
- ELASTIC56 — localized nonmonotonicity attribution;
- ELASTIC57 — nonmonotonicity-robust refinement-controller pattern;
- ELASTIC58 — multi-metric endpoint-error characterization;
- ELASTIC59 — external physical-budget normalization.

These research results are not broadened by this admission.

## Closure

F-PE-ELASTIC60 is closed.

Production status:

`PRODUCTION_ADMITTED_MODE7_SWKIMPL0_DEFECT_INDICATOR`.
