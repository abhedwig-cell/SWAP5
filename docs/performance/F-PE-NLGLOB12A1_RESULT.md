# F-PE-NLGLOB12A1 result — representation-aware endpoint certificate and replay

Date: 2026-09-29

Status:

`QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_CERTIFICATE_RESEARCH`

Canonical base:

`integration/f-ci-canonical@15e5fa2738a889700dc4b8ed792e823652b38dd3`

Qualification authority:

- workflow run: `36553669542`;
- job: `109357577995`;
- conclusion: SUCCESS.

## Frozen question

Can an endpoint state be accepted test-only when its local and aggregate residuals are already within the exact floating-point representation scale of the stored moisture differences, while preserving the existing head, ponding, route and physical mass contracts?

## Bank A — stagnation subset

PASS.

- frozen stagnation cases: 8;
- recovered: 8/8;
- R0 triggered in: 8/8.

No scalar balance tolerance was changed.

## Full 96-case replay bank

Completed requested horizon:

`87 / 96 = 0.90625`.

The completed set spans:

- TG and KLAG;
- FLUX, HEAD and RUNOFF;
- B01, B12, O05 and O14.

Representation-floor accepts:

`1355`.

Existing S0 accepts:

`2`.

No process failures occurred.

## Physical admissibility

Physical mass remains near roundoff:

- max accepted-interval ledger: about `4.84e-14 cm`;
- max cumulative ledger: about `6.06e-14 cm`.

All completed states are finite.

No scalar balance, head, ponding, MAXIT, backtracking, timestep, K-staging or route rule was relaxed.

## Frozen classification

`QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_CERTIFICATE_RESEARCH`.

All preregistered gates pass.

## Interpretation

NLGLOB12A1 removes the representation-floor stagnation blocker at research level.

The key distinction is that R0 does not enlarge BALTOL02.

Instead, it certifies a state only when the residual is already no larger than the arithmetic resolution implied by the actual stored `theta - theta_m1` representation, both locally and in aggregate, while all other existing state guards pass.

This is therefore a representation-aware exhaustion certificate, not an empirical tolerance relaxation.

## Consequence

The dynamic replay recovery increases from the earlier 75/96 S0-only result to 87/96.

The remaining failures are not covered by R0 and require separate attribution. The TG near-saturation temporal-admissibility line remains independent.

A production-shaped proposal is not yet authorized. First complete the remaining temporal and endpoint qualification.

## Production boundary

Research/test-only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
