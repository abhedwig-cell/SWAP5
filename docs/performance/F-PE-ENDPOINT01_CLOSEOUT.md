# F-PE-ENDPOINT01 closeout — dynamic-origin independent endpoint authority

Date: 2026-09-26

Status: `CLOSED_DIRECT_Q_SPACE_AUTHORITY_QUALIFIED`

PR:

`#653 — F-PE-ENDPOINT01: dynamic-origin independent endpoint authority`

Parent:

`#652 — F-PE-TEMPORAL07`

## Trigger

TEMPORAL07 could not admit c=0.65 because the inherited independent physical residual gate reported approximately `2.735e-14 m/s` for both c=0.65 and c=0.50, despite:

- production coupled residual closure around 1e-22 m/s;
- endpoint-head agreement with the independent root around 1e-12 m;
- MODFLOW model/API balance PASS;
- mass and transaction invariants PASS.

The inherited endpoint oracle evaluated a local three-point q(H) fit, constructed from +/-2e-8 m/s probes, at a dynamic-origin endpoint around +1e-7 m/s.

## Independent diagnosis

ENDPOINT01 replaced no production physics and changed no tolerance.

It constructed a direct endpoint authority:

`q -> fresh constant-flux MODFLOW6 H(q) -> non-committing SWAP q_swap(H(q)) -> R(q)=q_swap-q`

The frozen physical residual gate remained:

`abs(R) <= 1e-15 m/s`

The frozen endpoint-head gate remained:

`abs(H_production-H_direct) <= 5e-10 m`

## Dynamic-origin result

### c=0.50

Direct root residual:

`-5.67482494681676331e-16 m/s`

Production-head direct residual:

`1.75870006703782015e-16 m/s`

Production versus direct endpoint-head error:

`-2.79776202205539448e-14 m`

All frozen gates pass.

Historical three-point-fit residual at the same production endpoint:

`2.73563604113793708e-14 m/s`

### c=0.65

Direct root residual:

`1.45082979579268766e-17 m/s`

Production-head direct residual:

`1.45082847230370757e-17 m/s`

Production versus direct endpoint-head error:

`2.22044604925031308e-16 m`

All frozen gates pass.

Historical three-point-fit residual at the same production endpoint:

`2.73512847384965168e-14 m/s`

## Groundwater response characterization

Fresh constant-flux MODFLOW6 points from -1e-7 through +1e-7 m/s complete under unchanged solver controls.

The historical three-point local q(H) fit has a maximum available-ladder q error of:

`6.23468056361197083e-14 m/s`

This is materially above the frozen 1e-15 m/s endpoint residual gate.

The outer characterization point +1.5e-7 m/s is outside the unchanged solver convergence envelope and is retained as `ORACLE_UNAVAILABLE`; it is not synthesized.

## Historical preservation

The canonical historical one-cell closeout fixture passes with both endpoint authorities.

Historical original endpoint:

- H = `-0.714999970005842145 m`;
- residual = `-3.78973439691400074e-17 m/s`.

Direct q-space endpoint:

- H = `-0.714999970005808949 m`;
- residual = `-9.47560877278753900e-18 m/s`.

Head difference:

`3.31956684362921806e-14 m`

This is far inside the frozen 5e-10 m preservation gate.

## Scientific conclusion

The TEMPORAL07 endpoint blocker was an independent-oracle extrapolation problem, not a failure of the coupled SWAP-MODFLOW solution and not a c=0.65-specific failure.

The historical three-probe q(H) fit remains valid evidence inside its original closeout scale, but it is not sufficiently accurate to enforce a 1e-15 m/s residual gate at the larger dynamic-origin exchange scale.

The direct q-space endpoint is therefore qualified as the independent authority for dynamic-origin coupling admission.

## Repository effect

ENDPOINT01 changes no production source.

It adds only:

- preregistration;
- P0 convergence-envelope amendment;
- direct dynamic endpoint qualification harness;
- historical preservation harness;
- result and closeout evidence;
- CI wiring.

## Decision

F-PE-ENDPOINT01 is closed.

Verdict:

`DIRECT_Q_SPACE_AUTHORITY_QUALIFIED`

Dynamic c=0.50:

`PASS`

Dynamic c=0.65:

`PASS`

Historical preservation:

`PASS`

Acceptance tolerances changed:

`NO`

Production source changed:

`NO`

## Direct follow-up

The blocker that prevented TEMPORAL07 admission is now resolved.

A separate admission continuation may therefore re-evaluate frozen c=0.65 using:

- TEMPORAL05 physical envelope;
- TEMPORAL06 performance evidence;
- TANGENT01 same-policy Jacobian authority;
- TEMPORAL07 P0/P1 coupling response/cache evidence;
- ENDPOINT01 direct dynamic endpoint authority.

No coefficient recalibration is warranted.
