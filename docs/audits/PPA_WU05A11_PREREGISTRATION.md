# PPA-WU05-A11 preregistration — bounded RFM unponded activation service

Date: 2026-10-01

Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS

Baseline:

    integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

Research authorities:

    F-MACRO-ALT08
    F-MACRO-ALT30
    F-MACRO-ALT34
    F-MACRO-ALT46
    F-MACRO-TRACER01-D
    F-MACRO-EMP01/EMP02

## Purpose

Promote only the already qualified deterministic unponded RFM surface-activation
operator from research code into production source.

A11 is deliberately not a complete RFM macropore runtime.

## Admitted candidate scope

The candidate service accepts explicit interval inputs:

    sigma_B > 0
    matrix surface conductivity K >= 0
    surface sorptivity S >= 0
    nonnegative source rate R
    nonnegative event age
    nonnegative ponding depth

For unponded source-controlled conditions it computes:

    b50 = K + S/(2 sqrt(tau))

and the frozen lognormal distributed-intake partition:

    source = matrix + preferential.

## Hard boundaries

A11 SHALL NOT:

- provide a default sigma_B;
- infer or calibrate sigma_B;
- execute when ponding depth is positive;
- own event-age lifecycle;
- derive K or S from solver state;
- route preferential water by depth;
- introduce f_MB, p or chi_wall;
- mutate physical state;
- change A8/A9/A10 top-input ownership;
- alter restart or transaction payloads;
- change existing production behavior while unused.

Ponded/head-controlled conditions fail closed with an explicit
SURFACE_BOUNDARY_REQUIRED status.

## Qualification gates

The focused gate must prove:

1. exact source partition closure to floating-point tolerance;
2. bounds 0 <= matrix <= source and 0 <= preferential <= source;
3. exact parity with frozen independent oracle fixture:
   
       sigma_B = 0.65
       K = 0.16264 cm/day
       S = 2.92460 cm/sqrt(day)
       R = 4.8 cm/day
       tau = 0.25 day

   expected:

       b50 = 3.08724
       matrix = 3.1439554598512593
       preferential = 1.6560445401487405
       fraction = 0.3450092791976543

4. zero-source identity;
5. positive ponding fails closed;
6. invalid sigma_B fails closed;
7. preferential fraction is monotone nondecreasing over the frozen source-rate
   screen for fixed K/S/tau;
8. no existing runtime file is mutated in A11.

## Exit criteria

One of:

    QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE_RFM_UNPONDED_ACTIVATION_SERVICE
    ORACLE_PARITY_FALSIFIED
    MASS_PARTITION_FALSIFIED
    BOUNDARY_FAIL_CLOSED_FALSIFIED
    TRUE_BLOCKER
