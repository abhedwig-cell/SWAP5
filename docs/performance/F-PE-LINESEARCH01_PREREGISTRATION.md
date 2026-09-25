# F-PE-LINESEARCH01 — Reference backtracking algorithm characterization

Date: 2026-09-25

Status: `PREREGISTERED_CHARACTERIZATION`

Production parent: admitted PLANVALID01 postimage `df664f56cf09ee8479701f15fe10ee02d31a9536`.

## Motivation

PROFILE02 and NEWTON-CANDIDATE01 established that difficult Reference trajectories are dominated by repeated backtracking candidate work.

F-AHL44 and F-AHL45 then falsified the current lookup family as a speed solution for theta-only candidate demand on the current demand-aware solver.

The remaining exact-performance question is therefore algorithmic:

> Does the current fixed factor /= 3 backtracking schedule spend substantial work on candidates that provide little or no useful residual progress, and is there evidence for a safer candidate-selection strategy?

## Current algorithm

For each Newton iteration:

1. solve one Newton correction;
2. start factor = 1;
3. evaluate candidate;
4. recompute residual;
5. compute sump, total residual sum and max residual;
6. accept progress if sump decreases or max residual is below tolerance;
7. otherwise divide factor by 3 and retry;
8. stop after max_backtracking attempts.

## Phase 1: observation only

No production algorithm change is authorized.

Instrument a test-only HeadCalc copy and record, per candidate:

- Newton iteration;
- backtracking ordinal;
- factor;
- previous residual inner-product metric;
- candidate residual inner-product metric;
- Fmax;
- whether the progress criterion would accept the candidate.

Characterize at least:

- the existing easy B01 case;
- the existing high-backtracking B01 case from NEWTON-CANDIDATE01.

## Questions

1. How often is factor=1 accepted?
2. For difficult iterations, at which factor is the first progress candidate found?
3. How many iterations exhaust all backtracking attempts?
4. Is residual response approximately monotone with factor?
5. Is there enough structure to justify testing interpolation, bisection, or another safeguarded schedule?

## Governance boundary

A future algorithm candidate may change candidate sequence and failure timing only under a separately preregistered qualification phase.

It must retain:

- the same Richards equations;
- the same constitutive authority;
- the same convergence tolerances;
- the same mass gates;
- transaction semantics;
- strict endpoint/state comparison against current Reference.

No practical/approximate error budget is used here.
