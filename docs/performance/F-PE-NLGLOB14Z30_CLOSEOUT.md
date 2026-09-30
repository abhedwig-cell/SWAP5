# F-PE-NLGLOB14Z30 closeout — trajectory-driving adaptive manager A/B

Date: 2026-09-30

Final status:

`DRIVING_ADAPTIVE_DIVERGENCE`

Qualification authority:

- workflow run `36739588440`;
- HEAD segment-B job `109974727012`;
- RUNOFF segment-B job `109974727001`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@38b78b3415cee0563eb19efa68b73a6082b3c899`

## Closure

Z30 closes negatively on one preregistered long-horizon gate:

the cumulative adaptive/full mass difference exceeds `5e-7 cm` after more than 2.1 million independently driven intervals.

No instantaneous comparison gate fails first.

No ownership-sequence divergence occurs.

No reconstruction or nonlinear-solve failure occurs.

## What survives the negative result

The adaptive manager remains highly credible:

- independent trajectory driving works for >2.1 million intervals;
- moving-interface event sequence remains identical through stop;
- h/theta/top-flux differences remain within frozen instantaneous gates;
- per-interval ledgers remain small;
- active dimension is predominantly n=12;
- deterministic solver work is reduced by about 24%.

The negative result therefore localizes the remaining problem to long-horizon cumulative drift rather than the moving-interface mechanism itself.

## Direct successor

Open:

`F-PE-NLGLOB14Z31 — adaptive cumulative-drift attribution`.

The successor must keep Z30 physics and tolerances frozen and attribute the cumulative mass-difference growth by:

1. sign and monotonicity;
2. ownership regime;
3. event versus stable intervals;
4. per-step ledger bias distribution;
5. cumulative growth rate before and after the first chatter family.

No Z30 gate may be relaxed retroactively.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z30

BRANCH: `research/f-pe-nlglob14z30-driving-manager-ab`

RESEARCH POSTIMAGE BEFORE CLOSEOUT: `9e8710591110018e7ed86c391fee950cb2f0a311`

QUALIFICATION STATUS: `DRIVING_ADAPTIVE_DIVERGENCE`

NEXT SAFE STEP: Z31 drift attribution from the unchanged independent A/B trajectories.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
