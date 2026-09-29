# F-PE-NLGLOB12A1 closeout — representation-aware endpoint certificate

Date: 2026-09-29

Final status:

`QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_CERTIFICATE_RESEARCH`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@15e5fa2738a889700dc4b8ed792e823652b38dd3`

Qualification authority:

- run `36553669542`;
- job `109357577995`;
- conclusion: SUCCESS.

## Closure

NLGLOB12A1 closes positively.

The representation-aware R0 certificate recovers all 8/8 frozen stagnation trajectories and raises full-bank dynamic replay completion to 87/96, while physical mass remains at roundoff scale.

The certificate uses no fitted tolerance multiplier.

It requires:

- every local residual within its node-specific storage representation scale;
- total residual within the aggregate storage representation scale;
- existing head and ponding guards;
- finite state;
- downstream route consistency;
- unchanged physical mass accounting.

## Scientific consequence

The previously identified above-floor stagnation is an arithmetic representation-floor issue, not evidence that more physical moisture evolution is required.

This blocker is therefore removed at research level.

## Remaining blockers

NLGLOB12A1 does not cover:

- TG accepted-state near-saturation temporal-admissibility failures;
- any residual endpoint trajectory that does not satisfy R0;
- production-shaped convergence-policy integration.

The next priority remains the preregistered near-saturation temporal subdivision line.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB12A1

BASELINE: `15e5fa2738a889700dc4b8ed792e823652b38dd3`

BRANCH: `research/f-pe-nlglob12a1-representation-certificate`

STATUS: closed positive

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_CERTIFICATE_RESEARCH`

NEXT SAFE STEP: admit research authority, then continue near-saturation temporal admissibility and residual-failure attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
