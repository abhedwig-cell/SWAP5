# F-PE-NLGLOB12C closeout — representation-aware endpoint convergence replay

Date: 2026-09-29

Final status:

`QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_REPLAY_RESEARCH`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@15e5fa2738a889700dc4b8ed792e823652b38dd3`

Qualification authority:

- run `36553728494`;
- job `109357771313`;
- conclusion: SUCCESS.

## Closure

NLGLOB12C closes positively.

The exact representation-aware certificate, combined with unchanged S0 replay, completes 87/96 trajectories on the frozen dynamic-top bank.

All eight NLGLOB12A stagnation trajectories recover.

Physical mass remains near roundoff and no process failures occur.

## Research conclusion

The broad above-floor stagnation blocker is resolved at research level without relaxing any configured numerical or physical tolerance.

A terminal state may be recognized as numerically exhausted when:

- every node residual lies within its own storage-representation resolution;
- the total residual lies within the aggregate representation resolution;
- existing head and ponding contracts already pass;
- state and route remain valid.

This is a representation certificate, not a looser balance threshold.

## Residual blocker

Only 9/96 trajectories remain incomplete:

- 8 O05/TG HEAD-RUNOFF predictor-domain failures;
- 1 O14/TG HEAD endpoint failure.

The dominant remaining work is therefore TG-specific near-saturation temporal admissibility rather than generic nonlinear globalization.

## Next work

1. continue the near-saturation TG line from NLGLOB11A;
2. separately characterize the single O14/TG/HEAD residual endpoint case if it persists after the TG repair;
3. after the TG line is resolved, return to TIMEINT17 same-route dynamic-top mechanism qualification;
4. event localization remains downstream;
5. TIMEINT18 variable-step/LTE remains downstream until dynamic-top qualification closes positively.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB12C

BASELINE: `15e5fa2738a889700dc4b8ed792e823652b38dd3`

BRANCH: `research/f-pe-nlglob12c-representation-replay`

STATUS: closed positive

IMPLEMENTATION STATUS: test-only S0 + representation-aware replay persisted

TEST STATUS: focused full-bank run PASS

QUALIFICATION STATUS: `QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_REPLAY_RESEARCH`

DEPENDENCIES / BLOCKERS: 8 TG predictor-domain failures plus 1 TG endpoint failure remain

NEXT SAFE STEP: near-saturation TG temporal-admissibility successor

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
