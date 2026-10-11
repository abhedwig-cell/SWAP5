# F-PE-ELASTIC65 — mode-7 C-SAFE certificate binding result

Date: 2026-09-30

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic65-mode7-csafe-binding`

Qualified postimage:
`891bc98e466d1e3e55396e406fa7259d20b1be19`

Canonical baseline:
`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

Workflow run:
`36706279185`

Job:
`109857176107`

Conclusion:
SUCCESS.

## Purpose

Bind the already admitted bottom-mode-7 defect indicator and conservative
ELASTIC61 head-error envelope into the existing model-certificate transaction
path without introducing a new timestep-control algorithm or a default physical
head budget.

## Production delta

Exactly one existing production file changes:

`src/runtime/mod_fmr_serialized_reference_backend.f90`.

The runtime now imports the admitted ELASTIC61 stateless envelope adapter and,
for bottom mode 7 only, converts:

`Binf`
-> `alpha * Binf`
-> explicit caller-owned head budget normalization
-> dimensionless model certificate.

Frozen alpha remains:

`0.17320259355765216`.

Modes 2 and 5 retain their existing native Binf/budget normalization.

## Transaction behavior

No new controller is added.

The existing transaction path already:
- evaluates each attempted dt independently;
- applies hard mass acceptance before temporal acceptance;
- retries using the configured retry scale;
- re-evaluates the certificate after refinement;
- never infers that the next smaller dt must improve the indicator;
- commits only after all required acceptance gates pass.

ELASTIC65 therefore realizes the qualified C-SAFE pattern by composition with
the existing transaction semantics.

## Qualification result

### A1 — exact mode-7 normalization

Qualified mode-7 probe:

- Binf = `5.1734683336191649e-6 cm`;
- generous explicit head budget = `100 cm`;
- normalized certificate =
  `8.9605813307122422e-9`.

The observed certificate matches:

`alpha * Binf / head_budget`.

PASS.

### A2 — refine and recheck

A physical head budget was chosen below the first-attempt estimated error.

Observed:
- first attempt rejected temporally;
- retries = `1`;
- accepted refined dt = `0.005 day`;
- accepted certificate <= 1;
- no monotonicity prediction was used.

PASS.

### A3 — missing budget fail closed

With the caller-owned model budget absent:
- result does not complete;
- the existing certificate-unavailable/temporal-rejection path is exercised.

No default budget is substituted.

PASS.

### A4 — hard mass remains independent

On the qualified retry path:
- mass rejection count = `0`;
- temporal acceptance does not bypass or replace hard mass acceptance.

No mass tolerance is changed.

PASS.

### A5 — mode-2 preservation

The F-SI38 prescribed-qbot temporal-certificate path remains green and O0/O2
consistent.

PASS.

### A6 — mode-5 preservation

The qualified TEMPORAL08 model-certificate/registry route remains green and
O0/O2 consistent.

PASS.

### A7 — swkimpl=1 remains fail closed

Bottom mode 7 with `swkimpl=1` does not enter the admitted temporal-indicator
envelope and is rejected through existing fail-closed admission/certificate
semantics.

PASS.

### A8 — O0/O2 semantic identity

The mode-7 qualification output is identical at O0 and O2.

PASS.

### A9 — production source scope

The only `src/**` change is:

`src/runtime/mod_fmr_serialized_reference_backend.f90`.

PASS.

## Architecture

Preserved:
- solver versus execution-policy separation;
- explicit caller ownership of the physical head budget;
- hard mass acceptance;
- transaction rollback/retry/commit ownership;
- no numerical default for the physical budget;
- Full Richards Reference availability;
- mode-2 and mode-5 existing semantics.

ELASTIC65 does not change:
- Richards equations;
- HeadCalc;
- constitutive relations;
- nonlinear convergence;
- retry scale;
- mass tolerances;
- ELAS parameters;
- mode-7 indicator operator;
- frozen alpha.

## Relation to ELASTIC56/57B

ELASTIC56 showed local Binf nonmonotonicity.

ELASTIC57/57B showed that a controller is robust when it re-evaluates each
refined point and does not assume monotonic improvement.

ELASTIC65 does exactly that through the existing transaction machinery.

The production binding therefore does not encode any
`Binf(dt/2) <= Binf(dt)`
assumption.

## Decision

Classification:

`QUALIFIED_MODE7_CSAFE_CERTIFICATE_BINDING_ADMISSION_CANDIDATE`.

Qualified production scope:

`bottom_mode=7 + swkimpl=0 + admitted temporal-history state
 + explicit positive caller-owned head budget
 -> ELASTIC61-normalized certificate
 -> existing mass-first refine/recheck transaction path`.

Still outside:
- any default physical head budget;
- a complete F-CI14 eight-metric numeric profile;
- default-on mode-7 temporal control;
- swkimpl=1;
- optional-process combinations outside the admitted indicator envelope;
- any mass-tolerance relaxation.

The next permitted action is canonical admission of this bounded production
binding.
