# F-PE-ELASTIC61 — direct defect head-infinity candidate result

Date: 2026-09-30

Status: QUALIFIED_NEGATIVE_RESEARCH_RESULT

Branch:
`research/f-pe-elastic61-direct-defect-head-inf`

Qualified postimage:
`3fc5aace66af51eb8e7cf85b686d6bd959b33d86`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36701147987`

Job:
`109840625409`

Conclusion:
SUCCESS.

## Question

Can the direct infinity norm of the tridiagonal defect correction

`D_INF = max_i |delta_i|`

serve directly as a head-space temporal quantity that is both:

1. conservative relative to realized full-versus-two-half head error; and
2. compatible with the independently frozen P2E09 head-infinity envelope?

## Research implementation

A qualification-only copy of the canonical Reference Richards temporal
indicator was materialized.

The canonical operator was preserved.

The research copy returned one additional scalar:

`D_INF=maxval(abs(delta))`.

The ordinary indicator result, including canonical `Binf`, had to remain
bit-identical to production.

That preservation gate passed for all selected cases.

No production result type or source file changed.

## Exact independent domain

The exact P2E08/P2E09 selected domain was reused:

- materials: B01, B12, O01, O05, O14, O18;
- Se = 0.65, 0.85, 0.98;
- forcing = DRYING, NOMINAL, WETTING;
- coarse dt = 0.0064 day;
- two half steps = 0.0032 + 0.0032 day;
- bottom mode 2;
- real stationary accepted history;
- strict Reference validity and mass gates.

All 54 cases remained valid.

## Primary result: realized-error conservatism

`D_INF` bounded the directly observed full-versus-two-half head discrepancy in
all 54 cases.

Failures:

`0 / 54`.

Maximum:

`H_INF / D_INF = 0.7158165673010196`.

Minimum:

`H_INF / D_INF = 2.4850e-5`.

Therefore the direct defect correction is materially closer to realized
head-space error than the canonical mass-norm Binf while remaining conservative
on the complete exact test bank.

This is a positive structural result.

## Relation to canonical Binf

Across the 54 cases:

`Binf / D_INF`

ranged from approximately:

- minimum: `1.40437`;
- maximum: `3.32774`.

The min-mass-weight conversion therefore adds substantial conservatism beyond
the already conservative direct defect correction.

## Independent P2E09 budget compatibility

Despite improved sharpness, D_INF is still much larger than the independently
frozen P2E09 U_h_inf envelopes in most cases.

Budget failures:

`43 / 54`.

Maximum:

`D_INF / P2E09_limit = 54.1433919865642`.

By effective saturation:

### Se = 0.65

- maximum `H_INF/D_INF = 0.0184695`;
- maximum `D_INF/T = 54.1434`.

The direct defect is extremely conservative relative to actual coarse-versus-
refined disagreement in dry states.

### Se = 0.85

- maximum `H_INF/D_INF = 0.0576238`;
- maximum `D_INF/T = 17.3539`.

### Se = 0.98

- maximum `H_INF/D_INF = 0.715817`;
- maximum `D_INF/T = 2.02043`.

Near saturation, the direct defect correction becomes much closer to realized
self-disagreement, but is still not universally inside the P2E09 envelope.

## Interpretation

ELASTIC61 separates two issues that were mixed in the canonical Binf:

1. the min-mass-weight conversion makes the canonical bound additionally
   conservative;
2. even the underlying direct defect correction is not numerically equivalent
   to P2E09 coarse-versus-two-half self-disagreement.

The first issue is real but not the whole budget-bridge problem.

The second issue is dominant in dry and moderately wet states.

This is consistent with the physical meaning of the quantities:

- D_INF is a local defect-based trajectory correction associated with the
  current derivative change;
- P2E09 thresholds are empirical Reference self-disagreement envelopes at one
  specific coarse-versus-two-half schedule.

They are not the same estimator and should not be forced into equivalence by
scalar rescaling.

## Hypothesis outcome

Direct defect correction is a conservative realized-error bound on the tested
bank:
SUPPORTED, 54/54.

Direct defect correction is compatible with frozen P2E09 budgets:
FALSIFIED, 43/54 failures.

Canonical Binf adds additional conservatism relative to D_INF:
SUPPORTED.

## Decision

Classification:

`QUALIFIED_DIRECT_DEFECT_ERROR_BOUND_WITH_INDEPENDENT_BUDGET_INCOMPATIBILITY`.

No production temporal metric or F-CI14 numeric profile is admitted.

The result argues against further empirical scalar fitting of the defect
indicator to P2E09.

The next bounded question should instead address temporal-budget authority
itself:

- what independent application/physical accuracy criterion should define the
  F-CI14 endpoint limits;
- how that criterion should vary across dry, transitional and near-saturated
  states;
- and whether a defect indicator is used as a conservative controller signal
  rather than interpreted as the physical error budget itself.

P2E09 remains valid as its own publication Reference-calibration envelope, but
ELASTIC61 does not support promoting it directly to a generic per-step SWAP
temporal tolerance.
