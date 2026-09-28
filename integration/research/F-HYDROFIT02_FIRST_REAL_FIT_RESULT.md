# F-HYDROFIT02 — first real-data fit result

Status: QUALIFIED FIRST REAL CASE  
BRO object: `BHR000000378560`  
Interval: 0.04-0.14 m  
Canonical observed at closeout: `integration/f-ci-canonical@50ee9dc2acbc9847807d3fd98d0553f9862d428b`

## Source semantics

The official BRO SWE element schema establishes the tuple order and units:

1. `soilWaterPotential`: cm[H2O];
2. `volumetricWaterContent`: cm3/cm3;
3. `hydraulicConductivity`: cm/d.

The selected interval contains 17 complete triplets spanning h=-15849 to 0 cm[H2O].

## Stored WENR/BRO model

BRO identifies:

- modelling procedure: `WENRHydrofysicav1`;
- modelling method: `mualemVanGenuchten`;
- theta_r = 0.00000;
- theta_s = 0.66683;
- alpha = 0.03515 cm-1;
- n = 1.15043;
- m = 0.13076, consistent with 1-1/n;
- modelled Ks = 13.69 cm/d;
- conductivity exponent from the stored conductivity-shape array: l = -2.44937.

Under the F-HYDROFIT family-mean objective used here, this stored parameter set gives `J=51.2605466`.

This objective is not asserted to equal the historical WENR fitting objective.

## Controlled refits

### Incorrectly restricted l=0.5 diagnostic

The initial real-data experiment fixed l=0.5 and gave J=115.750603. This is retained as a negative diagnostic and must not be used to judge the stored WENR fit.

### Stored l retained

With l fixed to the stored -2.44937 and the remaining five parameters refitted:

- J = 39.0202986;
- theta_r = 0.163694;
- theta_s = 0.702519;
- alpha = 0.078095 cm-1;
- n = 1.209675;
- m = 0.173332;
- Ks = 27.2196 cm/d.

### Six-parameter modern fit

With l also fitted, three substantially different initial points converged to the same solution to reported precision:

- J = 35.0649947;
- theta_r = 0.126179;
- theta_s = 0.705378;
- alpha = 0.093393 cm-1;
- n = 1.180342;
- m = 0.152788;
- Ks = 32.5304 cm/d;
- l = -3.06237;
- local Jacobian condition number about 2909.

The three starts all reached J=35.0649947.

## Interpretation

Under this specific explicit objective, the six-parameter modern fit reduces objective value by about 31.6% relative to the stored WENR/BRO parameter set.

This does not establish that the modern fit is physically superior. The historical WENR objective, weighting, parameter constraints and fitting workflow are not yet reproduced here. In particular, the modern optimum moves theta_r substantially above the stored zero value and raises Ks, so physical plausibility and parameter identifiability require scrutiny.

The stable multi-start convergence is evidence for optimizer stability in this case, not parameter certainty.

## Next gates

1. decompose objective by theta and K family for stored and modern fits;
2. calculate residual patterns over h, not only scalar J;
3. run identifiability/profile diagnostics for theta_r, Ks and l;
4. repeat on the other two intervals in the same BRO object;
5. only then expand to additional BRO objects.

No solver-performance conclusion is made from this fit result.
