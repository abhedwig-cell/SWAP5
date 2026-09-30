# F-MACRO-ALT04 — dynamic-geometry state necessity result

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_RESULT / DYNAMIC_VOLUME_DERIVABLE / DOMAIN_INDEX_OPEN`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Question

Which parts of legacy macropore geometry are independent continuation state, and which are deterministic functions of accepted matrix state plus immutable configuration?

Primary legacy candidates:

- `VlMpDyCp`: dynamic macropore volume per compartment;
- `VlMpDmCp`: total macropore volume per domain and compartment;
- `ICpBtDm`: current bottom compartment of a domain.

## Theory authority

The SWAP macropore theory defines dynamic macropore volume as shrinkage-generated volume.

For a compartment, dynamic volume is calculated from overall matrix shrinkage and vertical subsidence, corrected for the static macropore fraction. Schematically:

```text
V_dy = (1 - V_st) * (V_sh - V_su) / (1 - V_su)
```

where `V_sh` and `V_su` follow the soil shrinkage characteristic and the current soil moisture condition.

The official theory explicitly states that:

- static macropore volume is permanent;
- dynamic macropore volume depends on soil moisture status;
- static and dynamic volume together form total macropore volume;
- continuity/bottom-depth distribution and horizontal distribution are configuration/topology properties applied to the total volume.

## ALT04-A — dynamic-volume state

### Result

For fixed:

- soil profile and layer identity;
- shrinkage-characteristic parameters;
- static macropore geometry;
- current accepted matrix moisture state;

the current dynamic macropore volume is deterministic.

Therefore:

```text
VlMpDyCp_current
    = G(theta_current, shrinkage_config, static_geometry)
```

and is not an independent material-history degree of freedom in the published formulation.

### Previous-step geometry in the discrete balance

Legacy code also uses previous-step macropore volume in terms such as:

```text
(VlMpDmCp_current - VlMpDmCpM1) / dt
```

This does not by itself make geometry an independent persistent state.

At a transactional step boundary SWAP5 already owns the accepted matrix state at `t_n`. If geometry is deterministic from that accepted matrix state, then:

```text
V_mp^n     = G(theta^n, config)
V_mp^{n+1} = G(theta_candidate^{n+1}, config)
```

and the volume-change term can be reconstructed exactly from accepted and candidate matrix states.

Thus a previous-geometry array is potentially a cache/reference convenience rather than irreducible physical continuation state.

### Decision

```text
ALT04_DYNAMIC_VOLUME_INDEPENDENT_MEMORY = FALSIFIED_BY_MODEL_DEFINITION
ALT04_DYNAMIC_VOLUME_DERIVABLE = SUPPORTED
```

Production removal still requires exact source replay to prove no additional hidden use.

## ALT04-B — total domain volume

Published geometry separates:

1. total static + dynamic volume;
2. vertical continuity/domain distribution.

If the domain fractions/distribution are immutable configuration, then total per-domain/per-compartment volume is also derivable:

```text
VlMpDmCp = distribute(V_static + V_dynamic, connectivity_config)
```

This is the leading hypothesis and is strongly supported by the theory description.

However exact B1.11 source trace is still required before claiming every legacy `VlMpDmCp` use is reconstructable without stored state.

Current status:

```text
ALT04_TOTAL_DOMAIN_VOLUME = DERIVABLE_HYPOTHESIS_STRONGLY_SUPPORTED
```

## ALT04-C — ICpBtDm

`ICpBtDm` is different.

The retained source labels it as the compartment containing the current bottom depth of a domain. It is also compared with `ICpBtDmM1` during state reconstruction when a domain bottom becomes shallower.

The currently recovered theory establishes an immutable functional bottom-depth distribution for macropore connectivity, but does not yet prove that this particular runtime index is solely configuration-derived.

It may encode a current active/hydraulic extent rather than only immutable structural topology.

Therefore:

```text
ALT04_ICPBTDM_DERIVABLE = OPEN
```

It must not be removed based on the dynamic-volume result.

## Revised reduced-state architecture

The leading research architecture is now:

```text
PERSISTENT PHYSICAL/HISTORY
    fast-domain water/storage
    Philip event sorptivity
    Philip event age
    [runtime domain-bottom/active-extent state only if ALT04-C proves necessary]

DERIVED FROM ACCEPTED/CANDIDATE MATRIX STATE + CONFIG
    dynamic shrinkage volume
    total macropore volume candidate
    previous-step geometry for balance
    likely wet-wall fraction / within-step contact geometry

WORKER-LOCAL SCRATCH
    SATFLOW / ABSORPTION / RAPIDDRAIN rate/Jacobian workspace

IMMUTABLE CONFIGURATION
    static macropore volume
    structural connectivity distribution
    shrinkage characteristics
    polygon/horizontal geometry parameters
```

## Architectural implication

This result strengthens SWAP5 invariants:

- compact persistent state;
- explicit data separation;
- transactional recomputation from accepted state;
- optional functionality scales with active columns;
- worker scratch remains separate from physical state.

It also suggests that persisting large geometry arrays simply because legacy code stores them would reproduce implementation history rather than model necessity.

## Next step

F-MACRO-ALT04C should isolate `ICpBtDm` and related active-bottom/topology indices.

The decisive question is whether, at equal:

- matrix state;
- fast-domain water distribution;
- immutable connectivity geometry;
- dynamic volume;

two distinct valid values of `ICpBtDm` can lead to distinct future physical response.

If no, derive the index on demand.
If yes, identify the physical sufficient statistic it represents rather than carrying the legacy index by default.
