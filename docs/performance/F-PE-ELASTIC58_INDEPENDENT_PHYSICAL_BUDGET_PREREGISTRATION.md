# F-PE-ELASTIC58 — independent physical temporal-budget qualification preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN`

Parent postimage:
`research/f-pe-elastic57-controller-robustness@b09ab27c7e5cd1027975f42ad61511500e180d53`

Canonical authority:
`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

Frozen global conservative scaling:
`alpha = 0.17320259355765216`.

Independent physical envelope authority:
F-PE-TEMPORAL04 P1 / F-PE-TEMPORAL05.

Frozen physical limits:
- terminal max |dh| versus refined Reference oracle <= 0.01 cm;
- terminal max |dtheta| <= 1e-5;
- relative terminal bottom-flux difference <= 1%;
- relative integrated bottom-exchange difference <= 0.5%;
- mass remains a separate hard gate.

## Question

Can the ELASTIC53-55 conservative mode-7 indicator plus the ELASTIC57 C-SAFE
refinement rule enforce the already-qualified independent physical envelope on
the multi-profile mode-7 bank?

No new physical tolerance is chosen in ELASTIC58.

## Derived controller threshold

Because the frozen global relation is

`H_INF <= alpha * Binf`

and the independent head-error limit is

`H_INF <= 0.01 cm`,

the research Binf acceptance threshold is derived exactly as

`Binf <= 0.01 / alpha = 0.05773585599727987 cm`.

This threshold is derived before execution and is not fitted to ELASTIC58
results.

## Frozen bank

Reuse the four ELASTIC55 profiles:
- 11060;
- 10260;
- 8016;
- 3030.

Reuse:
- profile-specific retention materialization;
- profile-specific generated Ss;
- 16-node geometry;
- bottom mode 7;
- swkimpl=0;
- fixed-flux top boundary;
- OFF, FIXED_1E6 and GENERATED;
- h0 = -75, -20, +2, +10 cm;
- delta = +/-0.035 and +/-0.05 cm/day.

Total sequences:
`4 profiles * 4 heads * 4 perturbations * 3 regimes = 192`.

## Refinement controller

For every sequence, C-SAFE tests dt from largest to smallest:

- dt0 = 0.015625 day;
- repeated factor 0.5;
- up to 15 levels total.

At each level:
1. if the full solve fails or Binf is unavailable, continue;
2. if `Binf <= 0.05773585599727987 cm`, accept that dt;
3. otherwise continue;
4. if no level passes, classify EXHAUSTED.

No monotonicity assumption is used.

## Independent oracle

For every accepted C-SAFE point construct an independent fixed-substep
Reference oracle over the same requested interval:

- N = 32 equal substeps;
- same initial state;
- same forcing;
- same bottom mode 7;
- same material/ELAS regime;
- same solver/tolerances;
- accepted-state chaining across all 32 substeps.

A point is oracle-qualified only if all 32 substeps converge.

Record:
- max terminal |dh|;
- max terminal |dtheta|;
- full-step terminal bottom flux versus final oracle bottom flux;
- full-step integrated bottom exchange
  `qbot_full * dt`;
- oracle integrated bottom exchange
  `sum(qbot_j * dt/32)`;
- hard mass validity.

## Relative-error denominators

Terminal bottom-flux relative error:

`abs(q_full-q_oracle) / max(abs(q_oracle), 1e-12 cm/day)`.

Integrated bottom-exchange relative error:

`abs(Q_full-Q_oracle) / max(abs(Q_oracle), 1e-12 cm)`.

The denominator floors are numerical guards only and are frozen before results.

## Hypotheses

H1. Every oracle-qualified C-SAFE acceptance satisfies the independent 0.01 cm
head-error limit.

H2. The same accepted points also satisfy the independent theta, terminal-flux
and integrated-exchange limits without using those quantities for acceptance.

H3. C-SAFE may exhaust some difficult sequences; safe exhaustion is preferable
to accepting outside the independently qualified physical envelope.

H4. GENERATED does not require a distinct physical budget.

## Gates

A1. Exactly the four ELASTIC55 profiles are used.

A2. All 192 sequences execute through the frozen C-SAFE ladder.

A3. O0/O2 C-SAFE accept/exhaust decisions are identical.

A4. The frozen Binf threshold is exactly
`0.05773585599727987 cm`.

A5. Every accepted point either completes the 32-substep oracle or is reported
explicitly as ORACLE_UNAVAILABLE; no physical pass claim is made for unavailable
oracle points.

A6. Every oracle-qualified accepted point satisfies:
- |dh| <= 0.01 cm;
- |dtheta| <= 1e-5;
- terminal bottom-flux relative error <= 0.01;
- integrated bottom-exchange relative error <= 0.005.

A7. No alpha or physical error limit is refit.

A8. Zero production `src/**` changes.

## Decision

ELASTIC58 may qualify:
- an independently physically bounded mode-7 C-SAFE research candidate;
- or falsify the present Binf/global-scaling/controller composition.

It does not authorize production temporal-budget admission or F-CI14 completion.
