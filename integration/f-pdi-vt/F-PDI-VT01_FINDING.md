# F-PDI-VT01: theory-documentation-code reconciliation

## Classification

CONFIRMED IMPLEMENTATION / UNIT-SCALE BUG in the PDI vapor-conductivity helper.

## Code observation

`Kvap_func(WC,h,Temp)` documents `Temp` as degrees Celsius.

The current source evaluates:

- `MgRT = MgR/(Temp+273.15)`
- `Da = 2.14e-5*((Temp+273.15)/273.15)^2`
- `Rho_sv = 1e-3*exp(31.3716 - 6014.79/Temp - 7.92495e-3*Temp)/Temp`

Thus the same runtime Celsius temperature is converted to absolute temperature for MgRT and Da, but not for Rho_sv.

## Documentation authority

The SWAP 4.3.030 theory manual, section 2.2.5.2, gives the same PDI vapor-conductivity equations and explicitly defines T as absolute temperature in K. It uses T in Da, rho_sv and the Kelvin term.

## Scientific authority

The PDI model-system literature likewise defines T as absolute temperature in K in the isothermal vapor-conductivity equations. Independent later implementations using Celsius input write the saturated-vapor-density relation with T_C + 273.15 throughout.

## Numerical consequence already reproduced

- -5 C: current Rho_sv expression overflows.
- +5 C: current Rho_sv underflows to zero in the tested double-precision evaluation.
- +20/+35 C: values are many orders of magnitude below the intended saturated vapor density.

## Minimal correction

Inside `Kvap_func`, define one local absolute temperature:

`TK = Temp + 273.15d0`

and use `TK` consistently in:

- `MgRT = MgR/TK`
- `Da = 2.14d-5*(TK/273.15d0)**2`
- `Rho_sv = 1.0d-3*exp(31.3716d0 - 6014.79d0/TK - 7.92495d-3*TK)/TK`

Keep the SWAP-009 correction unchanged:

`Hr = exp(h/100 * MgRT)` with signed unsaturated h.

## Status

`BUG_CONFIRMED_FIX_PREREGISTERED`.

Required next gates:

1. exact-source function-level vapor comparison against the independent absolute-temperature equation across negative and positive Celsius temperatures;
2. regression that water retention and NoVap PDI are unchanged;
3. preserve SWAP-009 signed-head Kelvin behavior;
4. representative full PDI vapor-on SWAP run;
5. hard water-balance and nonlinear-route evidence;
6. source identity and governance admission.
