# F-PE-TIMEINT12 preregistration — fully implicit dynamic-top derivative prerequisite

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@044e686d1899adf3a631716d09743aa4fce0818f`

Parent authority:

- TIMEINT04-05 qualify fully implicit variable-step BDF2 on a smooth fixed-flux envelope;
- BOFEK00 qualifies corrected dynamic-top Jacobian only for fixed top conductivity, SWKIMPL=0;
- TIMEINT11 rejects TR-BDF2/ESDIRK as the default smooth integrator on cost grounds.

## Trigger

A second-order BDF2 route requires endpoint-updated conductivity.

On the current dynamic-top head-boundary path, HeadCalc requires:

`dHsurf/dh_top`.

The dynamic-top provider currently exposes this derivative only when top-node conductivity is fixed.

Therefore fully implicit dynamic-top is a correctness prerequisite before BDF2 may be exercised on wet/ponding cases.

## Mathematical candidate

For conductivity mean method 1:

`Kf = 0.5*(Ksat + Ktop(h))`

`dKf/dh = 0.5*dKtop/dh`.

Use the already qualified smooth-route constitutive directional derivative for `dKtop/dh`.

Define:

`a = dt / d_surface`

`p1 = a*Kf`

`p1' = a*Kf'`.

For the head-regime analytical numerator:

`A = pond_prev + q0*dt - Kf*dt + p1*h + runoff_constant`

where `runoff_constant=0` for the no-runoff head branch and
`dt/RSRO * PMAX` for the linear-runoff branch.

Then:

`A' = -Kf'*dt + p1'*h + p1`.

With denominator:

- no runoff: `D = 1+p1`;
- linear runoff: `D = 1+p1+dt/RSRO`;

and `Hsurf=A/D`:

`dHsurf/dh = (A' - Hsurf*p1') / D`.

When `Kf'=0`, this reduces exactly to the already admitted fixed-K derivative:

`p1/D`.

## Test-only qualification

No production source is modified.

For repository-backed B01, B12, O05 and O14 hydraulics, sample a preregistered grid of:

- top pressure head;
- previous ponding;
- rainfall;
- dt.

Evaluate the unmodified dynamic-top value formula with fully variable K.

For every point whose base and central perturbations all remain in the same smooth head-regime route:

1. compute the analytical derivative above;
2. compute a central finite-difference derivative of returned surface head;
3. compare.

Both no-runoff ponded-head and linear-runoff head routes must be represented.

## Frozen gates

Advance only if:

1. at least 20 smooth same-route head-regime points are obtained;
2. at least 5 no-runoff head points;
3. at least 5 linear-runoff points;
4. every analytical derivative is finite;
5. every finite-difference derivative is finite;
6. max absolute mismatch <= 1e-6;
7. max relative mismatch <= 1e-5 for derivatives with magnitude >=1e-6;
8. fixed-K limit identity is verified algebraically/numerically to <=1e-12.

No tolerance changes after exposure.

## Stop rule

If derivative qualification fails, dynamic-top BDF2 is blocked.

If it passes, TIMEINT12A may materialize the derivative test-only into the provider and exercise fully implicit BE before any BDF2 wet-regime claim.

## Production boundary

No production source change in this phase.
