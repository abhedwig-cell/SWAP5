# F-PE-NLGLOB11 result — half-step provider-consistent TG coefficient predictor

Date: 2026-09-29

Status:

`CLOSED_TG_HALFSTEP_PREDICTOR_DOMAIN_NOT_RESOLVED`

Additional negative mechanism result:

`TG_HALFSTEP_PREDICTOR_SECOND_ORDER_REGRESSION`

Canonical base:

`integration/f-ci-canonical@6ce07b5578c0c1193d2d21a2449a1b7788714f40`

Qualification authority:

- workflow run: `36550910609`;
- job: `109348570855`;
- conclusion: SUCCESS.

## Frozen candidate

Only the auxiliary TG coefficient predictor was changed:

`theta_tilde = theta_n + 0.5 h theta_dot_n`.

The accepted TG state, physical mass contract, S0 replay, nonlinear tolerances, timestep and K-provider ownership remained unchanged.

## Smooth TIMEINT16C regression bank

All four ladders complete and remain physically clean.

But second order is lost.

Median refined top-head order:

`1.03343`.

Median refined top-theta order:

`1.03346`.

Individual head ladders >=1.5:

`0/4`.

Median deterministic work ratio versus KLAG BE:

`1.0`.

Physical interval/cumulative ledgers, constitutive roundtrip and native endpoint balance remain within authority.

Therefore the fixed half-step coefficient stage does not preserve the qualified TIMEINT16C temporal mechanism.

## Dynamic-top replay bank

Completed horizon:

`78/96 = 0.8125`.

This exceeds the old NLGLOB09 recovery threshold of 80%, and physical ledgers remain near roundoff:

- max interval ledger about `4.39e-14 cm`;
- max cumulative ledger about `6.06e-14 cm`.

However the same seven TG predictor-domain failures remain.

Thus the candidate does not resolve the target Arm-B defect.

## Interpretation

The result identifies an important constraint.

Provider consistency alone is not sufficient. The coefficient predictor must also approximate the endpoint hydraulic state at the correct temporal location.

Moving the coefficient stage to a fixed half-step returns the method to approximately first order even though the accepted TG moisture average itself is unchanged.

This strengthens the TIMEINT16C mechanism attribution: endpoint-consistent current-step coefficient staging is part of the observed second-order construction.

## Consequence

Do not try other fixed fractions inside this workunit.

A successor predictor should retain endpoint prediction while avoiding direct moisture extrapolation beyond the constitutive domain.

A bounded candidate is a head-space endpoint predictor derived from the accepted-state chain rule:

`h_dot_n = theta_dot_n / C(h_n)`

and

`h_tilde = h_n + h h_dot_n`.

K is then evaluated through the same provider on `h_tilde`.

This preserves endpoint staging and does not clip moisture.

It requires separate preregistration and full smooth-order requalification.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
