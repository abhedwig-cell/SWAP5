# F-PE-ELASTIC65 — closeout

Date: 2026-09-30

Status: CLOSED_PRODUCTION_ADMITTED

Canonical admission:
`integration/f-ci-canonical@889c871f6d5f487730ce8d81feaaf8ed2335e214`

Admission PR:
`#898 — F-PE-ELASTIC65: admit mode-7 C-SAFE certificate binding`

Qualified owner evidence:
- qualified production postimage: `891bc98e466d1e3e55396e406fa7259d20b1be19`;
- original owner qualification run: `36706279185`;
- original owner job: `109857176107`;
- final admission head: `5bcb11195492ab87e020a6ad0d3c4bb1e49830a9`;
- final extended owner run: `36712145340`;
- final extended owner job: `109876237318`;
- final extended owner conclusion: SUCCESS.

## Admitted capability

Production now binds the canonically admitted mode-7 Richards temporal defect
indicator to the canonically admitted ELASTIC61 conservative head-error
envelope inside the existing model-certificate transaction path.

For the bounded admitted route:

`bottom_mode = 7`

and

`swkimpl = 0`

with admitted temporal-history continuation and an explicit caller-owned
positive pressure-head budget:

`Binf`
-> `estimated_head_error = 0.17320259355765216 * Binf`
-> divide by explicit head budget
-> normalized model certificate
-> existing mass-first retry/accept transaction path.

No default physical head budget is introduced.

## Controller semantics

ELASTIC65 does not add a new timestep-controller algorithm.

The existing transaction path:
- evaluates each attempted dt independently;
- applies hard mass acceptance before temporal acceptance;
- retries using the existing configured retry scale;
- re-evaluates the model certificate after every refinement;
- does not assume that a smaller dt must reduce Binf;
- commits only after all applicable acceptance gates pass.

This is the production realization of the nonmonotonicity-robust C-SAFE pattern
qualified by ELASTIC57/57B.

## Production source scope

The scientific/runtime production delta is confined to:

`src/runtime/mod_fmr_serialized_reference_backend.f90`.

The runtime imports the already admitted stateless
`mod_fmr_mode7_temporal_head_envelope` adapter and applies that normalization
for bottom mode 7 only.

Modes 2 and 5 retain their prior native Binf/budget semantics.

No change is made to:
- Richards equations;
- HeadCalc;
- constitutive relations;
- nonlinear convergence criteria;
- retry scale;
- mass tolerances;
- ELAS parameters;
- mode-7 indicator operator;
- frozen alpha.

Admission also carries bounded test/build dependency-closure updates required
because the serialized backend now imports an already admitted module.

## Final owner qualification

The final extended owner gate on admission head `5bcb1119...` passed:

- ELASTIC65 mode-7 normalization: PASS;
- refine/recheck transaction behavior: PASS;
- missing budget fail closed: PASS;
- hard-mass independence: PASS;
- mode-2 preservation: PASS;
- mode-5 preservation: PASS;
- swkimpl=1 fail closed: PASS;
- O0/O2 semantic identity: PASS;
- production source scope: PASS;
- F-KT22 serialized production compile closure: PASS;
- F-KT22 serialized production runtime closure: PASS;
- EB-I25 same-harness no-regression reconciliation: PASS;
- P2E05 same-harness no-regression reconciliation: PASS.

## Pre-existing current-canonical preservation failures

Two broad preservation gates remained red during PR admission, but both were
replayed against the exact current canonical baseline and the ELASTIC65
candidate with one identical harness.

### EB-I25

Canonical:
- exit status: 1.

ELASTIC65 candidate:
- exit status: 1.

Both fail at the same existing assertion:

`external full-half outflow fixture rejected before commit`.

Differential result:

`F_PE_ELASTIC65_EBI25_NO_REGRESSION=PASS`.

Classification:

`PREEXISTING_CURRENT_CANONICAL_FAILURE`.

ELASTIC65 does not qualify or repair EB-I25 itself.

### P2E05 moving preservation

Canonical:
- exit status: 1.

ELASTIC65 candidate:
- exit status: 1.

Both fail at the same frozen dependency assertion:

`admitted dependency drift from a0fd7822...:
src/runtime/mod_a23bu_worker_execution_context.f90`.

ELASTIC65 does not modify that file.

Differential result:

`F_PE_ELASTIC65_P2E05_NO_REGRESSION=PASS`.

Classification:

`PREEXISTING_CURRENT_CANONICAL_FAILURE`.

ELASTIC65 does not update or weaken the frozen P2E05 authority.

These failures remain routed to their owning preservation lines and must not be
misclassified as ELASTIC65 regressions.

## Admission decision

Classification:

`PRODUCTION_ADMITTED_MODE7_CSAFE_CERTIFICATE_BINDING`.

Admitted bounded scope:

`mode7 + swkimpl=0 + admitted temporal history
 + explicit caller-owned positive head budget
 -> conservative ELASTIC61 normalized certificate
 -> existing mass-first refine/recheck transaction path`.

Still outside:
- any default physical head budget;
- a complete F-CI14 eight-metric numeric profile;
- default-on mode-7 temporal control;
- swkimpl=1;
- optional-process combinations outside the admitted indicator envelope;
- any relaxation of hard mass acceptance.

## Relation to the original ELASTIC56 question

The localized Binf nonmonotonicity discovered in ELASTIC55/56 is now closed
through the production binding chain:

- ELASTIC56 localized the nonmonotonicity and preserved the global envelope;
- ELASTIC57/57B qualified a forward-only controller that does not assume
  monotonic improvement;
- ELASTIC60 admitted the mode-7/swKimpl=0 defect indicator;
- ELASTIC61 admitted conservative Binf-to-head-error normalization with an
  explicit caller-owned budget;
- ELASTIC65 binds that normalization to the existing mass-first transaction
  retry/accept path.

No Binf monotonicity assumption is present in the admitted mode-7 controller
path.

## Closure

F-PE-ELASTIC65 is closed.

The remaining broader temporal-policy question is independent of this workunit:
production still has no default mode-7 physical head budget and F-CI14 still has
no complete eight-metric numeric temporal profile.

Those questions should be handled by their own calibration/application-policy
authority and must not reopen ELASTIC56/57/65 unless new evidence invalidates
the admitted dependency surface.
