# PPA-WU05-A27-PROFILE01 preregistration — RFM trial-preparation constitutive overhead

Date: 2026-10-02  
Status: PREREGISTERED_BEFORE_EXECUTION

## Purpose

ABC01 qualifies bounded B/C hydrologic similarity after DEP01/DEP02/DEP03, but current RFM C takes about 4.3–5.3 times standard macropore B wall time in the preregistered CI timing sample while nonlinear iteration counts are nearly equal.

PROFILE01 attributes RFM trial-preparation cost without changing production physics or execution.

## Fixed setup

Use:
- B01 default-MvG hydraulics;
- ten 10-cm cells;
- hydrostatic matrix state at groundwater level -150 cm;
- RFM G1 geometry from ABC01;
- sigma_B 0.65, f_MB 0.25, p 1.0;
- Z_AH 20 cm, Z_IC 60 cm;
- endpoint node 6, MB wall node 10;
- endpoint area fraction 0.0375;
- exchange/contact length 20 cm;
- chi_wall 1;
- exactly 64 sorptivity panels;
- dt 0.01 day.

No production source file is modified by this experiment.

## Counting provider

Wrap the actual `b110_default_mvg_provider_t` in a transparent counting provider. It delegates exactly to production hydraulics and counts:
- vector `evaluate()` calls;
- vector `evaluate_demand()` calls;
- point-conductivity calls.

The wrapper may not alter returned values.

## Components

Measure and count:

1. `NODE_SORPTIVITY`: one 64-panel node sorptivity evaluation.
2. `SURFACE_WET`: production RFM surface activation under 8 cm/day.
3. `WALL_FRESH`: endpoint wall binding with empty accepted endpoint and positive new endpoint input.
4. `WALL_CACHED`: wall binding with existing endpoint water and stored endpoint sorptivity.
5. `FULL_WET_EMPTY`: complete live trial preparation from empty RFM state under 8 cm/day.
6. `FULL_WET_CACHED`: complete live preparation with accepted endpoint storage/history.
7. `FULL_DRY_CACHED`: complete live preparation with zero supply and accepted endpoint storage/history.

Use five timing batches of 2000 identical calls at O2. Timing is attribution evidence only; exact call counts are the stronger cross-machine evidence.

## Prospective hypotheses

H1. A 64-panel sorptivity integral requires 65 vector constitutive-demand evaluations.

H2. Fresh wall binding requires two sorptivity integrals, endpoint plus MB, while cached wall binding still requires the MB integral.

H3. The production composer does not consume the MB wall sorptivity or MB wall conductivity returned by `bind_rfm_wall_hydraulics_from_accepted`, because A26 leading MB is fast-through with no passage-wall exchange. If confirmed, the MB hydraulic calculation is an exact-preserving zero-waste candidate.

H4. Zero-supply activation is already defined independently of hydraulic threshold values by `evaluate_rfm_unponded_activation`, but the binding currently computes surface conductivity and sorptivity before reaching that zero-source branch. If FULL_DRY_CACHED retains the surface sorptivity call count, that is a second exact-preserving zero-waste candidate.

## Nonclaims

PROFILE01 does not change sorptivity panel count, RFM parameters, hydrologic results, transaction policy or coupling physics. It does not establish the realized end-to-end speedup from removing any identified waste. Any implementation of a zero-waste repair requires a separate same-postimage preservation and repeated ABC timing check.
