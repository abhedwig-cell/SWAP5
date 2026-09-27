# F-PE-ENDPOINT01 P0 convergence-envelope amendment

Date: 2026-09-26

Status: `PREREGISTERED_HARNESS_AMENDMENT`

## Trigger

The first ENDPOINT01 dynamic-authority run reached the preregistered groundwater-response ladder.

MODFLOW6 constant-flux solves completed through:

- -1.5e-7 m/s;
- -1.0e-7;
- -5e-8;
- -2e-8;
- 0;
- +2e-8;
- +5e-8;
- +1.0e-7.

The outermost positive characterization point:

`+1.5e-7 m/s`

did not converge under the unchanged canonical one-cell solver controls.

The run stopped before the direct endpoint root was attempted.

## Interpretation

The +/-1.5e-7 points were preregistered for P0 curvature characterization only.

They are not acceptance gates and are not required by the P1 direct endpoint definition.

A nonconverged characterization point must not be converted into a synthetic response value or used to retune MODFLOW.

## Amendment

For the P0 response ladder:

- retain every preregistered q point;
- if a fresh constant-flux MODFLOW solve does not converge, report that point as `ORACLE_UNAVAILABLE`;
- do not include unavailable points in fit-error statistics;
- require at least all points from -1.0e-7 through +1.0e-7 m/s to complete.

For the P1 q-space root:

- every q value actually used for bracketing or bisection must complete;
- no interpolation across a nonconverged MODFLOW point is allowed;
- if a required root-search point does not converge, P1 fails closed.

No solver tolerance, iteration cap, physical residual gate, endpoint-head gate, or coupling quantity is changed.
