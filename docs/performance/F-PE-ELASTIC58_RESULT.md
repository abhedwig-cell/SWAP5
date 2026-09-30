# F-PE-ELASTIC58 — physical temporal-budget transfer result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic58-physical-budget-transfer`

Qualified postimage:
`a565e44458edd4975db8b6c37e1f60f1e45b6072`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36679009630`

Job:
`109770152667`

Conclusion:
SUCCESS.

## Question

Can the independently qualified TEMPORAL04/05 physical head-error envelope be
transferred to the mode-7 defect-indicator / C-SAFE research chain without
fitting a new tolerance?

## Frozen external authority

TEMPORAL04/05 preregistered and blindly preserved:

- terminal pressure-head error <= `0.01 cm`;
- terminal water-content error <= `1e-5`;
- relative terminal bottom-flux error <= `1%`;
- relative integrated bottom-exchange error <= `0.5%`;
- complete mass accounting.

ELASTIC58 only has direct oracle coverage for head and water content.
It does not qualify the flux/exchange limits.

## Frozen defect scaling

ELASTIC54/55 qualified the research relation

`H_INF <= alpha * Binf`

with frozen

`alpha = 0.17320259355765216`.

Therefore ELASTIC58 preregistered, before the run:

`Binf_budget = 0.01 / alpha`

which evaluates exactly to

`0.05773585599727987 cm`.

No alpha or physical limit was refit.

## C-SAFE application

For each of the four ELASTIC55 profiles and every state/forcing/regime
sequence:

1. process the frozen dt ladder from largest to smallest;
2. unavailable full solve/indicator -> refine;
3. first point with
   `Binf <= 0.05773585599727987 cm`
   -> accept;
4. if no point passes -> EXHAUSTED.

The logic makes no monotonicity assumption.

## Bank

Profiles:
- 11060;
- 10260;
- 8016;
- 3030.

Preserved:
- profile geometry;
- Staringreeks retention materialization;
- generated Ss;
- bottom mode 7;
- swkimpl=0;
- explicit fixed-flux top boundary;
- states `-75,-20,+2,+10 cm`;
- perturbations `-0.05,-0.035,+0.035,+0.05 cm/day`;
- OFF, FIXED_1E6 and GENERATED;
- same nine-step dt ladder.

O0/O2 semantic identity passed.
No `src/**` production source changed.

## Primary result

Aggregate C-SAFE outcome:

- accepted sequences: `96`;
- EXHAUSTED sequences: `96`;
- paired accepted observations: `90`;
- accepted-but-unpaired observations: `6`.

On all 90 paired accepted observations:

- head-limit failures: `0`;
- water-content-limit failures: `0`;
- frozen global-envelope failures: `0`.

Thus every directly verifiable accepted point satisfied:

`H_INF <= 0.01 cm`;

`DTHETA_INF <= 1e-5`;

and

`H_INF <= alpha * Binf`.

## Per-profile results

### Profile 11060

- accepted: 24;
- paired: 24;
- unpaired: 0;
- exhausted: 24;
- head failures: 0;
- theta failures: 0;
- envelope failures: 0.

### Profile 10260

- accepted: 24;
- paired: 24;
- unpaired: 0;
- exhausted: 24;
- head failures: 0;
- theta failures: 0;
- envelope failures: 0.

### Profile 8016

- accepted: 24;
- paired: 18;
- unpaired: 6;
- exhausted: 24;
- head failures: 0;
- theta failures: 0;
- envelope failures: 0.

The six unpaired acceptances are all:
- initial head `h0=-20 cm`;
- positive forcing perturbation;
- accepted dt `0.0009765625 day`;
- Binf about `0.0377 cm`;
- all three ELAS regimes.

Specifically:
- delta `+0.035 cm/day`: OFF, FIXED_1E6, GENERATED;
- delta `+0.05 cm/day`: OFF, FIXED_1E6, GENERATED.

These full solves satisfy the research Binf budget but their two-half oracle
does not complete, so direct realized H_INF/DTHETA verification is unavailable.

They are not treated as physically qualified observations.

### Profile 3030

- accepted: 24;
- paired: 24;
- unpaired: 0;
- exhausted: 24;
- head failures: 0;
- theta failures: 0;
- envelope failures: 0.

## Interpretation

ELASTIC58 provides a genuine independent bridge.

The Binf threshold was not fitted from the ELASTIC58 bank. It was derived from:

1. an external preregistered physical head-error limit of `0.01 cm`;
2. the frozen ELASTIC54/55 global conservative scaling.

On all 90 accepted points for which a direct full-versus-two-half oracle is
available, that bridge preserves both the external head and water-content
limits.

This is stronger than merely replaying a threshold optimized on the same
material bank.

However, the six accepted-but-unpaired cases expose an important qualification
boundary.

The C-SAFE production-shaped rule can make an acceptance decision using only
the full solve and defect indicator, while the research oracle may fail to
materialize the two-half comparison needed to verify realized error.

Therefore ELASTIC58 cannot claim universal physical-budget qualification over
all accepted cases.

## Relation to F-CI14

F-CI14 requires eight explicit endpoint limits:

- h;
- theta;
- ponding;
- groundwater level;
- volact;
- ldwet;
- spev;
- saev.

ELASTIC58 directly addresses only the head budget and checks theta on the
paired subset.

It does not qualify the remaining six endpoint limits.

It also does not qualify the TEMPORAL04/05 bottom-flux or integrated-exchange
limits on the mode-7 ELAS bank.

## Decision

Classification:

`QUALIFIED_EXTERNAL_HEAD_BUDGET_TRANSFER_WITH_UNPAIRED_COVERAGE_GAP`.

Supported:
- exact derived Binf budget;
- C-SAFE application;
- 90/90 paired accepted head-envelope pass;
- 90/90 paired accepted theta-envelope pass;
- global conservative envelope preservation.

Unresolved:
- six accepted-but-unpaired oracle gaps;
- bottom-flux and integrated-exchange physical limits;
- the six remaining F-CI14 endpoint metrics;
- production indicator admission;
- production controller integration.

No production change is authorized.

The next bounded workunit should target the six accepted-but-unpaired cases and
determine whether the missing two-half oracle is a verification-harness
limitation, a half-step convergence issue, or evidence that acceptance coverage
must remain fail-closed there.
