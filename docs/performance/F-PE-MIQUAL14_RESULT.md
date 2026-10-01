# F-PE-MIQUAL14 result — serialized manager scale-crossover benchmark

Date: 2026-10-01

Status:

`QUALIFIED_MIQUAL14_SERIALIZED_SCALE_CROSSOVER`

Qualification authority:

- workflow run: `36829433150`;
- job: `110262410092`;
- workflow conclusion: SUCCESS.

Canonical authority at final interpretation:

`integration/f-ci-canonical@190dad36a821f3a43f78f00fccf827c58cacedb6`

The canonical delta since preregistration is PPA-WU05A10 macropore rapid-drain work. It does not alter the moving-interface manager/basic-Richards dependency surface and is outside the no-macropore MIQUAL14 envelope.

## Aggregate result

The serialized manager shows a clear dimension-dependent crossover.

All three frozen geometries pass:

- 20,000/20,000 LEGACY commits;
- 20,000/20,000 MANAGER commits;
- zero retries;
- zero mass residual;
- 100% reduced manager route;
- zero fallback;
- zero bypass;
- exact final pressure-head identity;
- exact final water-content identity;
- exact storage identity;
- identical final saturated-tail identity.

Classification:

`QUALIFIED_MIQUAL14_SERIALIZED_SCALE_CROSSOVER`.

## N16 / tail 13

Deterministic work ratio:

`0.8125`

Median paired wall ratio:

`1.03973`

Geometric-mean wall ratio:

`1.04575`

Median CPU ratio:

`1.03963`

At N16 the fixed manager composition overhead remains larger than the solve saving.

## N32 / tail 25

Deterministic work ratio:

`0.78125`

Median paired wall ratio:

`0.99651`

Geometric-mean wall ratio:

`1.00213`

Median CPU ratio:

`0.99639`

N32 is effectively at break-even. Four of seven wall pairs are below 1.00, but the geometric mean remains slightly above 1 because one slow pair is retained per preregistration.

No claim of stable N32 speedup is made.

## N64 / tail 49

Deterministic work ratio:

`0.765625`

Median paired wall ratio:

`0.98411`

Geometric-mean wall ratio:

`0.97878`

Median CPU ratio:

`0.98418`

All frozen qualification gates pass:

- median wall <0.99;
- median CPU <0.99;
- deterministic work <0.85.

Thus the N64 production-shaped serialized manager route is approximately:

- 1.6% faster by median wall time;
- 2.1% faster by geometric-mean wall time;
- 1.6% faster by median CPU time;
- 23.4% lower in deterministic nonlinear row work.

## Interpretation

The negative N16 timing result was not evidence that variable-dimension solving cannot improve the production-shaped runtime.

It exposed a fixed-cost crossover.

The manager has a relatively fixed composition cost per solve. At N16 that cost exceeds the absolute saving from removing three nonlinear rows. At N32 the effects approximately balance. At N64 the larger solve reduction is sufficient to produce measurable net end-to-end speedup through the full serialized checkpoint/trial/candidate/commit path.

This is consistent with the earlier lower-level N32/N64 trajectory evidence, but MIQUAL14 is stronger because it includes the normal serialized transaction/runtime overhead.

## Qualified claim boundary

Qualified:

- exact production-shaped serialized semantics at N16/N32/N64;
- dimension-dependent runtime crossover;
- N64 net runtime gain on the equilibrium/basic-Richards envelope;
- 100% reduced routing with zero fallback/bypass;
- N64 deterministic work ratio 0.765625.

Not qualified:

- stable N32 runtime gain;
- dynamic serialized runtime speedup;
- optional-process combinations;
- whole-SWAP application speedup;
- MultiSWAP throughput gain;
- production-default replacement.

## Consequence

Do not spend more time optimizing N16 in isolation.

The next production-oriented work should use representative larger columns and obtain a dynamic serialized reference workload. Admission, if pursued before that dynamic evidence exists, must remain explicitly bounded and opt-in.

## Production boundary

No production-default change.

`LEGACY_NUMERICS` remains production default.
