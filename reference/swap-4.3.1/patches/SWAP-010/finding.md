# SWAP-010 finding

## Defect

For hydraulic model 7, `WC_MvG_2_s` defines scaled bimodal effective saturation as

```text
Scap = (Omega1*Gamma1(h) + Omega2*Gamma2(h)
        - Omega1*Gamma1(h0) - Omega2*Gamma2(h0))
       / (1 - Omega1*Gamma1(h0) - Omega2*Gamma2(h0))
```

so its derivative has the same single weighted denominator.

B1.6 instead evaluates `C_MvG_2_s` as a sum of two separately scaled terms:

```fortran
Gam01 = Gamma1 (dabs(h0))
Gam02 = Gamma2 (dabs(h0))
C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h)/(1.0d0-Gam01) + &
                        Omega2*C2(h)/(1.0d0-Gam02))
```

This cannot in general be the derivative of the implemented retention curve.

## Minimal correction

The corrected capacity is

```fortran
Gam01 = Omega1*Gamma1 (dabs(h0))
Gam02 = Omega2*Gamma2 (dabs(h0))
C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h) + Omega2*C2(h)) / &
            (1.0d0-Gam01-Gam02)
```

No physical formulation is selected or redesigned here; the code is made algebraically consistent with its own implemented model-7 retention function.

## Classification

`CODE_BUG / DIRECT_DERIVATIVE_INCONSISTENCY`.

The earlier audit register classifies SWAP-010 as `FIX_TESTED`, certainty very high, severity high, because capacity enters the Richards storage term directly. The earlier hydraulic matrix reported about 40.2% capacity-consistency failures for its model-7 sample and zero after correction. The fresh admission rerun uses a different, broader source-bound sample and therefore has a different baseline failure fraction; both independently establish the same defect class.
