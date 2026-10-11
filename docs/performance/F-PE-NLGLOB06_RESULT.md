# F-PE-NLGLOB06 result — Newton-trajectory exhaustion discrimination

Date: 2026-09-29

Status:

`NLGLOB06_TRAJECTORY_CERTIFICATE_NONSPECIFIC`

Canonical base:

`integration/f-ci-canonical@2332a59d2ec33245f53593960e0c334525eda148`

Qualification authority:

- workflow run: `36547506113`;
- job: `109337328215`;
- conclusion: SUCCESS.

## Frozen question

Can terminal numerical exhaustion be identified safely from a three-iteration trajectory rather than from a single Newton-state snapshot?

The preregistered T0 discriminator required:

- three consecutive locally floor-admissible iterations;
- persistent storage/balance-floor proximity;
- no material net balance improvement over the window;
- persistently collapsed head corrections;
- repeated lack of useful already-tested backtracking improvement;
- poor model-quality rho in at least 2/3 iterations;
- finite, route-consistent state.

No solver behavior was changed.

## Coverage

PASS.

- cases: 96;
- endpoint-failure trajectories: 96;
- audited Newton iterations: 768;
- eligible three-iteration windows: 576;
- terminal windows evaluated: 96;
- diagnostic coverage: 1.0;
- process failures: 0.

## Terminal usefulness

T0 certifies:

`37 / 96`

terminal endpoint trajectories.

Terminal certification fraction:

`0.38542`.

Coverage is broad in identity:

- both TG and KLAG;
- all three routes;
- all four materials.

But only 2/6 route-mode families reach the frozen >=50% terminal-certification family gate.

Family terminal certification:

- FLUX / KLAG: 8/16 = 0.5000;
- FLUX / TG: 9/16 = 0.5625;
- HEAD / KLAG: 6/16 = 0.3750;
- HEAD / TG: 5/16 = 0.3125;
- RUNOFF / KLAG: 2/16 = 0.1250;
- RUNOFF / TG: 7/16 = 0.4375.

Thus T0 is materially more selective than the NLGLOB05 single-iteration candidates, but it remains too narrow for a general endpoint certificate.

## Negative-control discrimination

Hard unresolved controls remain perfectly rejected:

- above-floor false-positive rate: 0.0;
- storage-floor-absent false-positive rate: 0.0;
- head/ponding-unresolved false-positive rate: 0.0.

Adequate-model control:

- n = 241;
- false-positive rate = `0.03734`.

This passes the frozen <=5% gate.

Early-trajectory control:

- n = 384;
- false-positive rate = `0.06510`.

This fails the frozen <=5% gate.

That failure is decisive.

## Frozen classification

`NLGLOB06_TRAJECTORY_CERTIFICATE_NONSPECIFIC`.

The three-iteration T0 discriminator does not qualify.

No endpoint acceptance replay is authorized.

## Interpretation

Cross-iteration history helps substantially.

Compared with NLGLOB05, the adequate-model nonspecificity is reduced below the frozen 5% gate, while all hard unresolved controls remain rejected.

However, a non-negligible fraction of still-useful early trajectory segments already exhibit the same three-iteration floor/stagnation signature as terminal exhaustion.

Therefore the missing information is not merely:

- one more local floor scalar;
- a three-iteration persistence window;
- persistent tiny corrections;
- repeated poor rho;
- repeated backtracking non-improvement.

A safe successor must distinguish **continued useful evolution while already on the arithmetic floor** from **genuine terminal inability to change the accepted candidate**.

The most defensible next question is therefore whether state evolution itself has become representationally stationary across accepted Newton origins, rather than whether residual diagnostics are merely stationary.

That means examining cross-iteration accepted-state displacement in conserved moisture/head space relative to representational resolution, not changing the existing convergence tolerances.

## Preserved authority

The full chain remains valid:

- TIMEINT17 endpoint blocker remains real;
- NLGLOB01 no simple state-scaling signal;
- NLGLOB02 near-floor stagnation;
- NLGLOB03 no final summation explanation;
- NLGLOB04 storage representation floor;
- NLGLOB05 single-iteration certificate nonspecific;
- NLGLOB06 three-iteration residual/merit trajectory certificate still nonspecific.

None of these results weakens physical mass conservation or the existing BALTOL02 authority.

## Consequence

Do not tune T0 by changing:

- the three-iteration window;
- balance-range factor;
- no-progress threshold;
- tiny-step threshold;
- merit-improvement threshold;
- rho threshold or count.

That would be outcome-conditioned tuning of the rejected candidate.

A materially distinct successor may preregister an accepted-state stationarity discriminator based on cross-iteration physical-state displacement and representational resolution.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No tolerance, mass, MAXIT, backtracking, timestep, K-staging or route/event change.

`LEGACY_NUMERICS` remains production default.
