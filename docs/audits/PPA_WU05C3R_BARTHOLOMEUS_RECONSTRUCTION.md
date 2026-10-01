# PPA-WU05-C3R — Bartholomeus oxygen-process reconstruction

Date: 2026-10-01

Status: `PREREGISTERED_RESEARCH / NO_PRODUCTION_MUTATION`

Canonical base: `integration/f-ci-canonical@2a0b23a2c4e547f6de2613884207d10b2fce462e`

## Question

Before porting the SWAP 4.3.1 `SWOXYGEN=2 / SWOXYGENTYPE=1` Bartholomeus route, determine whether its scientific contract can be represented in SWAP5 with materially simpler state and numerical machinery without changing the intended process model.

## Authority

- PPA-WU05-C admitted review authority.
- Corrected SWAP 4.3.1 B1.11 identities from that authority.
- SWAP-007 is mandatory numerical-reference behavior, not physical-model authority.
- Recovered S9/S11 oxygen cache evidence is corroborating architecture evidence.
- Bartholomeus et al. (2008), Journal of Hydrology 360, 147–165, DOI 10.1016/j.jhydrol.2008.07.029, is scientific intent authority.

## Initial reconstruction

The scientific model separates:
1. oxygen demand, including root respiration and microbial respiration;
2. macro-scale oxygen transport from atmosphere through soil gas;
3. micro-scale oxygen transport across the root-zone water film / root geometry;
4. reduction when oxygen supply cannot sustain potential root respiration.

The existing SWAP routine applies this per rooted node/layer and returns an oxygen reduction factor to root-water uptake. Oxygen remains a modifier, not a water-mass owner.

Recovered source-bound evidence shows six legacy arrays
`d_soil_term1`, `d_soil_term2`, `gfp100`, `capac_term`, `nmin1`, `mplus1`
are immutable-after-construction derived data. They must not become transactional per-column state in SWAP5.

## Hypotheses to falsify

H1. The complete Bartholomeus runtime can be expressed as a pure per-node response from current hydraulic state, temperature, root/crop geometry/configuration, and immutable soil precomputation, with no physical continuation state.

H2. The legacy Newton/restart machinery solves only an instantaneous scalar constitutive/root-oxygen balance and therefore does not require committed numerical state across timesteps.

H3. The scalar solve can be replaced by a bounded robust formulation or precomputed/interpolated response while preserving the B1.11 response surface to a separately declared tolerance.

H4. Most legacy cost is avoidable through immutable precomputation, removal of repeated hydraulic work, and a cleaner scalar solve; no relaxation of water-mass conservation is needed.

## Work plan

1. Reconstruct the exact B1.11 call graph and equations from the available pristine/cumulative source evidence.
2. Map each variable to immutable configuration, current external state, derived precomputation, call-local scratch, or true continuation state.
3. Reproduce the corrected B1.11 scalar response in an independent reference kernel.
4. Characterize solver difficulty and identify why Newton/restart is present.
5. Test three candidates against the kernel:
   - cleaned exact scalar solve;
   - bounded/bracketed solve;
   - response-table/interpolant only if monotonicity and error structure justify it.
6. Select the smallest implementation that preserves scientific intent and reference behavior.
7. Only then open a production C3 implementation slice.

## Gates

No production admission from this research branch.

A production proposal requires:
- exact source-equation reconstruction;
- explicit state classification;
- independent reference kernel;
- wet/dry, temperature, soil, depth and root-geometry coverage;
- SWAP-007 pathological case coverage;
- A/B/A replay where applicable;
- root-sink exactly-once mass ownership;
- fail-closed groundwater derivative behavior;
- measured cost relative to the legacy-equivalent implementation.

## First finding

A literal port of `oxygenstress.f90` is not the default strategy. Existing evidence already proves that part of the apparent state in the legacy routine is immutable derived data, and the 2008 scientific model is naturally decomposable into demand, macro transport, micro transport and a final supply/demand reduction. The next decisive question is whether any true cross-timestep oxygen state remains after exact equation reconstruction.


## Reconstruction checkpoint R1

### Numerical solve identified

The SWAP-007 patch exposes the local Newton residual derivative in the legacy scalar solve:

```text
fi_a = ... exp(-l / shape_factor_microbialr)
       - (r_mroot_z0 / d_soil) * l * exp(-l / shape_factor_rootr)
lnew = abs(l - fi / fi_a)
```

This is strong evidence that the Newton machinery is an instantaneous scalar root solve in a length-like variable `l`, with current root and microbial respiration terms and current soil oxygen diffusivity. No evidence found so far indicates that `l` is committed physical state between timesteps.

The legacy comments also explicitly mention an alternative ZBREND solution inside `SOLVE`. That independently supports classifying Newton as numerical execution policy rather than physical state.

### State classification strengthened

Evidence now supports, but does not yet fully qualify:

- six soil/hydraulic arrays: immutable-after-construction derived data;
- water-film thickness: recomputed from current matric potential and hydraulic precomputation;
- `d_soil`: recomputed from current gas-filled porosity and immutable coefficients;
- Newton variable `l`: likely call-local scalar scratch;
- Newton restart: numerical recovery, not model-time continuation.

Therefore H1/H2 remain live and strengthened. They are not yet admitted facts until the complete pristine equation/call graph is recovered.

### Performance implication

A SWAP5 design should separate:

```text
immutable soil precompute
        +
current node state/config
        -> instantaneous oxygen response kernel
        -> rwu reduction factor
```

and keep scalar-solver policy outside the physical-state object.

### Remaining authority gap

The available cumulative patch contains unchanged legacy equations only as context around changed hunks; it is not a complete pristine `oxygenstress.f90`. Exact B1.11 source materialization remains necessary before an exact independent kernel can be declared qualified. Library evidence is sufficient to continue architecture reconstruction but not to invent omitted equations.
