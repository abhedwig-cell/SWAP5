# TOP03 explicit transition-layer prerequisite

Date: 2026-10-02
Status: REQUIRED_BEFORE_PHYSICAL_PARAMETER_ADMISSION

## Why this is a separate prerequisite

The finite contact-resistance formulation is numerically robust in the current TOP03 synthetic fixture and has a defensible physical interpretation as a reduced saturated surface layer with

```
R_s = L_s / K_s
```

However, the current FAPP09/TOP03 mechanism fixture is not suitable for identifying `L_s` and `K_s` separately.

Its test stub declares:

- four nodes;
- `z = [-0.25,-0.75,-1.50,-2.50] cm`;
- `dz = [0.50,0.50,1.00,1.00] cm`;
- but `disnod/node_distance = 1.0 cm` for every face.

This was deliberately adequate for a bounded solver/integration mechanism probe. It is not a geometrically faithful discretization from which a millimetre- or centimetre-scale transition-layer thickness can be inferred.

Building an explicit crust layer into this fixture would therefore create false physical precision.

## Existing repository route

The repository already has infrastructure for materializing internally consistent Richards test geometries. For example, `tests/rom/materialize_f_rom0_headcalc_stubs.py` creates a grid with matching node centers, compartment thicknesses and node distances and is used by the BOFEK/performance testbank.

The transition-layer equivalence test should reuse that style of geometry construction rather than reinterpret the four-node TOP03 stub.

## Required experiment

Create a separate geometrically consistent profile fixture with:

1. a declared base soil column;
2. local vertical refinement near the surface;
3. an explicit upper transition layer with independently specified `L_s` and `K_s`;
4. a comparator without that layer but with reduced boundary resistance `R_s=L_s/K_s`;
5. identical deeper-soil hydraulic properties, initial profile, lower boundary and external stage forcing.

Use multiple `L_s,K_s` pairs that produce the same resistance to test whether the reduced boundary is insensitive to layer decomposition only where the explicit-layer approximation should be valid.

At minimum include:

- a no-layer / `R_s=0` control;
- at least two finite resistances;
- at least two different `L_s,K_s` decompositions for one common resistance;
- temporal refinement;
- integrated top and bottom exchange;
- soil storage and complete mass closure.

## Acceptance rule

The reduced resistance becomes a physically qualified surface parameterization candidate only if, over a declared profile/stage envelope:

- explicit-layer and reduced-boundary trajectories both converge;
- mass closes independently;
- accepted underlying-soil states converge under vertical and temporal refinement;
- integrated top and bottom exchange agree within a preregistered physical error budget;
- the conclusion is not sensitive to an arbitrary top-grid spacing choice.

Until then, `R_s` remains a supported research parameter, not admitted production physics.

## Consequence for TOP03

TOP03 itself should not be broadened into grid/layer-model development.

The current branch has established:

- the flat full-contact boundary is the problematic idealization;
- shallow partial contact helps onset;
- simple wet-fraction geometry alone is insufficient during stage rise;
- finite contact resistance robustly repairs the synthetic trajectory;
- the physical magnitude of that resistance remains unqualified.

PR #956 therefore remains draft. Receipt/commit qualification should resume only after the transition-layer prerequisite or another independent physical authority supplies the admitted surface-contact envelope.
