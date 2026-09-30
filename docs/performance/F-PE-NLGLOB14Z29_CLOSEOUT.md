# F-PE-NLGLOB14Z29 closeout — reduced physical moving-interface binding

Date: 2026-09-30

Final status:

`QUALIFIED_Z29_REDUCED_PHYSICAL_BINDING`

Qualification authority:

- workflow run `36731447222`;
- HEAD segment-B job `109948831768`;
- RUNOFF segment-B job `109948831533`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@a3af828f442da7665615b222a0d3a7e5e614ac53`

## Closure

Z29 closes positively as the first physical variable-dimension moving-interface binding.

Across all 70 frozen HEAD/RUNOFF event/control intervals:

- the reduced candidate is physically equivalent to the full candidate within the preregistered gates;
- retreat and reverse ownership directions match exactly;
- saturated-tail identity matches exactly;
- provider route matches;
- ledger and theta differences remain at roundoff;
- reduced dimensions n=12, 13 and 14 replace full n=16.

The deterministic numerical-Jacobian probe-work proxy is reduced to:

- 75% to 87.5% interval-by-interval;
- about 82–83% on average across the frozen windows.

## Strategic conclusion

The research question has changed.

The remaining uncertainty is no longer whether a reduced moving-interface solve can reproduce the full-reference candidate locally. Z29 establishes that it can for the qualified moving-interface windows.

The next question is whether that reduced candidate can safely become the trajectory-driving candidate over the long horizon, with the full-column route retained only as observer/reference.

That is the required step toward a working SWAP Heritage timestep manager.

## Direct successor

Open:

`F-PE-NLGLOB14Z30 — trajectory-driving adaptive manager A/B benchmark`.

The successor must:

- start from the exact same accepted origin as Z29;
- let the reduced variable-dimension manager drive the accepted trajectory;
- independently compute full-column reference candidates on the same intervals;
- preserve accepted-state authority and one-interface semantics;
- record cumulative h/theta divergence, mass, ownership sequence and provider route;
- report reduced algebra work and wall-clock timing;
- fail closed if reduced/full divergence leaves the preregistered physical envelope.

No anti-chatter mechanism should be introduced.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z29

BRANCH: `research/f-pe-nlglob14z29-reduced-physical-binding`

RESEARCH POSTIMAGE BEFORE CLOSEOUT: `6ae754d766e3f2f61eb7fe3f8420eadabde19640`

QUALIFICATION STATUS: `QUALIFIED_Z29_REDUCED_PHYSICAL_BINDING`

NEXT SAFE STEP: Z30 trajectory-driving adaptive-vs-full A/B benchmark.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
