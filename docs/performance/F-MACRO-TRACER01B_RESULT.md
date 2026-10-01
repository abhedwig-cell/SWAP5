# F-MACRO-TRACER01-B — Spechtacker source packet and hydrology-interface qualification

Date: 2026-10-01

Status: SOURCE_PACKET_QUALIFIED / ORDERED_WATER_TRANSFER_INTERFACE_MISSING

Branch: research/f-macro-tracer01-reference-kernel

## Purpose

Determine whether the public Spechtacker/Weiherbach testcase contains enough source-backed hydrology information to drive the TRACER01-A conservative matrix-tracer reference kernel without inventing a surrogate water-transfer trajectory.

## Source-backed inputs available

The public echoRD Weiherbach testcase supplies:

### Irrigation forcing

    tstart = 200 s
    tend   = 4880 s
    total irrigation = 0.021 m
    intensity = 4.487e-06 m/s
    bromide concentration = 1.65e-04 g/m3 in the testcase forcing file

The testcase configuration separately records the published tracer experiment descriptors:

    tracer_appl_Br = 4.19595
    tracer_SD_Br   = 0.3465
    tracer_time    = 2.3
    tracer_intensity = 11.05652174
    tracer_c_br      = 0.165

These values are preserved as source evidence; unit reconciliation between the generic irrigation file and publication/testcase metadata must be explicit before absolute tracer forcing is admitted.

### Initial matrix moisture

The source profile supplies theta by depth:

    0.00 to 0.05 m : 0.3000
    0.05 to 0.15 m : 0.1810
    0.15 to 0.25 m : 0.1878
    0.25 to 0.35 m : 0.2277
    0.35 to 0.45 m : 0.2773
    0.45 to 2.00 m : 0.2773

### Matrix hydraulic parameters

`matrix_specht.dat` contains the profile hydraulic definitions required to construct a source-backed matrix case.

### Bromide observations

`brspecht.dat` supplies two independent vertical bromide profiles, already used in ALT51/52.

## What is missing

TRACER01-A deliberately requires an ordered water-transfer journal:

    external -> layer
    layer -> layer
    layer -> external

plus exact hydrology-owned start/end water storage.

The source observation/configuration files do not contain such a journal.

## Stored echoRD run

The repository contains:

    testcases/specht4y_x2.pickle

and notebooks/results that can reproduce/load an echoRD simulation.

This is useful comparative model evidence, but it is NOT admitted as the hydrology authority for RFM validation because echoRD itself contains preferential-flow/macropore process hypotheses.

Using its simulated water trajectory as the matrix hydrology driver would risk circular/confounded validation:

    RFM tracer result
      conditioned on
    another preferential-flow model's water routing.

TRACER01-B therefore rejects that shortcut.

## Preferred hydrology authority

Use SWAP5 itself as the matrix hydrology owner for the Spechtacker experiment:

    source-backed soil hydraulics
    + source-backed initial theta
    + source-backed irrigation forcing
      -> SWAP5 matrix water solve
      -> ordered interface water-transfer publication
      -> TRACER01-A matrix tracer

This keeps the validation question focused on RFM preferential routing while using the target model's own matrix hydrology.

## Required SWAP5 adapter output

For every accepted hydrology substep:

    start matrix water storage per tracer layer
    ordered vertical water transfer per interface
    explicit surface water input admitted to matrix
    explicit bottom matrix water export
    end matrix water storage per tracer layer

with one accepted-state generation/interval identity.

Rejected SWAP trials must not publish tracer-driving transfers.

## Decision

    SPECHTACKER_SOURCE_FORCING = AVAILABLE
    SPECHTACKER_INITIAL_THETA = AVAILABLE
    SPECHTACKER_MATRIX_HYDRAULICS = AVAILABLE
    SPECHTACKER_BROMIDE_OBSERVATIONS = AVAILABLE
    INDEPENDENT_ORDERED_WATER_TRANSFER_JOURNAL = ABSENT
    ECHORD_SIMULATION_AS_HYDROLOGY_AUTHORITY = REJECTED
    SWAP5_AS_MATRIX_HYDROLOGY_OWNER = REQUIRED

## Next

TRACER01-C should implement a research-only SWAP5 water-transfer observer/adapter.

It must observe accepted matrix hydrology without changing solver physics and emit exactly the ordered transfer packet required by TRACER01-A.

Only after that adapter is qualified should the Spechtacker absolute bromide forward run begin.
