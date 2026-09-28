# F-PE-TIMEINT02 preregistration — BDF2 operator consistency

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b13fb7b903044a82687a21814bfaa1f7e7cfa833`

Parent:

F-PE-TIMEINT01 — current Reference SWKIMPL=0 is a first-order semi-implicit one-step method; BDF2 selected as successor candidate.

## Purpose

Determine which operator treatment is required for a genuine second-order BDF2 Richards path.

This is test-only research. No production source or solver contract changes.

## Four frozen variants

A. `BE_KLAG`
- current first-order storage derivative;
- SWKIMPL=0 lagged conductivity.

B. `BE_KIMPL`
- current first-order storage derivative;
- endpoint-updated conductivity with SWKIMPL=1.

C. `BDF2_KLAG`
- constant-step BDF2 storage derivative after one BE bootstrap step;
- SWKIMPL=0 lagged conductivity.

D. `BDF2_KIMPL`
- constant-step BDF2 storage derivative after one BE bootstrap step;
- endpoint-updated conductivity with SWKIMPL=1.

The BDF2 storage derivative is:

`(1.5 theta^{n+1} - 2 theta^n + 0.5 theta^{n-1}) / dt`.

Its storage Jacobian coefficient is:

`1.5 C(h^{n+1}) / dt`.

No other physical equation is changed.

## Test envelope

Use explicit fixed-flux top boundary and prescribed zero bottom flux to isolate smooth temporal order from dynamic-top transitions.

Hydraulic archetypes:

- B01;
- O05.

Origins:

- h0=-100 cm.

Top infiltration rates:

- 2 cm/day;
- 4 cm/day.

Horizon:

`0.04 d`.

Fixed dt ladder:

- 0.010 d;
- 0.005 d;
- 0.0025 d;
- 0.00125 d.

BALTOL02 effective balance floor remains active.

No adaptive controller.

## Order calculation

For each variant/case use successive top-head endpoint differences.

Primary refined estimate:

`p = log2(|y_0.005-y_0.0025| / |y_0.0025-y_0.00125|)`.

Secondary quantities:

- bottom head;
- terminal storage.

Roundoff-dominated differences are excluded.

## Frozen mechanism expectations

- BE_KLAG should remain approximately first order.
- BE_KIMPL should remain approximately first order because Backward Euler is first order.
- BDF2_KLAG may remain order-limited by lagged conductivity.
- BDF2_KIMPL is the only variant expected to approach second order if endpoint operator consistency is sufficient.

## Advancement gate

A BDF2 variant is considered second-order-capable only if:

1. all planned smooth cases complete;
2. median refined top-head order >=1.6;
3. at least 3/4 individual refined top-head orders >=1.5;
4. no mass-ledger failure;
5. median deterministic work per step is not more than 1.5x the matching BE conductivity variant.

If only BDF2_KIMPL passes, TIMEINT02 establishes endpoint-operator consistency as necessary for the modern integrator.

If neither BDF2 variant passes, BDF2 is not advanced without a new attribution workunit.

## Scope boundary

This study does not qualify:

- dynamic-top SWKIMPL=1;
- production BDF2;
- variable-step BDF2;
- BDF2 error estimation;
- user-facing AUTO_REFERENCE.

