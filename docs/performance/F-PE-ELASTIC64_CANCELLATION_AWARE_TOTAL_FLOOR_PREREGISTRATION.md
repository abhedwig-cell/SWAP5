# F-PE-ELASTIC64 — cancellation-aware total-balance floor preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC63 — QUALIFIED_NEGATIVE_SIMPLE_TOTAL_FLOOR_AGGREGATION_RESULT`

Parent postimage:
`research/f-pe-elastic63-total-floor-aggregation@0ee416f3ae931a85b7cfb3d9e107c21b8b5f465b`

Canonical authority:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Question

Can representation-scale total cancellation be handled without weakening the
existing strict local compartment balance gate?

## Frozen bank

Replay ELASTIC63 exactly:
- profiles 11060, 10260, 8016, 3030;
- same geometry/material/generated-Ss preparation;
- same states, forcing, regimes and dt ladder;
- same Reference solver settings;
- configured local and total balance tolerances remain 1e-12 cm/day.

No production solver tolerance is changed.

## Candidate H-SUM-LOCAL

Retain the current strict local criterion exactly:

`L = max_i |r_i| <= 1e-12 cm/day`.

For the total criterion define only for diagnostic candidate evaluation:

`F_sum = sum_i f_i`

with the P2E07 node-local representation floors

`f_i = 0.5*(spacing(theta_internal_i)+spacing(theta_base_i))*dz_i/dt`.

Candidate total floor:

`T_eff = max(1e-12, F_sum)`.

Candidate balance pass:

`L <= 1e-12 AND |sum_i r_i| <= T_eff`.

The local criterion is never replaced by `f_i` and is never relaxed.

## Existing retry ownership

H-SUM-LOCAL is only a balance-gate classifier.

It must not convert OTHER_RETRY or any non-balance solver failure into a
successful solve.

The study therefore reports:
- balance-pass classification;
- potential TOTAL_ONLY recovery;
- but preserves non-balance retry ownership.

## Frozen expectations

Because ELASTIC63 found:
- A_SUM covers 170/170 TOTAL_ONLY_STRICT;
- A_SUM also covers many LOCAL_ABOVE_STRICT when used alone;

the hybrid candidate is expected to retain the A_SUM total coverage while
blocking every LOCAL_ABOVE_STRICT state through the unchanged local gate.

This expectation is preregistered before ELASTIC64 replay.

## Gates

A1. Exact ELASTIC63 four-profile bank replay.

A2. O0/O2 semantic identity.

A3. STRICT_SUCCESS states remain candidate balance-pass.

A4. TOTAL_ONLY_STRICT candidate balance recovery is measured.

A5. LOCAL_ABOVE_STRICT candidate balance-pass must be exactly zero.

A6. OTHER_RETRY is never promoted to solver success by the research harness.

A7. ELASTIC62 six parent cases reproduce as candidate balance-pass.

A8. Zero `src/**` production changes.

## Decision

A positive result qualifies only a research candidate balance-gate rule.

It does not authorize:
- changing production total-balance tolerance;
- weakening local compartment balance;
- changing hard transaction mass acceptance;
- changing temporal acceptance.
