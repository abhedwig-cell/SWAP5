# F-PE-BASE01 P2 result — temporal-indicator demand specialization

Date: 2026-09-27

Status: `REJECT_NO_COMPOSED_RUNTIME_GAIN`

PR:
`#660 — F-PE-BASE01: base q/state Richards solve decomposition`

Authority:
- branch head exercised: `a30a77d6c72de196450ad53332578e6e4f86362a`;
- workflow run: `36306432670`;
- job: `p2-temporal-specialization`;
- frozen q-only LIVE01 head population.

## Candidate

The candidate replaced two full constitutive evaluations inside the Reference temporal indicator with demand-specialized calls:

- base state: conductivity only;
- candidate state: water content + capacity.

No constitutive formula, temporal-defect equation, acceptance rule, c=0.65 coefficient, floor, BALTOL02 setting, retry scale, nonlinear tolerance, tangent mathematics or MODFLOW behavior was changed.

## Semantic result

The candidate preserves the frozen replay semantics:

- maximum absolute q difference: 0;
- transaction/retry trajectory unchanged;
- no new solver rejection;
- accepted/rejected temporal decisions unchanged.

Thus the candidate is semantically acceptable as a research transformation.

## Runtime result

Aggregate paired result:

- current temporal-indicator time: `185303 ns`;
- specialized temporal-indicator time: `162483 ns`;
- temporal ratio: `0.876850348`;
- temporal gain: `12.3149652%`.

Serialized backend:

- current: `777418 ns`;
- specialized: `772726 ns`;
- ratio: `0.993964637`;
- gain: `0.6035363%`.

Total q/state trial:

- current: `2518428 ns`;
- specialized: `2533720 ns`;
- ratio: `1.006072042`;
- change: approximately `0.607%` slower.

## Independent current-head replay

The same candidate was repeated on later current head `c5f1881d3d95695993ab6420e232adb32c9df60b`.

Workflow run:
`36306634228`.

Observed:

- temporal-indicator current: `185075 ns`;
- specialized: `165611 ns`;
- temporal gain: `10.5168175%`;
- backend gain: `3.8810832%`;
- total q/state trial gain: `2.6035740%`;
- maximum absolute q difference: `0`;
- discrete retry/nonlinear trajectory unchanged.

This second measurement changes the small composed timing estimate but not the preregistered decision: the temporal-indicator gain again remains below the required 15%.

The two independent observations therefore give temporal-service gains of about 10.5% and 12.3%. Neither reaches the frozen local gate.

## Gate disposition

Preregistered advancement gates:

1. temporal-indicator gain >=15%;
2. serialized-backend gain >=3%.

Observed:

- temporal gain: 12.31%;
- backend gain: 0.60%.

In the first authority run both performance gates fail. In the independent replay the backend gate passes, but the temporal-indicator gate still fails.

The composed timing is small and variable across runs, ranging from about 0.6% slower to about 2.6% faster at total q/state trial level. That variability is itself evidence against promoting this local specialization as a robust production performance mechanism.

## Decision

`REJECT_NO_COMPOSED_RUNTIME_GAIN`

Do not:

- lower the frozen gates;
- production-admit this specialization;
- claim the roughly 10.5-12.3% temporal micro-gain as a solver/application speedup;
- continue tuning the same demand split inside BASE01.

The semantic identity result is retained as evidence, but this candidate is not a worthwhile performance mechanism on the measured live workload.
