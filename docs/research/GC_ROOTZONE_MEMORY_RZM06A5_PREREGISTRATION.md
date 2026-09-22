# GC-RZM06A5 redistribution-timing H2 preregistration

Date: 2026-09-22  
Machine-readable authority: `503b943b72de6f5d3c5d447781cd4605b8334eb4`  
Production changes: none

## Question

Can two real-SWAP states with the same fixed interface head, the same endpoint time and the same integrated prescribed top forcing nevertheless retain a materially different vertical water distribution because the same forcing occurred at a different time?

This is a more direct H2 construction than another sign-reversal experiment.

## Forcing

The experiment reuses the strongest already-qualified baseline-admissible top-flux magnitude from RZM06A:

`|q_top| = 1e-4 cm d^-1`

with interval duration

`dt = 0.01 d`.

Both forcing directions are allowed as separate candidate families:

- `NEG_INTO_PROFILE = -1e-4 cm d^-1`;
- `POS_OUTWARD = +1e-4 cm d^-1`.

The interface head remains fixed at

`H* = -0.7149999706136307 m`.

## Candidate histories

For each frozen pulse count `N = 100, 50, 20, 10`, common final relaxation `R = 0, 50`, and forcing direction in the order NEG then POS, construct:

- EARLY: PULSE repeated N, ZERO repeated N, ZERO repeated R;
- LATE: ZERO repeated N, PULSE repeated N, ZERO repeated R.

Within every pair, H_c, endpoint time, pulse magnitude, pulse count and integrated top forcing are identical. Neither trajectory contains a forcing sign reversal.

Candidate enumeration is fixed before execution: pulse count outer loop, relaxation middle loop, direction inner loop.

## H2 endpoint gate

Only after both histories of one candidate are transactionally accepted are endpoint observables exposed.

The criteria remain unchanged:

- `|ΔW_profile| <= 1e-6`;
- `|ΔM1| >= 1e-4`.

The first fully admitted candidate satisfying both criteria is selected. E_c is unavailable to the selector.

## Response probe

Only the selected pair is replayed exactly and subjected to the same read-only forcing-free probe:

- `H_c = H*`;
- `q_top = 0`;
- duration `1e-4 d`;
- no commit.

H2 support requires exact replay, complete mass accounting and `|ΔE_c| > 1e-18` in native whole-window bottom outward exchange.

No production setting or H2 threshold is changed.
