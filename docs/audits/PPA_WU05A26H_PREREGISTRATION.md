# PPA-WU05-A26H preregistration — RFM wall-hydraulic history ownership

Date: 2026-10-01
Status: PREREGISTERED

Baseline: work/ppa-wu05-a26-rfm-backend-dispatch@a5c76081612ed43cdc8eb41364e091dd7b0cb9ec

## Question

Resolve the A26 blocker without introducing a new calibration parameter or changing the A22A/A22B wall law.

## Authority-derived hypothesis

A22A makes terminating-endpoint wall sorptivity event history: while endpoint contact remains wet, wall age advances and the event sorptivity is retained; when the endpoint empties, both reset.

Therefore endpoint sorptivity must not be recomputed every trial. The missing transition is only dry-to-wet seeding.

Preregistered rule:
- if accepted endpoint storage is positive, retain accepted wall age and sorptivity exactly;
- if accepted endpoint storage is zero and new routed input makes the endpoint wet, seed that endpoint's event sorptivity from the accepted matrix hydraulic view at its explicit mapped matrix node;
- the seed is derived by the already-qualified A25 node-sorptivity operator;
- candidate-only seeding is discarded on reject and becomes persistent only through the existing candidate commit path;
- if the endpoint empties during the candidate interval, A22A resets age and sorptivity exactly as already qualified.

For MB, A22B has no persistent MB storage/history state: MB input is resolved within the interval into wall exchange plus distinct deep receipt. Its wall sorptivity and conductivity are therefore derived from the accepted mapped MB wall node for each trial. No MB history default is introduced.

## Falsification

Stop if:
- this rule requires mutating accepted state before trial acceptance;
- retry from the same accepted origin changes the seed;
- a wet endpoint's stored sorptivity is overwritten by current matrix hydraulics;
- dry-to-wet seeding cannot be expressed without an arbitrary constant;
- MB requires persistent history not represented by admitted state.
