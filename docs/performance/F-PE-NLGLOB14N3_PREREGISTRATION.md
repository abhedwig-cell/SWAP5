# F-PE-NLGLOB14N3 preregistration — saturation-root retry-as-bracket contraction falsification

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@e0aead4c1a1402dbcf7aabb18218711383e237d4`

Reconciliation note:

The branch descends from the closed NLGLOB14N2 research authority. The intervening canonical delta since the NLGLOB14N2 baseline is ELASTIC28-only and does not alter TIMEINT17/NLGLOB saturation-entry semantics, root localization, constitutive providers, or mass accounting.

Parent authority:

- NLGLOB14N: `BLOCKED_NLGLOB14N_REFINED_RETREAT_CONVERGENCE`;
- NLGLOB14N1: `NLGLOB14N1_ROOT_TRIAL_SOLVER_FAILURE`;
- NLGLOB14N2: `RETRY_ADVISED_AT_ROOT_TRIAL`.

## Purpose

NLGLOB14N2 established that the finest HEAD saturation-entry blocker is a retry-advised endpoint solve inside the NLGLOB14A root bisection.

NLGLOB14N3 tests one narrow root-controller interpretation:

a retry-advised root trial is never accepted, but may act as a failed upper-bracket trial that contracts `phi_hi` to `phi_mid`, after exact restoration of the saved accepted state and accounting.

No solver tolerance, iteration limit or physical acceptance rule is changed.

## Frozen controller change

Inside NLGLOB14A root bisection only:

1. mark execution as a root trial before calling `advance_tg_core`;
2. if that call returns a solver result with `retry_advised=true`:
   - do not accept its candidate state;
   - restore the saved accepted state and accepted accounting;
   - retain ordinary diagnostic work counters;
   - set `phi_hi = phi_mid`;
   - continue the existing bisection;
3. all non-retry failures retain current fail-closed behavior;
4. ordinary non-root trial behavior is unchanged.

The retry-advised state itself never becomes accepted authority.

## Frozen target

First test exactly the NLGLOB14N blocked fixture:

- O05;
- TG;
- HEAD;
- dt = `7.8125e-6 d`;
- horizon = `0.05 d`;
- unchanged forcing.

## Frozen target gates

The controller hypothesis survives only if the target fixture:

1. no longer terminates as `SATURATION_ROOT_TRIAL_OTHER_FAILED`;
2. records at least one retry-bracket contraction;
3. enters persistent saturated mode through the existing localized event path;
4. completes the full 0.05 d trajectory;
5. remains finite;
6. remains mass-clean under the unchanged physical authority;
7. preserves valid provider-selected route semantics;
8. shows no rejected-trial state leakage.

## Frozen full-ladder replay

If the target gates pass, rerun the unchanged NLGLOB14N six-level HEAD+RUNOFF ladder using the NLGLOB14N3 root-controller interpretation.

Do not alter the NLGLOB14N retreat-event estimator or convergence threshold.

Report the unchanged NLGLOB14N classification on the repaired coverage surface.

## Frozen classifications

If the target gates fail:

`NLGLOB14N3_RETRY_BRACKET_CONTRACTION_FALSIFIED`.

If target gates pass but any previously complete NLGLOB14N fixture becomes invalid or mass/state inconsistent:

`NLGLOB14N3_RETRY_BRACKET_CONTRACTION_REGRESSION`.

If all 12 NLGLOB14N fixtures complete safely and the only changed path is retry-advised root-trial contraction:

`QUALIFIED_SATURATION_ROOT_RETRY_BRACKET_CONTRACTION_RESEARCH`.

The NLGLOB14N retreat-convergence classification is reported separately and is not retuned.

## Stop rules

Do not:

- accept retry-advised candidate state;
- increase MAXIT or backtracking;
- change BALTOL/head/ponding tolerances;
- change dt ladder or forcing;
- change event-node or retreat-event definitions;
- change physical mass gates;
- introduce production source changes.

## Architecture invariants

Affected invariants: 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: research root-controller policy only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14N3

BASELINE: `e0aead4c1a1402dbcf7aabb18218711383e237d4`

BRANCH: `research/f-pe-nlglob14n3-retry-bracket-contraction`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: implement the research-only retry-bracket controller and run the frozen target fixture.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
