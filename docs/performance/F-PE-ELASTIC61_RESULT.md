# F-PE-ELASTIC61 — mode-7 conservative head-error envelope result

Date: 2026-09-30

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic61-mode7-error-envelope`

Qualified postimage:
`47fa7bf529dc0bf7fc9949c3541d1b9b7d24ffed`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36704181538`

Job:
`109850403465`

Conclusion:
SUCCESS.

## Purpose

Admit only the typed production normalization layer between the canonically
admitted mode-7 Richards defect indicator and an explicit caller-owned physical
head budget.

No default physical budget and no timestep controller are introduced.

## Production delta

Exactly one production source file is added:

`src/adapter/mod_fmr_mode7_temporal_head_envelope.f90`.

The adapter is stateless and exposes the frozen qualified conservative scaling:

`alpha = 0.17320259355765216`.

Given:
- `head_inf_bound_cm`;
- explicit caller-owned `head_budget_cm`;

it computes:

`estimated_head_error_cm = alpha * head_inf_bound_cm`

and for positive budget:

`normalized_error = estimated_head_error_cm / head_budget_cm`.

Acceptance is:

`normalized_error <= 1`.

## No hidden default

The adapter contains no temporal head-budget value.

A caller must supply the physical budget explicitly.

This preserves the F-CI14 ownership rule that physical temporal limits are not
borrowed from solver convergence tolerances or silently installed as numerical
defaults.

## Exact alpha qualification

Qualification confirms bit identity of the public production constant with:

`0.17320259355765216_real64`.

Observed marker:

`ELASTIC61_ALPHA=1.73202593557652162E-001`.

A1 exact alpha: PASS.

## Formula and threshold semantics

Qualification verifies:
- below-threshold estimate -> accepted;
- exact-threshold estimate -> accepted;
- above-threshold estimate -> rejected;
- normalized-error identity;
- estimate identity.

A2 formula: PASS.
A3 threshold behavior: PASS.

## Zero-budget semantics

For explicit zero budget:
- zero estimate -> accepted with normalized error 0;
- positive estimate -> rejected.

No division by zero is performed.

A4 zero-budget semantics: PASS.

## Fail-closed input behavior

Negative or nonfinite bound/budget values return an incomplete invalid
assessment.

The first qualification run exposed a Fortran evaluation-order hazard:
combining the finite test and numeric comparison in one `.or.` expression can
still evaluate the comparison on NaN when invalid floating-point traps are
enabled.

The implementation was corrected to sequential finite checks before numeric
comparisons.

Final qualification with
`-ffpe-trap=invalid,zero,overflow`
passes.

A5 fail closed: PASS.

## Preservation

The qualification replays the existing production seams rather than treating
the new adapter as independent of its inputs.

### Mode-7 typed mass

ELASTIC59 typed mode-7 mass publication is replayed with O0/O2 identity.

`F_PE_ELASTIC61_A7_TYPED_MASS_PRESERVATION=PASS`.

### Mode-7 defect indicator

The canonically admitted ELASTIC60 production mode-7 indicator oracle is
replayed.

Qualified mode-7 availability and operator semantics remain unchanged.

### Mode-2 and mode-5 temporal seams

The preserved prescribed-qbot and prescribed-head temporal indicator seams
remain green at O0/O2.

`F_PE_ELASTIC61_A7_INDICATOR_PRESERVATION=PASS`.

## O0/O2 and scope

Unit-level output is semantically identical at O0 and O2.

`F_PE_ELASTIC61_A8_O0_O2=PASS`.

Production source delta is exactly:

`src/adapter/mod_fmr_mode7_temporal_head_envelope.f90`.

No existing production source changes.

`F_PE_ELASTIC61_A9_SOURCE_SCOPE=PASS`.

## Architecture

Preserved:
- solver versus execution-policy separation;
- hard mass acceptance;
- committed/candidate transaction ownership;
- explicit application-owned temporal accuracy;
- Full Richards Reference mode;
- no silent numerical defaults.

Affected invariants:
- 7 transactional timesteps: preserved;
- 13 mass conservation: preserved;
- 23 physical options versus numerical policy: strengthened by explicit
  separation;
- 25 Reference mode: preserved;
- 26 diagnostics: unchanged.

## Decision

Classification:

`QUALIFIED_MODE7_CONSERVATIVE_HEAD_ENVELOPE_ADMISSION_CANDIDATE`.

Admission scope:

`admitted mode-7 Binf + frozen conservative alpha + explicit caller-owned
head budget -> typed normalized head-error assessment`.

Still outside:
- any default physical head budget;
- a complete F-CI14 eight-metric numeric profile;
- C-SAFE production controller integration;
- default-on temporal control;
- swkimpl=1;
- any relaxation of hard mass acceptance.

Canonical admission may proceed as a separate integration action.
