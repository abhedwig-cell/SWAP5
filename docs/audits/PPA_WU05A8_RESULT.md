# PPA-WU05-A8 result — bounded production macropore FMR integration

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_FMR_SINGLE_COLUMN_ADMISSION_CANDIDATE

Qualified head: 5edd7d6c928c2e2047c829766167f63819d21b2f
Focused qualification run: 36820455608
Canonical dependency reconciliation: integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1

## Qualified bounded scope

- Reference Richards only;
- serialized single-column FMR;
- standard macropore storage route (swmbf=1 semantics);
- no perched-zone production route;
- no surface-connected macropore top-input route;
- rapid drainage disabled in this first FMR admission scope;
- crack geometry fixed during one physical trial;
- external full/half transaction policy;
- seven-field macropore continuation state.

## Production integration achieved

- immutable FMR macropore physical configuration;
- source-bound standard-storage bottom-up canonicalization;
- dynamic macropore hydraulic-view derivation from accepted continuation state;
- matrix saturated-zone view derivation;
- outer macropore/Reference-Richards coupling while inner HeadCalc macropore flag remains inactive;
- source-rate bundle and sorptivity-history update;
- candidate-only publication;
- explicit mass accounting including macropore storage;
- macropore optional restart-state layout;
- continuous physical full/half temporal-error route for active macropore FMR.

## Transaction qualification

Focused run 36820455608 passed both mock-runtime and real-richards jobs on O0 and O2.

Real serialized FMR trial receipt:
- STATUS=0;
- COMPLETED=true;
- temporal acceptance source = external full/half;
- temporal rejections = 0;
- mass rejections = 0;
- solver rejections = 0;
- mass residual = -3.1084076285e-16 cm.

Independent bounded FMR trial receipt:
- admission rejections = 0;
- transaction calls = 1;
- attempts = 1;
- retries = 0;
- HeadCalc calls = 3;
- nonlinear iterations = 13;
- candidate ready = true;
- mass residual = -2.1337098755e-16 cm;
- macropore storage 0.2000000000 -> 0.1999916196 cm.

## Restart / rollback / replay

The same focused gate proves:
- trial leaves committed macropore state unchanged;
- discarded candidate does not mutate committed state;
- repeated trial from the same checkpoint reproduces the candidate;
- accepted candidate advances committed revision;
- persistence export carries the macropore optional-state layout;
- restore reproduces the seven-field continuation state;
- the next candidate from uninterrupted and restored state is identical.

Markers:
- PPA_WU05A8_RATE_ADAPTER=PASS;
- PPA_WU05A8_FMR_CONFIG_INITIALIZER=PASS;
- PPA_WU05A8_FMR_CONFIG=PASS;
- PPA_WU05A8_RUNTIME_ADAPTER_GATE=PASS;
- PPA_WU05A8_FMR_SERIALIZED_RUNTIME=PASS;
- PPA_WU05A8_FMR_REJECT_REPLAY=PASS;
- PPA_WU05A8_FMR_RESTART=PASS;
- PPA_WU05A8_FMR_MACRO_TRIAL=PASS;
- PPA_WU05A8_REAL_RICHARDS_GATE=PASS.

## Canonical-delta reconciliation

Canonical advanced to 0b231d16 through the non-default moving-interface-manager admission.
The 15-commit canonical delta from the A8 merge base changes the moving-interface manager, timestep numerical profile, tests/workflows and performance documentation only.
It does not mutate the A8 macropore/FMR/transaction/restart/Reference-Richards dependency surface.
Existing A8 qualification is therefore dependency-compatible with current canonical.

## Admission packaging decision

PR #922 is not suitable for canonical merge as-is: it is closed/draft and carries the complete A1-A8 research history (hundreds of commits and more than one hundred changed files).

The safe next step is a selective admission branch from current canonical containing only the production macropore postimage and the minimum qualification/admission evidence.

## Decision

QUALIFIED_PRODUCTION_FMR_SINGLE_COLUMN_ADMISSION_CANDIDATE_READY_FOR_SELECTIVE_CANONICAL_PACKAGING.