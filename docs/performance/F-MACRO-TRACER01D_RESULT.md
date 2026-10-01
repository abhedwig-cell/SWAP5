# F-MACRO-TRACER01-D — SWAP5 accepted-hydrology to disposable tracer-kernel composition

Date: 2026-10-01

Status: SOFTWARE_COMPOSITION_QUALIFIED / TIMESTEP_REFINEMENT_PASS / EMPIRICAL_REPLAY_NOT_YET_CLAIMED

Research branch: research/f-macro-tracer01-reference-kernel

Canonical SWAP5 authority:
    integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

## Purpose

Demonstrate that the disposable TRACER01-A conservative matrix-tracer kernel can be driven by accepted SWAP5 matrix hydrology through the TRACER01-C accepted-state flux observer.

## Case boundary

This run uses the fully specified echoRD Spechtacker fixture:

    SPECHTACKER_ECHORD_FIXTURE

with its own forcing, hydraulic parameters and depth-varying initial theta.

It is a software-composition qualification only.

It is NOT the empirical publication-authority Spechtacker replay.

The publication-authority case remains separately frozen in TRACER01-D0.

## Chain executed

    SWAP5 reference Richards solver
      -> accepted start/end theta
      -> accepted qtop / qbot
      -> TRACER01-C internal net-flux reconstruction
      -> TRACER01-A conservative donor-cell matrix tracer

No HeadCalc internal flux array is read.

No production source code is modified.

## Baseline 120-s run

Accepted hydrology packets:

    72

Solver retries:

    0

Integrated tracer input:

    2.099916

External tracer output over the short fixture horizon:

    0

Final matrix tracer mass:

    2.099916

Global tracer residual:

    ~8.9e-16

Maximum TRACER01-A per-step tracer residual:

    ~4.4e-16

Maximum reconstructed-water mismatch:

    ~2.2e-15 cm

Maximum TRACER01-C bottom-flux reconstruction residual:

    ~1.8e-12 cm/day.

## Baseline tracer profile

At the fixture sampling horizon the advection-only matrix reference retains tracer almost completely in the upper profile:

    0-10 cm   ~1.71449
    10-20 cm  ~0.38367
    20-30 cm  ~0.00176
    below 30 cm ~0

on the arbitrary unit-concentration tracer basis used for the software composition test.

This is not compared to field bromide observations because the fixture forcing/hydraulics are not the publication-authority experiment.

## Timestep-refinement gate

The forcing boundary is split exactly so all refinement runs receive identical integrated input:

    tracer input = 2.099916

for:

    120 s
     60 s
     30 s.

Accepted packets:

    120 s -> 72
     60 s -> 144
     30 s -> 287

with zero solver retries in all three runs.

Normalized final-profile L1 changes:

    L1_120_60 = 0.001516
    L1_60_30  = 0.000766

Thus the change approximately halves under timestep refinement and the 60->30 s change is well below the preregistered 2% research-reference tolerance.

All three tracer ledgers close at floating-point scale.

## Important harness correction

An intermediate refinement attempt initially allowed one timestep to straddle the exact irrigation-end boundary, producing slightly different integrated input between timestep choices.

That run was rejected as qualification evidence.

The final qualified run snaps/splits exactly at the forcing event boundary before comparing timesteps.

## What is now qualified

    SWAP5 accepted matrix hydrology
      -> balance-reconstructed internal net flux
      -> ordered research transfer packet
      -> conservative matrix tracer

is executable, mass-conservative and timestep-stable on the fully specified software fixture.

## What remains open

The exact publication-authority Spechtacker experiment cannot yet be replayed without an assumption on the initial 0-1 m matrix water-content profile.

The publication reports the initial 15-cm water content but not a complete vertical profile for Spechtacker.

Therefore:

    exact empirical PUB replay = BLOCKED on full initial hydraulic state.

Do not substitute the echoRD fixture profile into the publication case.

## Decision

    TRACER01_A_REFERENCE_KERNEL = QUALIFIED_FOR_RESEARCH_COMPOSITION
    TRACER01_C_FLUX_OBSERVER = QUALIFIED_ON_REAL_SWAPS_SOLVES
    FIXTURE_COMPOSITION = PASS
    TIMESTEP_REFINEMENT = PASS
    DISPERSION_EXTENSION = NOT_JUSTIFIED_BY_SOFTWARE_GATE
    EMPIRICAL_SPECHTACKER_REPLAY = NOT_YET_CLAIMED

## Next

Two valid next routes remain:

1. obtain the full observed/preprocessed Spechtacker initial moisture profile and execute the frozen publication-authority replay;
2. if that profile cannot be recovered, preregister an initial-state sensitivity envelope around the observed 15-cm theta rather than claiming an exact replay.

Only after one of those routes is frozen should RFM MB/IC tracer composition be fitted to the observed bromide profiles and 95% recovery.
