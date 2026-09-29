# F-PE-NLGLOB07 result — representational accepted-state stationarity attribution

Date: 2026-09-29

Status:

`NLGLOB07_STATE_STATIONARITY_NONSPECIFIC`

Canonical base:

`integration/f-ci-canonical@30e507fc8bdf7f7c37f327ab378e5c4a8ae39b94`

Qualification authority:

- workflow run: `36548150742`;
- job: `109339441540`;
- conclusion: SUCCESS.

## Frozen question

Can endpoint exhaustion be identified from the accepted moisture state itself becoming representationally stationary across two consecutive Newton transitions?

S0 required:

- current balance/storage-floor/head/ponding guards;
- two consecutive moisture transitions within the preregistered 32-ULP max-node and weighted-storage envelopes;
- no renewed normalized storage motion;
- finite route-consistent state.

No solver behavior was changed.

## Coverage

PASS.

- bank cases: 96;
- endpoint-failure trajectories: 96;
- audited iterations: 768;
- eligible three-state windows: 576;
- terminal windows: 96;
- diagnostic coverage: 1.0;
- process failures: 0.

## Terminal signal

S0 certifies:

`96 / 96`

terminal trajectories.

Every route-mode family is 16/16 certified:

- FLUX / KLAG: 1.0;
- FLUX / TG: 1.0;
- HEAD / KLAG: 1.0;
- HEAD / TG: 1.0;
- RUNOFF / KLAG: 1.0;
- RUNOFF / TG: 1.0.

Thus terminal endpoint states are uniformly representationally stationary in moisture space on this frozen bank.

## Negative controls

Hard unresolved controls remain perfectly rejected:

- above-floor false-positive rate: 0.0;
- storage-floor-absent false-positive rate: 0.0;
- head/ponding-unresolved false-positive rate: 0.0.

However:

- adequate-model control false-positive rate: `0.22822`;
- early-trajectory control false-positive rate: `0.28646`.

Both exceed the frozen limits substantially.

## Frozen classification

`NLGLOB07_STATE_STATIONARITY_NONSPECIFIC`.

S0 does not qualify as an exhaustion discriminator.

No endpoint acceptance replay is authorized from S0.

## Interpretation

The result changes the blocker diagnosis in one important way.

Representational stationarity is not merely a terminal phenomenon. It can begin materially earlier than the final failed Newton iteration while the current solver continues iterating.

Therefore iteration position is not a reliable proxy for whether physically meaningful state evolution remains.

The next bounded question is not another attempt to sharpen S0 with extra scalar conditions.

It is:

**after the first S0-stationary point, does the accepted moisture state subsequently move by a physically meaningful amount at all?**

If later Newton work changes the candidate state by less than the already accepted physical water-depth significance scale, then the NLGLOB05-07 "early false-positive" population is not necessarily unsafe; it may be temporally early but physically inert.

That question must be tested separately before any replay.

## Preserved authority

- TIMEINT17 endpoint globalization blocker remains valid.
- NLGLOB04 storage representation floor remains valid.
- NLGLOB05 and NLGLOB06 nonspecificity remains valid.
- NLGLOB07 establishes 96/96 terminal representational stationarity, but not safe termination specificity.

No physical mass authority is weakened.

## Consequence

Do not tune:

- 32-ULP envelope;
- two-transition requirement;
- factor-2 renewed-motion guard;
- existing early or adequate controls.

Open a separate successor based on tail state drift, not a modified S0 discriminator.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No tolerance, mass, MAXIT, backtracking, timestep, K-staging or route/event change.

`LEGACY_NUMERICS` remains production default.
