# F-PE-ELASTIC59 — real accepted-history budget-bridge attribution preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC58 — QUALIFIED_DIRECT_INDEPENDENT_BUDGET_BRIDGE_FALSIFICATION`

Parent postimage:
`research/f-pe-elastic58-independent-budget-bridge@5ea44a61522dcce3e05151abd65b4e1de03ffc51`

Canonical authority at start:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Frozen authorities:
- ELASTIC54/55 alpha:
  `0.17320259355765216`;
- PUB-P2E09 U_h_inf envelopes:
  - Se=0.65: `0.002329984405367469 cm`;
  - Se=0.85: `0.024875926496918055 cm`;
  - Se=0.98: `1.0304935719866082 cm`.

## Question

Is the ELASTIC58 budget-bridge falsification primarily caused by the
`previous_right_derivative=0` bootstrap proxy, or does the direct bridge remain
too conservative when the defect indicator receives a real accepted-history
right derivative?

## Exact physical domain

Reuse exactly the P2E08/P2E09 domain:
- B01, B12, O01, O05, O14, O18;
- Se=0.65,0.85,0.98;
- DRYING, NOMINAL, WETTING;
- selected current coarse dt = 0.0064 day;
- current half dt = 0.0032 day;
- bottom mode 2;
- same Reference solver and hard validity gates.

## Accepted-history construction

Before the current P2E08 forcing is applied, construct one previous Reference
interval of duration:

`history_dt = 0.0064 day`.

The previous interval starts from the exact P2E08 initial state and uses a
stationary unit-gradient prescribed-flux forcing:

`q_history_top = -K(h0)`

`q_history_bottom = -K(h0)`.

No sources/sinks.

The history solve must:
- converge;
- satisfy the same hard Reference mass/rate validity gates;
- preserve the initial state to a preregistered roundoff-scale gate:
  - max |delta h| <= 1e-10 cm;
  - max |delta theta| <= 1e-12.

If any of the 18 unique material/Se history states fails this stationary-history
gate, ELASTIC59 is blocked and the bootstrap attribution is not made.

## Previous derivative

For an accepted history interval:

`d_prev = (h_history_end - h_history_start) / history_dt`.

The current P2E08 coarse solve starts from the accepted history endpoint.

This produces a real accepted-history derivative and a transaction-shaped
current origin.

## Paired indicator comparison

For every one of the 54 current coarse solves at dt=0.0064, evaluate two
diagnostic indicator calls without mutating the solve:

1. ZERO:
   `previous_right_derivative = 0`.

2. HISTORY:
   `previous_right_derivative = d_prev`.

Record:
- Binf_zero;
- Binf_history;
- history derivative infinity norm;
- ratio Binf_history/Binf_zero;
- scaled budget ratio for both:
  `alpha*Binf/P2E09_limit(Se)`.

Then execute the two current half steps exactly as P2E08 and recompute U_h_inf.

## Hypotheses

H1. Stationary history is accepted and preserves the exact initial state to the
frozen roundoff-scale gate.

H2. If the history derivative is effectively zero, HISTORY and ZERO Binf should
be near-identical and the ELASTIC58 bridge falsification should persist.

H3. If HISTORY materially lowers the bridge failure count or worst budget ratio,
bootstrap/history initialization contributes materially to ELASTIC58.

No post-hoc threshold for "materially" is used for qualification; report exact
counts and ratios.

## Gates

A1. All 18 unique material/Se stationary histories pass the history validity
and preservation gates.

A2. All 54 current P2E08 cases remain valid.

A3. ZERO and HISTORY mode-2 indicators are AVAILABLE for all 54 coarse solves.

A4. Recomputed realized U_h_inf remains within P2E09 envelope for all 54 cases.

A5. Frozen alpha and P2E09 limits are unchanged.

A6. O0/O2 semantic output identity.

A7. Zero src/** and reference/** changes.

## Decision

If HISTORY materially changes the bridge behavior, classify:
`QUALIFIED_HISTORY_SENSITIVE_BUDGET_BRIDGE_ATTRIBUTION`.

If HISTORY is effectively identical to ZERO and the bridge remains falsified,
classify:
`QUALIFIED_ALPHA_DOMAIN_TRANSFER_AS_DOMINANT_BRIDGE_LIMITATION`.

No production history initialization, F-CI14 numeric profile, or controller
admission is authorized by ELASTIC59.
