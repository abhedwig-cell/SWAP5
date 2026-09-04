# ADR-0002: Transactional time stepping

**Status:** Accepted  
**Date:** 2026-09-04  
**Affected invariants:** 7, 8, 9, 10, 11, 13, 26, 29

## Context

Adaptive stepping, nonlinear retries and predictor-corrector coupling require speculative calculations. In legacy control flow, solver trials can be interwoven with updates to global or persistent model state. That makes rollback difficult and risks contamination of the accepted state after a rejected trial.

## Decision

Every kernel advance over an interval uses an explicit transaction model:

1. identify the committed starting state;
2. create a trial from that state;
3. retry or change numerical strategy without modifying committed state;
4. commit one accepted physical endpoint, or roll back completely.

A `TrialResult`-like result object may carry endpoint state, flux integrals, diagnostics and numerical metadata. The commit layer is the only path that replaces committed physical state.

Numerical warm-start information may survive rejected trials when useful, but it is not physical state and cannot change the physical starting point of a correction.

## Consequences

Positive consequences:

- reliable rollback;
- coupling windows are not tied to legacy day control flow;
- embedded error estimation and retries can share one contract;
- state corruption from rejected trials becomes structurally harder.

Costs and constraints:

- routines with hidden side effects must be isolated or refactored;
- state and diagnostic ownership must be explicit;
- commit semantics require dedicated tests.

## Verification implications

Tests must verify that:

- rejected trials leave committed state bitwise or numerically unchanged as appropriate;
- a committed endpoint equals the accepted trial endpoint;
- retry histories do not alter the physical result beyond qualified numerical tolerances;
- water-balance terms are committed exactly once.
