# F-MACRO-TRACER01-D0 — Spechtacker source-authority reconciliation

Date: 2026-10-01

Status: EXPERIMENT_AUTHORITY_FROZEN / ECHORD_FIXTURE_SEPARATED

Branch: research/f-macro-tracer01-reference-kernel

## Purpose

Resolve conflicting Spechtacker forcing/hydraulic values before any SWAP5 bromide forward run.

## Experimental authority

The peer-reviewed HESS Spechtacker experiment table is the authority for the empirical replay target.

Frozen publication values:

    irrigation duration = 02:30 h
    irrigation intensity = 11.1 mm/h
    bromide concentration = 0.165 kg/m3
    reported bromide recovery = 95%
    initial soil moisture at 15 cm = 0.274
    matrix Ksat = 2.50e-6 m/s
    theta_s = 0.40
    theta_r = 0.04
    alpha = 1.9 1/m
    n = 1.25

The publication also reports:

    macropore count = 16
    representative macropore diameter = 0.005 m
    structural depth classes 1.0 / 0.8 / 0.5 m
    fractions 0.13 / 0.19 / 0.68.

## echoRD fixture values

The open echoRD Spechtacker testcase contains a distinct model fixture.

Its irrigation file gives:

    total = 0.021 m
    tstart = 200 s
    tend = 4880 s

which implies a different effective block intensity/duration from the publication experiment.

Its matrix fixture uses:

    Ksat = 3.4e-6 m/s
    theta_s = 0.46
    theta_r = 0.06
    alpha = 1.50 1/m
    n = 1.36
    Mualem l = 0.5

and supplies a depth-varying initial theta profile.

These values are useful as an echoRD software/testcase fixture but are not treated as the empirical Spechtacker replay authority.

## No hybrid case

TRACER01-D forbids mixing publication forcing with echoRD fixture hydraulics or vice versa while calling the result an empirical replay.

Two named cases are allowed:

    SPECHTACKER_PUB
        publication forcing + publication hydraulic averages

    SPECHTACKER_ECHORD_FIXTURE
        echoRD forcing + echoRD hydraulics + echoRD initial theta

Only SPECHTACKER_PUB may be compared quantitatively to the 95% published recovery as an empirical replay target.

## Remaining initial-state limitation

The publication table exposes initial water content at 15 cm but not a full 0-1 m initial theta profile for Spechtacker.

Therefore a full publication-authority SWAP5 trajectory is not yet uniquely specified below the measured 15-cm state.

Until a deeper observed initial-state profile is found, publication-authority runs must be labeled sensitivity/anchor runs rather than exact experiment replay.

## Decision

    PUBLICATION_FORCING = EMPIRICAL_AUTHORITY
    PUBLICATION_HYDRAULICS = EMPIRICAL_AUTHORITY
    ECHORD_FIXTURE = SEPARATE_COMPARATOR
    HYBRID_PARAMETER_CASE = FORBIDDEN
    EXACT_PUB_REPLAY = BLOCKED_ON_FULL_INITIAL_THETA_PROFILE

## Next

Build SPECHTACKER_ECHORD_FIXTURE first as a software composition qualification because it is fully specified.

In parallel, search the original experiment/source material for the full publication Spechtacker initial moisture profile.

Do not use the fixture result as empirical RFM validation.
