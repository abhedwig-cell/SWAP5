# F-PE-NLGLOB14Z40 closeout — real reduced Heritage solve-service binding

Date: 2026-09-30

Final status:

`QUALIFIED_Z40_REAL_REDUCED_RICHARDS_PHYSICAL_ONLY`

Qualification authority:

- workflow run `36773430433`;
- job `110085279075`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z40 closes positively on the central implementation question:

the real Heritage/reference HeadCalc service can run at reduced active dimension and reproduce the full candidate on the compact physical holdout.

No alternate nonlinear solver stack is required.

The focused 16-node timing is modestly favorable on average:

- geometric-mean reduced/full ratio ~0.974;
- strongest frozen case ~0.958;
- one B12 case ~1.003.

This does not meet the frozen <0.95 gain criterion.

## Strategic conclusion

The manager architecture has crossed from research surrogate to real solver-service binding.

Further progress should now characterize scaling, not reopen physics.

The likely reason the measured gain is small is that the frozen profile has only 16 nodes and removes only 3–4 nodes from the nonlinear solve.

## Direct successor

Open:

`F-PE-NLGLOB14Z41 — real reduced HeadCalc active-dimension/profile-size scaling`.

Z41 should:

- reuse the exact Z40 real reduced solver path;
- vary full profile size and active fraction in a small matrix;
- retain physical equivalence checks;
- measure solve-service timing;
- determine when reduced HeadCalc crosses a practically meaningful speedup threshold.

No long trajectory is needed.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z40

BRANCH: `research/f-pe-nlglob14z40-real-reduced-richards-ab`

RESULT POSTIMAGE BEFORE CLOSEOUT: `e7e783f03c07aa1198d708af3ca303a7ff3d9f25`

QUALIFICATION STATUS: `QUALIFIED_Z40_REAL_REDUCED_RICHARDS_PHYSICAL_ONLY`

NEXT SAFE STEP: Z41 active-dimension/profile-size scaling.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
