# F-MACRO-TRACER01-D1S — publication-case initial-state sensitivity preregistration

Date: 2026-10-01

Status: PREREGISTERED_SENSITIVITY / NOT_EXACT_REPLAY

Case family: SPECHTACKER_PUB_SENS

## Purpose

Quantify whether the publication-faithful SWAP5 matrix hydrology and
no-dispersion conservative tracer result is robust to the unobserved deep
initial theta(z) state.

This work unit explicitly gives up the claim of an exact Spechtacker replay.

## Frozen publication authority

Use only the publication-authority values:

    irrigation duration = 2.5 h
    irrigation intensity = 11.1 mm/h
    theta(upper 15 cm macrostate anchor) = 0.274
    Ksat = 2.50e-6 m/s
    theta_s = 0.40
    theta_r = 0.04
    alpha = 1.9 1/m
    n = 1.25
    Mualem l = 0.5

No echoRD hydraulic or initial-state value may enter this case family.

No roots, drainage, subsurface irrigation or macropore hydrology.

## Initial-state sensitivity family

Use a 10-layer, 10-cm matrix domain to 1 m.

The first two solver layers are fixed at theta=0.274 as the operational
representation of the source-backed upper-15-cm macrostate.

Below 20 cm, define a linear depth trend ending at 1 m at one of:

    theta_1m = 0.234
               0.254
               0.274
               0.294
               0.314

The central member is vertically uniform at 0.274.

The +/-0.04 end-member spread is a deliberate stress envelope, not a
confidence interval. It corresponds in magnitude to roughly two times the
reported ~0.02 upper-layer spatial standard deviation, but that horizontal
variability is NOT reinterpreted as a measured vertical distribution.

No member is called the observed profile.

## Hydrology and tracer execution

For every member:

1. run the canonical reference Richards binding with macropore_active=false;
2. use accepted start/end theta plus qtop/qbot only;
3. reconstruct internal accepted net interface fluxes with TRACER01-C;
4. drive TRACER01-A with those packets;
5. use conservative unit tracer concentration in admitted matrix irrigation;
6. publish exact water/tracer ledger diagnostics.

Use the publication forcing for 2.5 h and simulate to 1 day.

## Numerical setting

Primary sensitivity runs:

    nominal accepted timestep = 120 s

D1 has already qualified 120 -> 60 -> 30 s convergence for the composition
chain. If any sensitivity member shows retries, closure degradation or a
qualitatively exceptional profile, rerun that member at 60 s before
interpretation.

## Metrics

For each member record:

- accepted packet count and retries;
- tracer input, output, retained mass and residual;
- maximum observer bottom-flux residual;
- final tracer mass by 10-cm layer;
- fraction below 20 cm;
- fraction below 50 cm;
- bottom tracer export.

Across the envelope compute:

    L1_max_to_central
    range(fraction_below_20cm)
    range(fraction_below_50cm)
    range(bottom_export)

## Decision rules

Sensitivity is considered sufficiently bounded for proceeding to a cautious
RFM composition study if all members:

1. close tracer mass at <=1e-10 absolute residual;
2. close observer bottom flux at the already qualified numerical scale;
3. converge without unresolved solver failure;
4. retain the same qualitative matrix-only conclusion;
5. show no envelope member whose deep-profile shift alone can mimic the
   observed preferential-depth signal to a degree that destroys parameter
   attribution.

If rule 5 fails, D2 remains blocked by initial-state non-identifiability.

If rules 1-4 pass and rule 5 passes, D2 may proceed only as
SENSITIVITY-CONDITIONED empirical comparison, never as exact replay.

## Frozen exclusions

No dispersion.
No new RFM physics.
No f_MB residual balancing.
No fitting of initial theta to bromide observations.
No echoRD initial profile in this publication-case envelope.
