# F-PE-ELASTIC60 — mode-7 transaction-core composition preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC59 — QUALIFIED_MODE7_REFINED_ORACLE_TEMPORAL_BUDGET_RESEARCH_CANDIDATE`

Parent result:
`research/f-pe-elastic59-refined-oracle-budget-calibration@2fd8bc8e4bf9ddff6f073ab2e143bf890caa8b34`

Canonical authority at start:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Purpose

Qualify the transaction-level composition of:

- bottom-mode-7 research defect indicator;
- frozen global scaling `alpha = 0.17320259355765216`;
- ELASTIC59 calibrated bound threshold
  `T_BOUND = 0.049428424452890203 cm`;
- C-SAFE refinement semantics;
- hard mass acceptance;
- rollback/retry;
- commit only after solver + mass + temporal certificate acceptance.

No production source is changed.

## Native indicator budget

The transaction model-certificate surface accepts a normalized model-owned
indicator.

ELASTIC60 therefore freezes the mathematically equivalent native Binf budget:

`B_NATIVE = T_BOUND / alpha = 0.2853792396384496 cm`.

For every successful physical trial:

`certificate = Binf / B_NATIVE`.

Acceptance requires:

`certificate <= 1`.

No recalibration occurs in ELASTIC60.

## Transaction authority

Use production `execute_reference_interval` with:

`TX_TEMPORAL_MODEL_CERTIFICATE`.

The production transaction core already owns:

1. solver rejection and rollback;
2. hard mass gate before temporal acceptance;
3. temporal-certificate rejection and rollback;
4. geometric retry scaling;
5. commit only after all gates pass.

ELASTIC60 does not reimplement those semantics.

## Research model seam

Because production `mod_reference_richards_temporal_indicator` still fails
closed for bottom mode 7, use a qualification-only transaction model that:

- uses the production Reference Richards solver;
- uses the ELASTIC53 research-only mode-7 indicator;
- carries previous-right-derivative history in transactional state;
- starts from zero previous derivative, consistent with ELASTIC53-59 isolated
  perturbation qualification;
- reports exact physical mass fluxes from the solver result;
- publishes the normalized certificate above.

This qualifies transaction-core composition only.

It does not admit the serialized production backend for bottom mode 7.

## Frozen physical bank

Use holdout profile `3030` from ELASTIC55/59 with its qualified:
- four-horizon geometry;
- Staringreeks retention materialization;
- generated Ss.

Cases:

States:
- `h0 = -20 cm`;
- `h0 = +10 cm`.

Perturbations:
- `delta = -0.035 cm/day`;
- `delta = +0.035 cm/day`.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

Total:
`2 * 2 * 3 = 12` transaction cases.

Requested interval:
`0.015625 day`.

Retry:
- scale 0.5;
- max retries 8.

## Independent first-pass oracle

For each case, independently evaluate the same frozen retry ladder from the
same initial state, always resetting previous derivative to zero for each
candidate attempt.

The oracle returns the first dt for which:
- solver converges;
- hard mass closes;
- mode-7 indicator is available;
- `Binf <= B_NATIVE`.

If no dt passes, oracle returns EXHAUSTED.

The transaction result must match this first-pass oracle.

## Gates

A1. All 12 cases execute under O0 and O2.

A2. O0/O2 transaction results are semantically identical.

A3. Transaction accepted/retry-exhausted classification matches the independent
first-pass oracle for every case.

A4. Accepted dt equals oracle first-passing dt exactly.

A5. Every accepted transaction has:
- one commit;
- complete hard mass accounting;
- accepted mass residual within 1e-12 cm;
- model-certificate acceptance source;
- normalized temporal indicator <= 1.

A6. Every rejected attempt increments rollback/retry accounting and cannot leak
physical state or derivative history into the next attempt.

A7. Accepted committed physical state is bit-identical to an independent direct
solve at the oracle accepted dt from the original checkpoint.

A8. A deliberate mass-defect discriminator is rejected before temporal commit
and leaves the initial committed state unchanged.

A9. Zero `src/**` production changes.

## Decision

A green ELASTIC60 qualifies the transaction-core composition only.

It does not authorize:
- production mode-7 indicator admission;
- serialized-backend mode-7 admission;
- canonical F-CI14 numeric profile;
- production default changes.

The next step after a green result is production-shaped serialized-backend
integration/qualification.
