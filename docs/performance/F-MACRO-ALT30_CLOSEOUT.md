# F-MACRO-ALT30 — final reduced RFM parameter contract and research closeout

Date: 2026-10-01

Status: QUALIFIED_RESEARCH_CONTRACT / PARAMETER-REDUCTION_PHASE_CLOSED

Baseline: integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b

## Purpose

Close the parameter-reduction phase by freezing the smallest RFM parameter contract currently supported by the analytical, standalone and external-evidence work from ALT01-ALT29.

## Final leading modes

### RFM-minimal

Free high-level parameters:

    sigma_B
    f_MB
    p

with:

    ell_ex derived from measured/profile structural geometry
    chi_wall = 1
    K_surface and S_surface derived from constitutive hydraulics
    Z_AH and Z_IC derived/observed from profile structure

This is the preferred first-principles research mode.

### RFM-wall-corrected

Free high-level parameters:

    sigma_B
    f_MB
    p
    chi_wall

with ell_ex still derived independently.

This mode is justified only when evidence supports wall repellency or reduced hydraulic contact that ordinary matrix hydraulics do not represent.

## Parameter roles and minimum evidence

sigma_B — surface matrix-infiltrability heterogeneity. Qualification requires multiple events on the same structural profile spanning weak through intense effective infiltration. Event-specific sigma_B is forbidden.

f_MB — persistent continuous/deep pathway fraction. Qualification requires deep receipt, drainage, bottom breakthrough or conservative tracer information. It must not be used to compensate surface activation errors.

p — one-shape terminating connectivity parameter in C(z)=1-x^p. Qualification requires multi-depth evidence such as dye coverage/depth, wetting-front arrival or tracer profiles. Geometry remains fixed across events within a structural class.

chi_wall — optional wall/contact efficiency. It is only estimable meaningfully after ell_ex is independently constrained, and ideally requires both dry Philip-dominated and wet Darcy-dominated exchange evidence.

## Derived quantities

The leading contract does not calibrate the following by default:

    Z_AH
    Z_IC
    K_surface
    S_surface
    ell_ex
    active connectivity
    dynamic macropore volume
    total macropore volume
    active bottom index
    wet-wall/contact fraction

These are profile observations, constitutive calculations or deterministic derived quantities.

## State contract

Persistent information roles are reduced to:

    fast-domain water storage
    S_wall,event
    tau_wall,event
    tau_surface

with all rate/Jacobian/connectivity views remaining candidate or worker-local scratch.

## Comparison with current SWAP user burden

The current SWAP macropore route exposes a broad geometry and process input surface including static depths and volume fractions, MB/IC partitioning, explicit IC subdomain count, frequency-distribution controls, shallow/deep polygon diameters and their depth variation, ponding threshold, exchange shape factor, shrinkage controls, and selectable sorptivity parameterisations. The official case input includes Z_ST, Z_IC, VLMPSTSS, NUMSBDM, DIPOMI, DIPOMA, PPICSS, optional Z_AH/RZAH/POWM/SPOINT/SWPOWM, SHAPEFACMP and sorptivity controls, in addition to layer-wise shrinkage inputs.

RFM does not claim that every one of those physical phenomena is irrelevant. It collapses their preferential-flow information into fewer roles where the evidence supports doing so and delegates ordinary surface hydraulics/shrinkage to their existing owners.

## Burden verdict

RFM-minimal has three free high-level preferential-flow parameters.

RFM-wall-corrected has four.

This does not count ordinary matrix hydraulic parameters, profile horizon depths or independently measured structural geometry because they are already part of the soil/profile description rather than extra preferential-flow calibration knobs.

The result is therefore a substantial reduction in user-facing preferential-flow parameter burden relative to the current advanced SWAP macropore input surface.

## Scientific caveats

Three parameters are not automatically enough for every soil. The current evidence supports this as the smallest leading research hypothesis, not as a universal truth.

The most important unresolved empirical risks are:

1. fixed sigma_B may be insufficient where event-dependent spatial moisture heterogeneity dominates;
2. one-shape connectivity p may fail with richer high-resolution depth data;
3. chi_wall=1 may fail in water-repellent or coated macropore walls;
4. measured ell_ex may not equal the effective continuum exchange length without bias;
5. the ponding/runoff/sealing transition still needs full composition with the accepted surface-boundary owner.

## Runtime claim

The architecture is computationally promising because activation is closed-form, connectivity is one-dimensional and active-sized, and no second Richards domain is introduced. However, no end-to-end SWAP5 runtime speedup is qualified yet.

## Production boundary

RFM remains an alternative research physical option. It is not a replacement for the current reference route and is not production-admitted.

The production macropore migration remains governed independently by PPA-WU05-A and its exact-source, state, transaction and admission sequence.

## Parameter-reduction phase verdict

    leading minimal free core = sigma_B, f_MB, p
    optional wall correction = chi_wall
    exchange length = derive from structure
    empirical sorptivity pair = removed
    explicit multiple IC subdomains = removed
    free R_AH = removed
    two-shape connectivity = fallback only

PARAMETER-REDUCTION_PHASE = CLOSED

## Recommended next research phase

Do not simplify further algebraically.

The next phase should be empirical qualification of the frozen contract, followed only then by a source-level SWAP5 research adapter.

Minimum decisive experiment:

- one structural soil/profile;
- multiple effective rainfall/input intensities and event durations;
- contrasting antecedent states;
- multi-depth response or conservative tracer data;
- independently measured macropore/ped geometry for ell_ex;
- held-out events with no parameter retuning.

A successful held-out test would justify promoting RFM from a coherent reduced hypothesis to a qualified alternative physical model candidate.
