# F-PE-ELASTIC60 — production admission candidate for mode-7 Richards defect indicator result

Date: 2026-09-30

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic60-mode7-indicator-admission`

Qualified postimage:
`030b0ca84b54bf3e75e3ed6bf298c482146ca637`

Canonical baseline:
`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

Workflow run:
`36692957387`

Job:
`109814173023`

Conclusion:
SUCCESS.

## Purpose

Admit production availability of the existing Reference Richards defect temporal
indicator for bottom mode 7 within the bounded `swkimpl=0` envelope already
qualified by ELASTIC53-59.

This workunit does not admit a temporal budget, controller or default-on policy.

## Production delta

Exactly one production file changes:

`src/solver/mod_reference_richards_temporal_indicator.f90`.

The boundary envelope changes from:

`bottom_mode in {2,5}`

to:

`bottom_mode in {2,5,7}`.

No defect-operator coefficient or stiffness expression changes.

The existing bottom-mode-5 Dirichlet stiffness remains guarded by:

`if (request%boundary%bottom_mode == 5) then`.

Mode 7 therefore uses the already qualified zero-added-bottom-stiffness operator
for the `swkimpl=0` envelope.

## Existing fail-closed boundaries preserved

Mode 7 remains unavailable when any existing indicator gate fails, including:

- `conductivity_implicit_mode /= 0` / `swkimpl=1`;
- unsupported conductivity-mean policy;
- unsupported top boundary;
- macropore-active envelope;
- unsupported constitutive/source-sink provider;
- non-converged candidate;
- unavailable/invalid previous right derivative.

No new fallback is introduced.

## Qualification

Current-head admission run:

`36692957387`

Job:

`109814173023`

Passed gates:

- `F_PE_ELASTIC60_A1_SOURCE_SCOPE=PASS`;
- `F_PE_ELASTIC60_A2_MODE7_ORACLE=PASS`;
- `F_PE_ELASTIC60_A4_PRODUCTION_BINDING=PASS`;
- `F_PE_ELASTIC60_A5_SWKIMPL1_FAIL_CLOSED=PASS`;
- `F_PE_ELASTIC60_A6_MODE2_MODE5_PRESERVATION=PASS`;
- `F_PE_ELASTIC60_A7_O0_O2=PASS`;
- `F_PE_ELASTIC60_A8_NO_BUDGET_BINDING=PASS`.

## Independent mode-7 oracle

The admission oracle uses:
- uniform unsaturated free-drainage equilibrium;
- fixed-flux top boundary;
- bottom mode 7;
- `swkimpl=0`;
- `qtop=-K(h)+perturbation`;
- independent zero-bottom-stiffness tridiagonal reconstruction.

The production indicator reproduces the independent:
- raw norm;
- defect norm;
- bounded norm;
- `Binf`.

Stationary free drainage produces zero temporal indicator.

## Production binding

The oracle invokes the production
`reference_richards_legacy_solver_t%evaluate_temporal_indicator`
binding.

Qualified mode-7 requests return AVAILABLE.

A cloned mode-7 request with
`conductivity_implicit_mode=1`
returns UNAVAILABLE through the existing
`conductivity-policy-deferred` route.

Thus ELASTIC60 does not broaden the `swkimpl=1` envelope.

## Preservation

Mode-2 prescribed-qbot semantics were replayed through a materialized F-SI38
preservation test with only its now-obsolete "mode 7 is unsupported" probe moved
to still-unowned mode 8.

Mode-5 production indicator semantics and the one-extra-tridiagonal cost
contract were replayed through the existing F-SI25 production seam.

Both preservation routes pass at O0 and O2 with semantic identity.

## Research evidence inherited

The production patch is the same operator-envelope extension qualified
research-side by ELASTIC53.

Subsequent research evidence established:
- ELASTIC54: global conservative scaling candidate;
- ELASTIC55: 0/801 multi-profile envelope failures;
- ELASTIC56: localized Binf nonmonotonicity, global envelope preserved;
- ELASTIC57: nonmonotonicity-robust refinement pattern;
- ELASTIC58: multi-metric endpoint-error characterization;
- ELASTIC59: fail-closed external physical-budget normalization.

ELASTIC60 does not admit those separate policy layers. It only admits indicator
availability.

## Architecture / ownership

Preserved:
- solver versus execution-policy separation;
- hard mass gate ownership;
- transaction/rollback semantics;
- application-owned accuracy budgets;
- no silent numerical defaults;
- Full Richards Reference path.

No application accuracy contract or canonical numerical configuration is
modified.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE_MODE7_SWKIMPL0_DEFECT_INDICATOR`.

Admission scope:

`bottom_mode=7 AND swkimpl=0 AND existing indicator envelope`.

Still outside:
- `swkimpl=1`;
- a numeric temporal head budget;
- alpha normalization in production;
- C-SAFE production controller binding;
- default-on mode-7 temporal control;
- optional process combinations outside the existing indicator envelope.

Canonical admission may proceed as a separate integration action.
