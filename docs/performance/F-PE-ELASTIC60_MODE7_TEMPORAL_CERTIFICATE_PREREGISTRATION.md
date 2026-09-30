# F-PE-ELASTIC60 — mode-7 temporal-certificate production admission preregistration

Date: 2026-09-30

Status: PREREGISTERED_PRODUCTION_ADMISSION_CANDIDATE

Canonical base:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authorities:
- F-PE-ELASTIC53: mode-7 defect-indicator operator candidate;
- F-PE-ELASTIC54/55: frozen conservative realized-error scaling;
- F-PE-ELASTIC57: nonmonotonicity-robust C-SAFE controller pattern;
- F-PE-ELASTIC58/59: 1.0-cm realized-head research budget candidate and expanded holdout.

Frozen scaling:
`alpha = 0.17320259355765216`.

Frozen realized-head candidate:
`H_budget = 1.0 cm`.

Equivalent runtime defect-bound budget:
`Binf_budget = H_budget / alpha = 5.773585599727987 cm`.

## Purpose

Admit bottom mode 7 to the existing production Reference Richards temporal
indicator envelope for the already-supported runtime/model-certificate path.

Do not add a second controller.

Do not add a new transaction mode.

Do not add a production default head budget.

## Production source scope

Exactly one production source file may change:

`src/solver/mod_reference_richards_temporal_indicator.f90`.

Permitted source change:
- extend the boundary-envelope gate from bottom modes 2/5 to 2/5/7.

No other operator term may change.

In particular:
- mode 5 retains its Dirichlet bottom stiffness;
- mode 2 retains zero bottom stiffness;
- mode 7 under the already-required `conductivity_implicit_mode=0` also
  contributes zero added bottom stiffness;
- unsupported modes remain fail closed.

## Existing runtime composition

Canonical already provides:
- Reference solver -> temporal indicator callback;
- accepted temporal-history state;
- explicit `model_temporal_indicator_budget`;
- normalization `Binf / budget`;
- model-certificate transaction acceptance at normalized indicator <= 1;
- rollback/retry with retry scale;
- hard mass acceptance before temporal acceptance.

ELASTIC60 composes these existing capabilities.

## Qualification

A1. Independent mode-7 operator oracle reproduces the production indicator
exactly for the declared `swkimpl=0` envelope.

A2. Existing F-SI38 mode-2 and mode-5 operator semantics are unchanged.

A3. A production-shaped serialized mode-7 transaction with elastic storage,
seeded accepted temporal history and requested interval `0.015625 day` uses
the frozen runtime Binf budget `5.773585599727987 cm`.

A4. The case is constructed so the larger attempts exceed the candidate budget
and a smaller retry can satisfy it. Qualification records:
- temporal retries;
- accepted dt;
- normalized indicator;
- hard mass residual;
- one extra tridiagonal solve per evaluated certificate;
- zero extra full nonlinear trajectory for the certificate.

A5. Rejected attempts do not commit physical state.

A6. Invalid/missing budget remains fail closed.

A7. Unsupported nearby bottom modes remain fail closed.

A8. O0/O2 semantic identity.

A9. Production source scope is exactly the one permitted file.

## Architecture invariants

Affected:
- transactional time-step acceptance;
- hard mass conservation;
- solver/execution-policy separation;
- Reference production availability;
- runtime diagnostics.

Required preservation:
- mass gate remains independent and hard;
- rejected trials never mutate committed authority;
- production Full Richards remains available;
- no physical equation or ELAS constitutive relation changes;
- no application accuracy default is introduced.

## Admission boundary

A green ELASTIC60 qualifies only:
- production mode-7 defect-certificate availability under the declared
  `swkimpl=0`, fixed-flux, no-macropore envelope;
- production-shaped use of an explicitly supplied Binf budget corresponding to
  the research 1-cm realized-head candidate.

It does not:
- set a production default budget;
- complete the full eight-metric F-CI14 endpoint policy;
- admit swkimpl=1;
- admit dynamic-top/macropore/deferred envelopes;
- change hard mass tolerance.
