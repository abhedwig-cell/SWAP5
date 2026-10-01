# F-MACRO-TRACER01-D — closure

Date: 2026-10-01

Status: CLOSED_ON_QUALIFIED_D1_AND_EMPIRICAL_INITIAL_STATE_BLOCKER

Branch: `research/f-macro-tracer01-reference-kernel`

Canonical SWAP5 authority:

    integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

Research recovery point before closure:

    research/f-macro-tracer01-reference-kernel@399fb27a3723a1e0cc868880ca0738e0222a57be

## Closure basis

TRACER01-D1 has satisfied the software-composition gate for the fully specified
`SPECHTACKER_ECHORD_FIXTURE`.

The qualified chain is:

    SWAP5 reference Richards solver
      -> accepted start/end theta and qtop/qbot
      -> TRACER01-C reconstructed internal net interface fluxes
      -> TRACER01-A conservative donor-cell matrix tracer

No production SWAP5 source was modified.

No HeadCalc-internal flux array was used.

No RFM, MB, IC, dispersion, diffusion, sorption or reaction term was added.

## Qualified D1 result

The 120 s baseline run produced:

    accepted hydrology packets = 72
    solver retries = 0
    integrated tracer input = 2.099916
    final matrix tracer mass = 2.099916
    global tracer residual ~= 8.9e-16
    maximum per-step tracer residual ~= 4.4e-16
    maximum reconstructed-water mismatch ~= 2.2e-15 cm
    maximum bottom-flux reconstruction residual ~= 1.8e-12 cm/day

The preregistered timestep-refinement gate also passed:

    L1_120_60 = 0.0015162192486311466
    L1_60_30  = 0.0007659631795578947

with identical integrated tracer input for 120 s, 60 s and 30 s runs and
floating-point-scale tracer closure in all runs.

Therefore:

    REAL_SWAP5_MATRIX_HYDROLOGY_COMPOSITION = QUALIFIED
    ACCEPTED_PACKET_OBSERVER_CHAIN = QUALIFIED
    MATRIX_TRACER_MASS_CLOSURE = QUALIFIED
    TIMESTEP_REFINEMENT_STABILITY = QUALIFIED

## Empirical Spechtacker publication case

The authority split from TRACER01-D0 remains binding.

`SPECHTACKER_PUB` may use only publication forcing, publication hydraulic
parameters and publication-authority initial-state evidence.

The publication-backed material currently provides the initial water content
near 15 cm but not a complete 0-1 m initial theta profile.

A targeted repository search at closure for:

    Spechtacker
    0.274
    initial theta Spechtacker

did not locate an additional source-backed publication initial profile.

No echoRD fixture profile may be substituted into the publication case because
that would create the explicitly forbidden hybrid replay.

Therefore:

    EXACT_SPECHTACKER_PUB_REPLAY = BLOCKED
    BROMIDE_FORWARD_COMPARISON_AS_EXACT_REPLAY = BLOCKED
    PROFILE2_HELD_OUT_FORWARD_VALIDATION = BLOCKED

This is an empirical initial-state authority blocker, not a matrix-tracer
software-composition failure.

## Why D2 does not start here

Frozen RFM composition requires a publication-faithful matrix hydrology
trajectory before interpreting Profile 1, Profile 2 and 95% recovery jointly.

Starting D2 now would force one of three invalid moves:

1. import the echoRD initial profile into `SPECHTACKER_PUB`;
2. fit RFM parameters against a hydrological initial condition not supported by
   the publication authority;
3. use `f_MB` or another preferential parameter to absorb initial-state
   uncertainty.

All three violate the frozen authority and identifiability rules.

No D2 preregistration is therefore created.

## Dispersion decision

The no-dispersion baseline did not fail its software-composition or timestep
stability gates.

Accordingly:

    DISPERSION_EXTENSION = NOT_AUTHORIZED

Any later dispersion term requires a separately qualified empirical
no-dispersion failure, not merely visual disagreement.

## Resume condition

Resume TRACER01-D2 only after one of the following is persisted:

1. source-backed full Spechtacker publication initial theta(z) over the modeled
   profile; or
2. a preregistered publication-case initial-state sensitivity envelope that
   explicitly gives up the claim of exact replay.

The second route may support sensitivity/robustness analysis, but must not be
reported as an exact Spechtacker replay.

## Final work-unit state

    D1_SOFTWARE_COMPOSITION = QUALIFIED
    D1_TIMESTEP_REFINEMENT = PASS
    EXACT_EMPIRICAL_REPLAY = BLOCKED
    D2_RFM_FORWARD_COMPOSITION = NOT_STARTED_BY_DESIGN
    HELD_OUT_PROFILE2_FORWARD_VALIDATION = BLOCKED
    NEW_RFM_PHYSICS = NONE
    PRODUCTION_CODE_CHANGE = NONE
    STOP_RULE = TRUE_EMPIRICAL_AUTHORITY_BLOCKER

This work unit closes at a valid stop condition.
