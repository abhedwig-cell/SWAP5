# F-PE-NLGLOB12C result — representation-aware endpoint convergence replay

Date: 2026-09-29

Status:

`QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_REPLAY_RESEARCH`

Canonical base:

`integration/f-ci-canonical@15e5fa2738a889700dc4b8ed792e823652b38dd3`

Qualification authority:

- workflow run: `36553728494`;
- job: `109357771313`;
- conclusion: SUCCESS.

## Frozen question

Can an exact representation-aware convergence certificate, evaluated alongside the unchanged S0 replay, recover the storage-floor stagnation population without relaxing any configured balance tolerance?

## Full-bank result

Complete requested horizon:

`87 / 96 = 0.90625`.

This exceeds the frozen >=80% gate.

Coverage spans:

- TG and KLAG;
- FLUX, HEAD and RUNOFF;
- B01, B12, O05 and O14.

All 8/8 NLGLOB12A stagnation targets recover.

Representation-floor acceptances:

`1336`.

Every representation-floor acceptance satisfies:

- node-local normalized representation ratio <=1;
- aggregate normalized representation ratio <=1.

## Physical admissibility

Physical mass remains near roundoff:

- max accepted-interval ledger about `4.84e-14 cm`;
- max cumulative ledger about `6.06e-14 cm`.

All completed states are finite.

Process failures:

`0`.

No extra Newton or backtracking evaluation is introduced by the representation certificate.

## Frozen classification

`QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_REPLAY_RESEARCH`.

All frozen gates pass.

## Remaining 9 failures

The unrecovered population is now sharply reduced to:

- 8 `PREDICTED_RETENTION_DOMAIN_FAILED`, all O05 / TG / HEAD or RUNOFF across the four dt levels;
- 1 `ENDPOINT_SOLVE_FAILURE`, O14 / TG / HEAD / dt 6.25e-5 d.

Thus the broad endpoint-globalization blocker has largely been removed on the frozen bank.

The dominant remaining blocker is now TG-specific near-saturation temporal/predictor admissibility.

## Interpretation

NLGLOB12C establishes a research numerical-policy result:

when residuals are already below the arithmetic resolution of the stored moisture state, endpoint termination can be recognized without loosening BALTOL02 or any physical mass gate.

This is not a tolerance relaxation.

The certificate is state-representation derived.

## Consequence

The nonlinear endpoint workstream may now treat representation-floor stagnation as qualified at research level.

The remaining work should focus on:

1. the O05 TG near-saturation predictor/accepted-state line;
2. the single residual O14 TG HEAD endpoint case.

Production admission requires a separate production-shaped implementation and broader regression authority.

## Production boundary

Research only.

No production `src/**` change.

No BALTOL02 or other numerical tolerance changed.

`LEGACY_NUMERICS` remains production default.
