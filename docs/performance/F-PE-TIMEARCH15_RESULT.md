# F-PE-TIMEARCH15 result — flux-regime AUTO with conservative fallback

Date: 2026-09-28

Status: `CLOSED_NEAR_QUALIFIED_SINGLE_PONDING_FAILURE`

Canonical base:

`integration/f-ci-canonical@9ab4042ee7e70eb8fd9679e1e408250f61190266`

Evidence:

- Actions run: `36432865003`;
- discovery job: `108963227837`;
- conclusion: SUCCESS.

## Candidate architecture

AUTO_REFERENCE was active only while the accepted dynamic-top endpoint remained FLUX.

On transition out of FLUX:

- discard the full candidate;
- refine the same interval;
- enter LEGACY_SAFE fallback.

Already-head/runoff accepted states also enter LEGACY_SAFE.

Two frozen refinement depths were tested:

- REFINE4;
- REFINE8.

No normal operating DTMAX was used during AUTO_FLUX.

## Result

Both candidates produced the same aggregate outcome:

- P-C1 pass: 15/16;
- median deterministic work reduction on passing cases: about 34.3%;
- median transition refinements: 0;
- median fallback entries: 0;
- retry-fraction gate: PASS;
- wet/ponding preservation: FAIL due one case.

Regime median work reductions for passing cases:

- DRY: about 36.8%;
- TRANSITION: about 29.6%;
- MOIST: about 34.4%;
- WET: about 11.4%;
- POND: about -6.5%.

## Sole failure

`B01/POND` failed during AUTO recovery at the retry floor:

`auto failure fallback did not reduce`.

Thus the remaining failure is not transition-refinement depth:

- REFINE4 and REFINE8 behave identically;
- no extra transition refinement repairs it.

The failure is associated with entering/staying in AUTO too close to the wet surface regime, followed by the known non-monotone short-step recovery pathology.

## Interpretation

This is the strongest AUTO_REFERENCE result so far.

The state-machine architecture removes the broad wet-regime failures seen in earlier controllers while retaining most dry/transition performance headroom.

But the frozen advancement rule requires every WET/POND case to pass.

Therefore the candidate is not qualified.

## Decision

Do not advance TIMEARCH15 to validation.

The next valid successor may change AUTO eligibility, not refinement depth:

- AUTO allowed only when accepted state is FLUX and sufficiently far from the wet surface zone;
- crossing the eligibility guard enters LEGACY_SAFE fallback;
- no material/regime identifiers;
- no post-hoc relaxation of P-C1.

No production controller is enabled.
