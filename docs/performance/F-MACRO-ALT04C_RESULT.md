# F-MACRO-ALT04C — active domain-bottom state attribution result

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_RESULT / ACTIVE_BOTTOM_DERIVABLE_HYPOTHESIS_STRONGLY_SUPPORTED`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Question

Does legacy `ICpBtDm` carry an independent hydraulic continuation state, or is it a derived index identifying the active bottom compartment of an already-defined macropore domain?

## Source evidence

Recovered source comments define:

- `ICpBtDm`: compartment number containing actual bottom depth of domain;
- `ICpBtDmM1`: compartment number containing bottom depth of domain of previous time step;
- `ICpBtDmPot`: compartment number containing potential bottom depth of domain;
- `ICpTpWaSrDm`: separate top index of water-saturated macropore storage;
- `ZWaLevDm`: separate macropore-domain water level.

This separation is important: `ICpBtDm` is not the macropore water level and not the saturated/unsaturated interface.

The recovered state reconstruction also shows that when `ICpBtDm` becomes shallower, the code redistributes/reconstructs flux/storage over the disappearing lower compartments while separately using `ICpTpWaSrDm` as the hydraulic interface index.

## Theory evidence

The published macropore geometry defines a functional bottom-depth distribution for the MB/IC domains from immutable geometry parameters. For each domain j, `ndb_j` is the model compartment containing that domain's bottom.

The model separately defines dynamic macropore volume from current shrinkage/moisture state.

Therefore there are two distinct concepts:

1. potential/structural domain extent from connectivity geometry;
2. actual currently present macropore extent when dynamic volume may vanish in deeper compartments.

Neither requires an independent hydraulic memory if current macropore volume is itself deterministic from accepted matrix state and configuration.

## Attribution

The most coherent interpretation is:

```text
ICpBtDm
= derived discrete index of the deepest currently active compartment
  within the configured potential domain extent
```

with a rule conceptually equivalent to:

```text
ICpBtDm(j)
= deepest i <= ICpBtDmPot(j)
  for which active domain macropore volume is non-zero / physically present
```

The exact legacy threshold and indexing rule remain source-trace details.

## Why previous-step ICpBtDmM1 need not be independent state

Legacy code compares `ICpBtDm` with `ICpBtDmM1` to handle a domain becoming shallower.

In a transactional architecture:

```text
ICpBtDm^n     = derive(theta^n, config)
ICpBtDm^{n+1} = derive(theta_candidate^{n+1}, config)
```

Thus the previous index is reconstructable from the accepted matrix state at the step boundary if the derivation rule is deterministic.

The fact that legacy stores `ICpBtDmM1` is therefore not by itself evidence of irreducible physical memory.

## Decision

```text
ALT04C_INDEPENDENT_HYDRAULIC_MEMORY = NOT_SUPPORTED
ALT04C_DERIVED_ACTIVE_EXTENT = STRONGLY_SUPPORTED
ALT04C_PRODUCTION_REMOVAL = OPEN_PENDING_EXACT_B1_11_SOURCE_TRACE
```

A production implementation must still recover the exact source rule that maps volume/topology to the active bottom index and prove exact replay over transitions where the domain becomes deeper or shallower.

## Reduced-state consequence

The leading minimal persistent macropore state no longer needs to assume an explicit active-bottom index.

Current research candidate:

```text
PERSISTENT
    fast-domain water/storage
    Philip-event sorptivity
    Philip-event age

DERIVED
    dynamic macropore volume
    total per-domain volume
    active domain-bottom index
    previous-step domain-bottom index from accepted state
    wet-wall fraction / within-step contact geometry

SCRATCH
    rate/Jacobian/intermediate arrays

CONFIGURATION
    potential bottom-depth distribution
    static macropore volume
    shrinkage characteristics
    connectivity and horizontal-geometry parameters
```

## Important caveat

This result addresses state minimality, not whether the existing geometric parameterization itself should be retained.

The broader MACRO-ALT research question remains open: the functional domain-bottom distribution may itself be replaceable by a simpler continuous connectivity representation.

## Next step

F-MACRO-ALT05 should now move from state reduction to parameter reduction.

The highest-value question is whether the legacy multi-domain geometry:

- MB domain;
- IC domain;
- multiple IC subdomains;
- domain-bottom distribution parameters;

can be replaced by a lower-dimensional continuous connectivity function without materially degrading:

- event arrival depth;
- drainage timing;
- bottom flux;
- matrix deposition/exchange;
- conservative tracer transport.
