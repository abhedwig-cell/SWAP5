# F-PDI-VT01: theory-documentation-code reconciliation

## Classification

Candidate implementation/unit bug in the PDI vapor-conductivity helper.

## Code observation

`Kvap_func(WC,h,Temp)` documents `Temp` as degrees Celsius.

The current source evaluates:

- `MgRT = MgR/(Temp+273.15)`
- `Da = 2.14e-5*((Temp+273.15)/273.15)^2`
- `Rho_sv = 1e-3*exp(31.3716 - 6014.79/Temp - 7.92495e-3*Temp)/Temp`

Thus the same runtime Celsius temperature is converted to absolute temperature for MgRT and Da, but not for Rho_sv.

## Independent theory/documentation evidence

The saturated-vapor-density expression with constants 31.3716, 6014.79 and 7.92495e-3 is defined for absolute temperature T [K]. The PDI model-system literature likewise defines both Da and rho_sv with T in K. SWAP runtime `tsoil` is in degrees Celsius.

## Numerical consequence already reproduced

- -5 C: current Rho_sv expression overflows.
- +5 C: current Rho_sv underflows to zero in the tested double-precision evaluation.
- +20/+35 C: values are many orders of magnitude below physically expected saturated vapor density.

## Candidate minimal correction

Inside `Kvap_func`, define one local absolute temperature:

`TK = Temp + 273.15d0`

and use `TK` consistently in:

- `MgRT = MgR/TK`
- `Da = 2.14d-5*(TK/273.15d0)**2`
- `Rho_sv = 1.0d-3*exp(31.3716d0 - 6014.79d0/TK - 7.92495d-3*TK)/TK`

Keep the SWAP-009 correction unchanged:

`Hr = exp(h/100 * MgRT)` with signed unsaturated h.

## Status

`BUG_HYPOTHESIS_STRONGLY_SUPPORTED`, not yet admitted.

Required next gates:

1. direct function-level Kelvin/vapor comparison against an independent formula across negative and positive Celsius temperatures;
2. regression that NoVap PDI is bit-identical;
3. representative full PDI vapor-on SWAP run;
4. hard water-balance and nonlinear-route evidence;
5. source identity and governance admission.
