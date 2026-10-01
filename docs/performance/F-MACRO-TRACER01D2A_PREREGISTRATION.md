# F-MACRO-TRACER01-D2A — activation + matrix + IC forward-comparison preregistration

Date: 2026-10-01

Status: PREREGISTERED_SINGLE_PARAMETER_CALIBRATION / MB_DISABLED_FOR_IDENTIFIABILITY_STAGE

## Purpose

Test the first process-complete subset of the frozen RFM tracer composition:

    publication forcing
      -> RFM surface activation
      -> matrix source -> SWAP5 Richards -> TRACER01 matrix tracer
      -> preferential source -> IC endpoint tracer
      -> sampled 10-cm profile

This stage deliberately fixes:

    f_MB = 0

so only one parameter is calibrated:

    sigma_B

The purpose is to determine whether the activation-plus-IC mechanism can explain
the observed retained bromide depth profile before introducing the still
unqualified MB wall-retention process.

## Frozen quantities

Publication authority:

    duration = 2.5 h
    intensity = 11.1 mm/h
    simulation/drainage horizon = 1 day
    Ks = 2.50e-6 m/s
    theta_s = 0.40
    theta_r = 0.04
    alpha = 1.9 1/m
    n = 1.25
    Mualem l = 0.5

Initial state:

    central D1S member
    theta(z) = 0.274 throughout 0-1 m

The D1S envelope already showed that the unknown deep theta profile has
negligible effect relative to the observed depth discrepancy. This central
member is therefore the calibration carrier; no initial theta is fitted.

Connectivity:

    p = 0.249

frozen exclusively from Spechtacker Profile 1 evidence already established by
ALT51/ALT52.

MB:

    f_MB = 0

for this identifiability stage only. This is not a claim that MB is absent in
the field.

## Coupled surface/matrix rule

At every accepted hydrologic step during irrigation:

1. derive K_surface and S_surface from the current accepted SWAP5 matrix state
   through the existing RFM research adapter;
2. evaluate frozen unponded activation with the candidate sigma_B;
3. send only q_matrix to the existing SWAP5 dynamic top-boundary owner;
4. keep q_preferential outside matrix hydrology;
5. after hydrology acceptance, reconstruct internal matrix transfers with
   TRACER01-C and commit TRACER01-A;
6. route the integrated preferential tracer mass to IC endpoint bins with
   p=0.249.

If accepted ponding appears while source is active, the run fails closed rather
than inventing a ponded RFM split.

## Calibration grid

Evaluate without adaptive tuning:

    sigma_B =
      0.10, 0.20, 0.30, 0.40, 0.50,
      0.60, 0.70, 0.80, 0.90, 1.00,
      1.20, 1.40, 1.60, 1.80, 2.00

Choose the single grid member with minimum Profile-1 normalized depth-mass SSE.

No other parameter may be changed in response to Profile 1.

## Observations

Use the source-backed `brspecht.dat` operator from ALT51:

    Profile 1 = columns 1-10
    Profile 2 = columns 11-20
    10 equal 10-cm depth bins

Only derived normalized depth-mass vectors are used in the comparison.

Profile 1 is calibration.

Profile 2 is held out and receives the selected sigma_B with no refitting.

## Metrics

For every sigma_B:

- tracer ledger residual;
- source partition closure;
- preferential fraction;
- normalized final profile;
- profile centroid;
- Profile-1 R2 and RMSE;
- Profile-2 R2 and RMSE as diagnostic only.

After selecting sigma_B:

- report Profile-1 calibration metrics;
- report Profile-2 held-out metrics;
- report predicted retained/recovered fraction under f_MB=0.

## Decision rules

D2A passes if:

1. all mass/partition ledgers close at <=1e-10 relative/absolute scale;
2. no unresolved hydrology or ponding-owner failure occurs for the selected run;
3. Profile 1 has R2 >= 0.90;
4. frozen selected sigma_B gives Profile 2 R2 >= 0.90.

If shape transfer passes but recovery remains incompatible with 95%, D2A
qualifies the activation+IC subset and explicitly motivates D2B MB/recovery
work.

If Profile 1 cannot reach R2 >=0.90, the current activation+IC route is
falsified for this case before MB is introduced.

If Profile 1 passes and Profile 2 fails <0.90, within-site held-out
transferability is falsified.

## Exclusions

No dispersion.
No MB wall exchange in D2A.
No fitting of p.
No fitting of initial theta.
No event-specific geometry.
No f_MB residual balancing.
No production source changes.
