# F-PE-ELASTIC58 — model-certificate transaction and cost characterization preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC57 — QUALIFIED_NONMONOTONE_SAFE_HALVING_CONTROLLER_RESEARCH_CANDIDATE`

Parent postimage:
`research/f-pe-elastic57-nonmonotone-controller@33c037d1ee6af10853ebd257c662768da78f0a93`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Purpose

Characterize two separate questions before any production integration:

1. Does the existing `TX_TEMPORAL_MODEL_CERTIFICATE` transaction contract
   implement the non-monotone-safe retry semantics needed by ELASTIC57?
2. What solver/tridiagonal work would the ELASTIC57 certificate route require
   relative to the current exact-identity full-half Reference route on the same
   physical bank?

No production source or policy is changed.

## Part A — transaction contract

Use a qualification-only scripted transaction model with:
- complete mass accounting;
- zero mass residual;
- scripted solver success/failure;
- scripted certificate availability;
- scripted normalized indicator;
- scripted work counters.

Test:

A1. certificate <= 1 accepts one full trial and commits.

A2. certificate > 1 rejects, halves dt and retries.

A3. a later larger certificate after a previous retry does not cause dt growth
or oscillation; retries remain strictly one-way.

A4. unavailable certificate fails closed and increments the unavailable and
temporal rejection counters.

A5. mass failure rejects before commit even when certificate <= 1.

A6. retry exhaustion preserves the original committed state and reports no
commit.

## Part B — physical work projection

Replay the ELASTIC55/57 four-profile bank exactly.

For each direct solve point record or derive:
- full nonlinear iterations;
- half1 nonlinear iterations;
- half2 nonlinear iterations;
- full linear solves;
- half1 linear solves;
- half2 linear solves;
- full HeadCalc calls;
- half1 HeadCalc calls;
- half2 HeadCalc calls;
- full backtracking;
- half1 backtracking;
- half2 backtracking;
- indicator availability and one additional tridiagonal solve when available.

Research budgets:
- 0.01 cm;
- 0.03 cm;
- 0.10 cm;
- 0.30 cm.

Frozen scaling:
`alpha = 0.17320259355765216`.

Certificate-route cost:
- one full physical solve per attempted dt;
- +1 tridiagonal solve when the full solve converges and indicator is
  available;
- stop at the first `alpha*Binf <= budget`;
- otherwise exhaust the frozen ladder.

Identity-route cost:
- one full + two-half trajectory per attempted dt when the required solves
  converge far enough;
- exact endpoint identity is required;
- stop only if exact identity occurs;
- otherwise continue to the next smaller dt.

This is a work-count characterization, not a wall-clock benchmark.

## Comparisons

For each budget and sequence report:
- accepted/exhausted status for certificate route;
- total nonlinear iterations;
- total linear solves;
- total HeadCalc calls;
- total backtracking attempts;
- additional certificate tridiagonal solves;
- corresponding identity-route accumulated work over the same retry ladder.

Aggregate:
- work ratios certificate / identity;
- accepted-dt distribution;
- counts where the certificate route accepts while identity exhausts;
- counts where both exhaust.

## Safety

The ELASTIC54/55 frozen global envelope remains unchanged.

For every paired certificate acceptance:
- require observed H_INF <= research head budget.

Hard mass acceptance remains logically separate and is explicitly tested in
Part A.

## Gates

A1. transaction-core scripted model passes all six contract cases.

A2. same four profiles and same physical bank replay.

A3. O0/O2 physical semantics agree.

A4. no paired certificate false acceptance.

A5. identity route never receives a relaxed endpoint criterion.

A6. unavailable certificate remains fail-closed in the transaction test.

A7. zero `src/**` production changes.

## Decision

ELASTIC58 may qualify:
- the existing transaction contract as suitable for the ELASTIC57 controller
  semantics;
- a research work/cost advantage or disadvantage.

It does not authorize:
- a production head budget;
- production mode-7 indicator admission;
- replacement of the current production temporal route;
- a runtime default change.
