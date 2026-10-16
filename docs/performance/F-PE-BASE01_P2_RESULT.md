# F-PE-BASE01 P2 result — temporal-indicator demand specialization

Date: 2026-09-27

Status: `REJECT_NO_COMPOSED_RUNTIME_GAIN`

PR:
`#660 — F-PE-BASE01: base q/state Richards solve decomposition`

Current-head authority:
- branch head exercised: `c5f1881d3d95695993ab6420e232adb32c9df60b`;
- workflow run: `36306634228`;
- job: `p2-temporal-specialization`;
- frozen q-only LIVE01 head population.

## Candidate

The candidate replaces two full constitutive evaluations inside the Reference temporal indicator with demand-specialized calls:

- base state: conductivity only;
- candidate state: water content + capacity.

No constitutive formula, temporal-defect equation, acceptance rule, c=0.65 coefficient, floor, BALTOL02 setting, retry scale, nonlinear tolerance, tangent mathematics or MODFLOW behavior is changed.

## Semantic result

The candidate preserves the frozen replay semantics:

- maximum absolute q difference: `0`;
- transaction/retry trajectory unchanged;
- no new solver rejection;
- accepted/rejected temporal decisions unchanged.

Thus the candidate is semantically acceptable as a research transformation.

## Runtime result

Aggregate paired result:

- current temporal-indicator time: `185,075 ns`;
- specialized temporal-indicator time: `165,611 ns`;
- temporal ratio: `0.894831825`;
- temporal gain: `10.5168%`.

Serialized backend:

- current: `858,987 ns`;
- specialized: `825,649 ns`;
- ratio: `0.961189168`;
- gain: `3.8811%`.

Total q/state trial:

- current: `2,721,605 ns`;
- specialized: `2,650,746 ns`;
- ratio: `0.973964260`;
- gain: `2.6036%`.

## Gate disposition

Preregistered advancement gates require both:

1. temporal-indicator gain >=15%;
2. serialized-backend gain >=3%.

Observed:

- temporal gain: `10.52%`, FAIL;
- backend gain: `3.88%`, PASS.

Because both gates were preregistered as jointly required, the candidate does not qualify.

The total q/state trial is faster in this current-head run, but that does not override the failed temporal-component gate.

## Decision

`REJECT_NO_COMPOSED_RUNTIME_GAIN`

Do not:

- lower or reinterpret the frozen gates after observing the result;
- production-admit this specialization from BASE01;
- treat the 2.60% trial gain as sufficient evidence for admission;
- continue tuning the same demand split inside BASE01.

The semantic identity and positive backend/trial timing evidence are retained for future work, but this exact candidate fails its preregistered qualification rule.
