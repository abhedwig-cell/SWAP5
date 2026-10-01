# F-MACRO-ALT52 — held-out conservative-tracer validation of one-shape endpoint mass

Date: 2026-10-01

Status: HELD_OUT_WITHIN_SITE_VALIDATION_PASS / OUT_OF_SYSTEM_FORM_TRANSFER_PASS

Canonical authority: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Purpose

Turn ALT51 from retrospective fit evidence into an actual held-out validation.

No RFM equation is changed.

## Preregistered split imposed before result interpretation

The open Spechtacker bromide matrix contains two physically separate vertical profiles:

    Profile 1 = lateral columns 1-10
    Profile 2 = lateral columns 11-20

ALT52 uses:

    Profile 1 = calibration
    Profile 2 = held-out validation

Only p is estimated on Profile 1.

Profile 2 is then predicted with exactly that frozen p.

## Observation-space model

For normalized sampled depth x:

    F_end(x) = x^p

and tracer mass in bin [a,b]:

    m_bin / sum(m)
      = b^p - a^p.

No amplitude or depth-specific correction is fitted after normalization.

## Calibration

Spechtacker Profile 1:

    p_cal = 0.249
    R2_cal ~ 0.985

This reproduces ALT51.

## Held-out validation

Using exactly:

    p = 0.249

for Spechtacker Profile 2:

    R2_holdout ~ 0.975
    RMSE ~ 0.0276 of normalized mass per 10-cm bin.

The held-out profile independently preferred p ~0.219 in ALT51, but no refitting is required to obtain a strong validation fit.

This is a materially stronger result than two independent best fits.

## Out-of-system form transfer

The independent Colpach/Attert bromide testcase uses:

- a different catchment/soil;
- different forcing;
- 5-cm instead of 10-cm depth bins;
- five lateral cells.

The endpoint law is not changed.

A profile-specific p is allowed because p is explicitly a structural-profile parameter in RFM-RC1.

Best Colpach result:

    p_eff ~ 0.385
    R2 ~ 0.902.

Therefore the one-shape endpoint-mass form transfers to another experiment while the structural parameter value changes.

## Interpretation

This is now the strongest empirical evidence in the alternative macropore line for retaining a one-parameter terminating-path depth distribution.

The evidence hierarchy is:

1. dye stained-area proportionality:
   
       rejected as a general observation operator (ALT49);

2. conservative bromide retained-mass depth profile:
   
       strong fit (ALT51);

3. held-out conservative bromide profile with p frozen:
   
       strong validation (ALT52);

4. different soil/catchment:
   
       same form remains useful with a different p.

This strongly supports keeping:

    C_struct(x) = 1 - x^p

as the leading reduced IC connectivity hypothesis.

## Important boundary

ALT52 validates the endpoint-mass observation form, not the complete RFM tracer process.

A full process simulation still needs:

- surface activation;
- MB/IC split;
- event routing;
- wall exchange;
- sampling-time matrix retention.

Those processes may bias p_eff relative to the underlying structural p.

Therefore ALT52 promotes p identifiability but does not authorize assigning:

    p_structural := p_eff

without a full forward tracer-routing check.

## Decision

    ONE_SHAPE_ENDPOINT_MASS = HELD_OUT_VALIDATED
    SPECHTACKER_p_WITHIN_SITE_TRANSFER = PASS
    COLPACH_ENDPOINT_FORM_TRANSFER = PASS
    DIRECT_DYE_OPERATOR = REMAINS REJECTED
    p_AS_LEADING_CONNECTIVITY_PARAMETER = STRENGTHENED
    p_eff_EQUALS_STRUCTURAL_p = STILL A FORWARD-MODEL QUESTION

## Next

The p-line no longer needs another empirical shape search.

The next unresolved quantitative parameter is f_MB.

Investigate whether applied-versus-recovered bromide mass closure can be reconstructed from the original Weiherbach/Colpach experiments. Only if absolute mass closure is source-supported may missing/deep tracer be used to constrain f_MB.
