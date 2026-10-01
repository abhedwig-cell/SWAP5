# F-MACRO-EMP01 — empirical qualification regime authority

Date: 2026-10-01

Status: EMPIRICAL_REGIME_AUTHORITY_FROZEN / RFM_PHYSICS_UNCHANGED

Canonical authority:

    integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

Research starting point:

    F-MACRO-TRACER01-D closed with:
      Profile-1 forward comparison pass
      Profile-2 held-out pass
      recovery-bound consistency pass
      sigma_B absolute magnitude not identified
      f_MB not identified

## Purpose

Prevent empirical qualification from mixing observables that belong to different
hydraulic boundary regimes or different points in the preferential-flow chain.

The frozen RFM-minimal parameter roles remain:

    sigma_B  = unponded/source-controlled surface activation heterogeneity
    f_MB     = persistent continuous/deep fraction of preferential input
    p        = terminating-path depth/connectivity shape

No parameter role is changed by EMP01.

## Four empirical regimes

### 1. Unponded/source-controlled activation

Primary evidence:

    NEON PF v1.1
    Spechtacker publication experiment

Admissible questions:

    event ordering
    activation transferability
    quantitative preferential-entry fraction if directly observed

The current RFM sigma_B definition belongs only here.

### 2. Ponded/head-controlled infiltration

Primary quantitative evidence:

    Zhang et al. (2022), Geoderma 428, 116205
    DOI 10.1016/j.geoderma.2022.116205

The experiment maintains a 5-cm water head in double-ring infiltrometers and
measures steady infiltration.

This regime is not allowed to calibrate sigma_B because sigma_B belongs to the
unponded/source-controlled activation law.

Ponded PFIR/SIR is instead used as a boundary-regime falsification/qualification
target for any future explicit ponded preferential-flow owner.

### 3. Downstream fast-routing receipt

Primary evidence:

    HILLSCAPE / Maier-van-Meerveld 2021

Observation:

    same-event shallow subsurface-flow receipt fraction

This constrains a composite of fast entry and routing/capture. It is not equal
to sigma_B or f_MB.

### 4. Morphology/depth response

Primary evidence:

    GFZ/Hartmann 2024
    Spechtacker/Colpach conservative tracer depth profiles

GFZ visible dye morphology is retained as qualitative/depth evidence only.
The direct stained-fraction-to-connectivity operator was falsified in ALT49.

Conservative tracer depth mass remains the stronger quantitative p evidence.

## Hard exclusions

- no ponded PFIR/SIR calibration of sigma_B;
- no binary NEON PF label calibration of sigma_B magnitude;
- no HILLSCAPE trench receipt interpreted as f_MB;
- no dye stained area interpreted as preferential-water volume;
- no post-hoc observation model introduced to rescue parameter identifiability;
- no RFM physics change during empirical qualification.

## Qualification objective

EMP01 and successors shall separate:

    model-form validation
    parameter identifiability
    boundary-regime applicability
    downstream-routing applicability
    observation-process limitations

A dataset may strongly qualify one of these while being invalid for another.
