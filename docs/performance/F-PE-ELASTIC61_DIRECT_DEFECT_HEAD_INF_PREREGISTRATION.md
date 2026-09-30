# F-PE-ELASTIC61 — direct defect head-infinity candidate preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC60 — QUALIFIED_STATE_STRATIFIED_SCALAR_BUDGET_BRIDGE_FALSIFICATION`

Parent postimage:
`research/f-pe-elastic60-state-stratified-budget-bridge@1b4702efcc9f69ffccd27daeebc5df5a3774feac`

Canonical authority at start:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Question

Can the tridiagonal defect correction already computed inside the Reference
Richards temporal indicator provide a direct head-space temporal observable that
is both:

1. conservative relative to realized full-versus-two-half head error; and
2. compatible with the independently frozen P2E09 head-infinity envelope;

without empirical scalar rescaling?

## Candidate

The canonical defect indicator solves:

`A * delta = rhs`.

Canonical currently publishes:
- raw mass-weighted norm;
- defect mass-weighted norm;
- bounded mass norm;
- Binf = bounded_m_norm / sqrt(min_mass_weight).

ELASTIC61 introduces only a research observable:

`D_INF = max_i |delta_i|`.

Units:
cm pressure head.

No production source or result type is changed.

## Exact independent domain

Use the exact ELASTIC59 / P2E08 selected-domain bank:
- B01, B12, O01, O05, O14, O18;
- Se=0.65,0.85,0.98;
- DRYING, NOMINAL, WETTING;
- coarse dt=0.0064 day;
- two half steps=0.0032+0.0032 day;
- bottom mode 2;
- real stationary accepted history;
- same strict Reference validity and mass gates.

Independent P2E09 U_h_inf budgets remain frozen:
- Se=0.65: 0.002329984405367469 cm;
- Se=0.85: 0.024875926496918055 cm;
- Se=0.98: 1.0304935719866082 cm.

## Research implementation

Materialize a qualification-only copy of the canonical
`mod_reference_richards_temporal_indicator` that:
- preserves the canonical operator byte-for-byte in mathematical terms;
- returns the existing indicator result unchanged;
- additionally returns `D_INF=maxval(abs(delta))`.

The research-copy Binf must match production Binf for every selected case.

## Primary tests

For each of 54 cases:

A. realized-error conservatism:
`H_INF <= D_INF`.

B. independent-budget compatibility:
`D_INF <= P2E09_limit(Se)`.

C. production preservation:
research-copy Binf equals production Binf within exact binary64 identity.

## Secondary observations

Report:
- max/min D_INF/H_INF;
- max/min D_INF/P2E09_limit;
- by-Se maxima;
- whether D_INF is closer to realized H_INF than canonical Binf.

No alpha is fitted.

## Gates

A1. All 54 exact current cases remain valid.

A2. Real stationary history remains exact.

A3. Production and research-copy Binf match exactly.

A4. D_INF finite and nonnegative in all 54 cases.

A5. O0/O2 semantic output identity.

A6. Zero src/** and reference/** changes.

## Decision

If all 54 satisfy both primary inequalities:
`QUALIFIED_DIRECT_DEFECT_HEAD_INF_BUDGET_BRIDGE_CANDIDATE`.

If any case violates realized-error conservatism:
`FALSIFIED_DIRECT_DEFECT_ERROR_BOUND`.

If realized-error conservatism holds but any case exceeds the P2E09 budget:
`FALSIFIED_DIRECT_DEFECT_BUDGET_COMPATIBILITY`.

No production temporal metric, F-CI14 numeric profile, mode-7 controller
integration or source admission is authorized by ELASTIC61.
