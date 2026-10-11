# F-PE-TIMEARCH17 result — blind validation of frozen GUARD_M5 AUTO_REFERENCE

Date: 2026-09-28

Status: `BLIND_VALIDATION_FAILED`

Canonical base:

`integration/f-ci-canonical@6dabb1d6e5baa351659363a1f938d596dddedc7c`

Evidence:

- Actions run: `36434695686`;
- blind-validation job: `108969451894`;
- conclusion: SUCCESS.

## Frozen candidate

Unchanged from TIMEARCH16:

- bootstrap dt = 0.005 d;
- normalized accepted-state target R = 0.40;
- no normal operating DTMAX in AUTO;
- AUTO only while accepted top mode is FLUX and accepted top head <= -5 cm;
- FLUX -> HEAD/runoff uses REFINE4;
- AUTO failure or loss of eligibility enters LEGACY_SAFE permanently;
- retry floor = 0.001 d;
- hard-event and retry ownership unchanged.

## Blind bank

20 previously unexposed material/forcing/state combinations:

- 4 hydraulic archetypes;
- 5 new regimes: DRY4, TRANS4, MOIST4, WET4, POND4.

## Aggregate result

- P-C1 pass: 17/20;
- required: >=19/20;
- median deterministic work reduction on passing cases: about 11.6%;
- required: >=20%;
- WET/POND preservation: FAIL;
- regime non-regression: FAIL;
- retry-fraction gate: PASS.

By regime:

- DRY: about 36.5% median work reduction, 4/4 pass;
- TRANSITION: about -5.7% median work reduction, 4/4 pass;
- MOIST: about 14.8% median work reduction, 4/4 pass;
- WET: about 4.1% median work reduction, 2/4 pass;
- POND: about 9.7% median work reduction, 3/4 pass.

## Candidate-specific failures

### B01/WET4

The candidate remains in AUTO and does not trigger fallback.

Observed:

- P-C1 failure reason: terminal head;
- max head difference: about 2.023 cm;
- limit: 2.0 cm;
- candidate work index: 252;
- Reference work index: 164.

This is not merely a borderline accuracy miss. The AUTO candidate also performs substantially more work.

### B12/WET4

The candidate eventually enters fallback, but too late to preserve trajectory.

Observed:

- P-C1 failure reason: terminal head;
- max head difference: about 6.113 cm;
- runoff difference: about 0.00989 cm;
- fallback entries: 1;
- candidate work index: 140;
- Reference work index: 136.

The accepted-state -5 cm eligibility guard does not prevent the relevant earlier path divergence.

## Common-domain failure

### O14/POND4

Both candidate and LEGACY_NUMERICS Reference fail at the solver floor.

Therefore this is not attributable specifically to GUARD_M5.

It is a Reference common-domain limitation of this validation point.

The frozen blind gate is not changed after exposure. Even excluding this common-domain point would not rescue GUARD_M5 because the two WET candidate-specific failures remain and median work reduction is below the frozen requirement.

## Decision

GUARD_M5 does not validate.

No production AUTO_REFERENCE activation is authorized.
