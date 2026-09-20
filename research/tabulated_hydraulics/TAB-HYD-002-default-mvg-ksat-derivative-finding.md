# TAB-HYD-002: default MvG Ksat clamp derivative inconsistency in legacy SWKIMPL=1

Status: **REPRODUCED_IN_PUBLIC_PRE_STRANGLER_LINEAGE / NOT A CURRENT SWAP5 PRODUCTION CLAIM**

## Scope

This finding concerns the public pre-strangler SWAP runtime used by the TAB-HYD executable experiments:

`SWAP-model/SWAP@2a5ace1c06be7a257b64e9ac1896b489533f16e9`.

It is not yet a byte-exact SWAP 4.3.1 B0 claim, and it is not a defect claim against the current SWAP5 production provider. The current SWAP5 B1.10/default-MvG provider explicitly does not admit `SWKIMPL=1` and returns a reserved zero derivative output.

## Residual/Jacobian mismatch

For default Mualem-van Genuchten hydraulics with no positive air-entry pressure, the legacy/public residual conductivity route contains a near-saturation clamp:

```fortran
else if (relsat > (1.0_real64 - 1.0d-6)) then
   hconduc = ksatfit
```

The residual K relation is therefore constant in this branch.

The corresponding `dhconduc` route does not test that clamp. It continues into the analytical MvG derivative unless another older branch is activated:

```fortran
if (relsat < 0.001_real64) then
   dhconduc = 0.0_real64
else if (relsat > s_enpr) then
   dhconduc = 1.0d-12
else
   ... analytical derivative ...
end if
```

For the ordinary Hupsel/default-MvG case, this means the `SWKIMPL=1` Jacobian can differentiate an unclamped K function while the residual uses the Ksat-clamped function.

This is the same class of inconsistency already used as a scientific rule in SWAP-011: the Jacobian derivative must correspond to the actual conductivity relation used by the residual.

## Bounded diagnostic candidate

A research-only candidate inserted the missing residual-branch derivative rule:

```fortran
if (h_enpr > -1.0d-2 .and. relsat > (1.0_real64 - 1.0d-6)) then
   dhconduc = 0.0_real64
```

No theta(h), K(h), `SWKIMPL=0`, table interpolation, or forcing logic was changed.

## Hupsel evidence

Full 2002-2004 daily-output runs gave:

### Original analytical SWKIMPL=1 versus analytical SWKIMPL=0

- GWL max abs difference: `1146.52418 cm`
- GWL RMSE: `1091.56561 cm`
- drainage max abs difference: `0.94697 cm`
- TACT max abs difference: `0.35931 cm`

This is not a plausible small difference between two numerical linearizations of the same residual problem.

### Consistency-corrected analytical SWKIMPL=1 versus analytical SWKIMPL=0

- GWL max abs difference: `0.62579 cm`
- GWL RMSE: `0.0434817 cm`
- drainage max abs difference: `0.00732 cm`
- DSTOR max abs difference: `0.00733 cm`
- TACT max abs difference: `0.00266 cm`

The correction removes the catastrophic trajectory divergence while leaving the expected non-zero difference between two distinct nonlinear linearization routes.

### Corrected analytical versus corrected tabulated SWKIMPL=1

With TAB-HYD-001's zero derivative at constant table endpoints, the corrected analytical and corrected tabulated routes agree very closely:

- GWL max abs difference: `0.00043 cm`
- GWL RMSE: `1.5402e-5 cm`
- drainage max abs difference: `0` at written precision
- TACT max abs difference: `0` at written precision
- DSTOR max abs difference: `1.41e-10 cm`

This is strong evidence that the large earlier `SWKIMPL=1` discrepancies were derivative-consistency problems rather than an intrinsic failure of the table representation.

## Disposition

- Do not use the original legacy/public `SWKIMPL=1` Hupsel route as a scientific reference.
- Do not backport this candidate to B0/B1 from this workstream without exact B0 reproduction and the normal correction-admission gate.
- When `SWKIMPL=1` is admitted in SWAP5, explicitly test derivative consistency at every residual clamp or extension, including the default-MvG Ksat clamp and tabulated endpoint extensions.
