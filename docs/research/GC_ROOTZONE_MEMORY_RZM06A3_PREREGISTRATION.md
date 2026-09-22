# GC-RZM06A3 micro-stepped H2 state-pair construction preregistration

Date: 2026-09-22  
Parent state: `GC-RZM06A2` qualified as construction-inadmissible  
Machine-readable authority: `c41b702dd2a87b6c94a482f0d384454b745a0f44`  
Production changes: none

## Objective

RZM06A3 keeps the H2 hypothesis and its thresholds unchanged. It changes only how candidate real-SWAP states are constructed.

RZM06A2 showed that direct head pulses lasting 0.02 to 0.10 d are outside the current serialized-reference temporal-admissibility envelope. RZM06A3 therefore separates two questions that must not be mixed:

1. which short H_c perturbations are transactionally admissible from the baseline;
2. whether longer histories assembled only from such admitted micro-intervals can create the required vertical-distribution separation.

No solver tolerance, retry budget, temporal budget or mass gate is changed.

## Stage 1: response-blind admissibility map

All trials start from a fresh baseline, use zero top forcing and are discarded.

The frozen head perturbations are:

`δH = 1e-4, 5e-5, 2e-5, 1e-5, 5e-6, 2e-6, 1e-6, 5e-7 m`.

The frozen durations are:

`1e-2, 5e-3, 2e-3, 1e-3, 5e-4, 2e-4, 1e-4 d`.

Both `H* + δH` and `H* - δH` are tested, with

`H* = -0.7149999706136307 m`.

The Stage 1 selector receives only status, retry, temporal, mass and no-mutation evidence. It does not receive endpoint water observables or interface-response quantities.

Among grid points admitted for both signs, the selected microstep maximizes `δH × duration`. Ties are resolved by larger `δH`, then longer duration.

If no two-sided point is admitted, RZM06A3 closes as `NO_ADMISSIBLE_MICROSTEP`.

## Stage 2: micro-stepped state construction

Using only the selected Stage 1 microstep, two opposite-order histories are built:

- PLUS repeated N, then MINUS repeated N, then BASE repeated R;
- MINUS repeated N, then PLUS repeated N, then BASE repeated R.

PLUS means `H* + δH`, MINUS means `H* - δH`, BASE means `H*`. Top forcing remains exactly zero.

The frozen repeat-count order is:

`N = 200, 100, 50, 20, 10`.

The frozen BASE-relaxation order is:

`R = 1, 5, 20`.

Configurations are inspected in that order. No special transition treatment is allowed. If the first interval after a head switch is rejected, that trajectory is rejected and retained as evidence.

For each configuration only the two opposite-order endpoints are compared. They have identical committed time by construction. The first configuration satisfying both unchanged H2 criteria is selected:

- `|ΔW_profile| <= 1e-6`;
- `|ΔM1| >= 1e-4`.

Endpoint selection cannot access E_c.

## H2 probe

Only after endpoint-pair selection are both complete histories replayed from fresh initialization and subjected to the identical read-only probe:

- `H_c = H*`;
- top forcing = 0;
- duration = `1e-4 d`;
- commit = false.

The selected origins and probes must replay exactly, be whole-window valid and mass-complete, and leave committed state unchanged.

H2 is supported only if

`|ΔE_c| > 1e-18`

in the native accepted whole-window exchange quantity.

If no endpoint pair satisfies the unchanged water and M1 criteria, H2 remains `NO_MATCH` and no E_c probe is opened.

## Authority boundary

This is research-only state construction around the F-GC44 serialized-reference carrier. It does not modify production SWAP physics, the production groundwater coupling, canonical APIs, the one-head physical interface contract, or RZM06B/H5.
