# PPA-WU05-A27-ABC01-TR01 preregistration — first-dry-step production-C attribution

Date: 2026-10-02  
Status: PREREGISTERED_BEFORE_EXECUTION  
Parent: `2d8bb8bdfa7f6ccb245cf6143d7e1ca0bec9a16c`

## Trigger

ABC01 shows a repeated production-C pattern:

- R1/R2 fail on step 5, the first dry step after four wet intervals;
- R5 fails on step 4, the first dry step after three wet intervals;
- R7/R8 fail on step 9, the first dry step after eight wet intervals;
- all these failures are solver rejections, with zero admission, temporal or mass rejection;
- continuous R4/R6 complete.

A26 qualification did not test a wet-to-dry continuation with accepted endpoint storage. It tested an active wet event, replay, zero-RFM limit and refinement under continuously active 8 cm/day forcing.

## Fixed diagnostic case

Use the exact ABC01 C definition for:

- soil B01;
- geometry G1;
- regime R2;
- 10-cell 0–100 cm matrix;
- initial water table -150 cm;
- dt 0.01 day;
- rain 8 cm/day for four accepted steps;
- first dry step at t=0.04–0.05 day;
- sigma_B 0.65;
- f_MB 0.25;
- p 1.0;
- Z_AH 20 cm;
- Z_IC 60 cm;
- endpoint area fraction 0.0375;
- endpoint bottom depth 60 cm;
- endpoint contact thickness 20 cm;
- exchange length 20 cm;
- chi_wall 1;
- 64 sorptivity panels;
- MB wall node 10 and endpoint node 6.

No A27 pressure-aware research source is used.

## Sequence

1. Run production C through the serialized backend for the first four wet intervals and commit each accepted candidate.
2. Snapshot the accepted matrix/RFM state.
3. Reconstruct the first dry-step RFM live candidate from that exact accepted state with zero surface supply and `event_active=false`.
4. Record:
   - accepted endpoint storage;
   - accepted endpoint wall age and stored wall sorptivity;
   - endpoint matrix head/theta;
   - production endpoint release amount;
   - matrix source rate;
   - candidate endpoint storage.
5. Re-run the actual production C first dry step and record its transaction/solver diagnostics.
6. From the identical accepted matrix state, run direct Reference Richards at dt=0.01 with a frozen matrix-source scale ladder:
   - 1.0;
   - 0.5;
   - 0.25;
   - 0.125;
   - 0.0.
7. From the same accepted state, recompute the production dry-step release and direct Reference solve at:
   - 0.01;
   - 0.005;
   - 0.0025;
   - 0.00125;
   - 0.000625 day.

The dt ladder is diagnostic only. It does not advance accepted state between ladder points.

## Interpretation rules

- Do not change geometry, RFM parameters, tolerance or source mapping after seeing output.
- If source scale 0 succeeds while source scale 1 fails, that supports attribution to the explicit endpoint-to-matrix source rather than the zero-rain boundary alone.
- If a lower fixed source scale restores convergence, report the threshold bracket only. Do not use it as a production limiter.
- If recomputed release rate remains approximately invariant as dt shrinks and the exact-source solve continues to fail, ordinary retry halving cannot be expected to cure the failure.
- If zero-source also fails, reject the source-causality hypothesis and investigate the boundary/state transition instead.
- This diagnostic cannot authorize source capping, new coupling physics or admission.
