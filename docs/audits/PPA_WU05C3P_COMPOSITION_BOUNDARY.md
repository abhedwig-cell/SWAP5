# PPA-WU05-C3P — proposed SWAP5 Bartholomeus composition boundary

Status: DESIGN CANDIDATE, NOT PRODUCTION WIRED

## Rule

The Bartholomeus kernel is an evaluator. It does not own water, crop lifecycle, hydraulic state,
thermal state, or accepted/rejected timestep state.

## Inputs by owner

### Soil/hydraulic owner
Per node:
- theta or gas-filled porosity;
- matric head/potential;
- saturated water content;
- hydraulic construction/precompute required by water-film evaluation;
- layer bulk density, sand fraction and organic-matter fraction;
- node/layer geometry.

### Thermal owner
- current soil temperature.

### Crop/root owner
- root length/specific-root-length derived quantities;
- root radius configuration;
- current root distribution / root dry mass;
- senescence factor;
- maintenance respiration coefficient;
- Q10 root;
- maximum respiration factor;
- crop lifecycle/model selection.

### Oxygen immutable dataset
Shared by compatible columns:
- d_soil_term1;
- d_soil exponent;
- gfp100;
- capac_term;
- n_minus_1;
- m_plus_1;
- fixed shape factors and static oxygen configuration where applicable.

## Output

Per node:
- oxygen reduction factor for root-water uptake;
- optional diagnostics trace.

No water flux is booked here.

## Runtime behavior

```text
current owner views
    -> supporting oxygen algebra
    -> water-film evaluator
    -> MICRO / MACRO residual
    -> bounded respiration solve
    -> rwu reduction factor
    -> existing root extraction composition
```

## Transaction semantics

No Bartholomeus-specific commit/rollback payload is proposed.

Rejected trial:
- recompute from rejected current owner views;
- discard returned reduction/diagnostics.

Accepted trial:
- owning water/crop/thermal states commit through their existing contracts;
- oxygen evaluator stores no continuation state.

If C3Q reveals history dependence at identical current inputs, this design is falsified.

## Production modes

REFERENCE:
- exact-preserving/prequalified algebra;
- reference water-film policy;
- bounded inner and outer solves.

PRACTICAL:
- same physical contract;
- qualified WFT lookup;
- reference fallback/oracle retained.

Mode selection is numerical policy, not crop/soil physical configuration.

## Explicit exclusions from first admission

- SWSOPHY=1 tabular hydraulic water-film path;
- new scientific oxygen formulations;
- changing Bartholomeus parameter values;
- coupling oxygen directly to water-mass ownership;
- carrying solver guesses across timesteps.


## Hysteresis construction-key constraint

Recovered S9 evidence establishes an important qualification on the immutable dataset.

Several precomputed quantities are constructed through `watcon()`. With hysteresis enabled, that
evaluation depends on the node's initial wetting/drying branch. The dataset is therefore:

`immutable-after-construction`

but not universally a function of nominal soil parameters alone.

A MultiSWAP sharing key must include every construction dependency, including the initial
hysteresis branch when `SWHYST>0`. Columns may share one oxygen precompute only when this complete
construction key matches.

Later hysteresis reversal does not mutate the legacy oxygen precompute; preserving that behavior is
part of 4.3.1 parity unless a separate scientific change is explicitly qualified.


## Vertical oxygen-boundary propagation

Exact legacy source inspection exposes one important within-call/profile dependency:

```text
C_top(1)      = atmospheric oxygen concentration
C_top(node+1) = C_macro(node)
```

Therefore a single node evaluator remains instantaneous/stateless, but a rooted-profile evaluation is
ordered from top to bottom and carries the current macro oxygen concentration as the upper boundary
for the next node.

This is not accepted-timestep continuation state and does not belong in `SwapContextSnapshot`.
It is profile-evaluation scratch owned by the oxygen composition/caller for one root-profile pass.

Revised composition:

```text
atmospheric C_top
  -> node 1 evaluator -> C_macro(1)
  -> node 2 evaluator -> C_macro(2)
  -> ...
  -> per-node rwu factors
```

The earlier statement "no dynamic OxygenState" remains valid for timestep persistence, but must not
be misread as "nodes are independently evaluable in arbitrary order".


## Implemented research composition seam

A narrow research implementation now exists in:

`src/process/mod_root_uptake_oxygen_composition.f90`

It deliberately does not create a second root-water process. It composes an independently evaluated
oxygen factor onto the existing drought-qualified root sink and returns one replacement
`root_extraction_sink`.

The module provides:
- `compose_root_sink_with_oxygen_factor`: bounded [0,1] nodewise composition;
- `evaluate_macro_feddes_drought_oxygen_uptake`: calls the existing drought process first, then
  applies the oxygen factor through the same single-sink result type.

Invalid/non-finite oxygen factors fail closed. Nodes below the rooted domain are preserved unchanged.
The final uptake total is recomputed from the one composed sink.

This is intentionally upstream of `mod_b110_root_sink_provider`: the solver provider continues to
see exactly one already-composed root sink and acquires no oxygen-process ownership.

Groundwater analytic tangent coverage is not widened by this seam. Oxygen-active composition remains
outside the admitted drought-only tangent envelope until separately qualified.
