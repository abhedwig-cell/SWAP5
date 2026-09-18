# PPA-WU05-C Oxygen-stress source/state/owner decomposition

Date: 2026-09-19

Status: `QUALIFIED_REVIEW_AUTHORITY_READY_FOR_CANONICAL_ADMISSION / PRODUCTION_IMPLEMENTATION_HELD`

Canonical reconcile base: `integration/f-ci-canonical@781c829943c9e5880e5ab83281112e66f439ecf2`.

## Purpose

PPA-WU05-C is the oxygen-stress authority slice selected by the closed PPA-WU05 dependency triage. It does not migrate oxygen stress. It separates the legacy oxygen families, preserves existing SWAP5 root-sink ownership, and freezes only the state and interface conclusions that are actually supported by corrected-reference and recovered evidence.

The key result is that "oxygen stress" is not one migration unit.

Three distinct legacy families must remain separate:

1. `SWOXYGEN=2, SWOXYGENTYPE=2`: oxygen reproduction factor;
2. `SWOXYGEN=1`: Feddes wetness/oxygen route;
3. `SWOXYGEN=2, SWOXYGENTYPE=1`: Bartholomeus physical oxygen-stress route.

Only the first family has enough recovered source-bound evidence in the present repository/project surface to freeze a no-persistent-state target contract. The other two remain source-materialization holds.

## Corrected reference authority

The corrected reference is SWAP 4.3.1 B1.11, member manifest:

`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`

Relevant member identities are:

```text
SWAP/oxygenstress.f90
8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87

SWAP/rootextraction.f90
8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5

SWAP/RWU_micro.f90
cac3d723cc11fb001878d53f2747bbff9fd53fb22949b682906df4361cb90477

SWAP/temperature.f90
92c39d296f41a60cfe3b66f8d1886ea938a53b4e0ea49e7ae1a23dd9680bd338
```

SWAP-007 is mandatory corrected-reference authority. It changes no oxygen-stress physics. It prevents an unrepresentable Newton quotient from overflowing and routes that case through the existing restart path. Any future migration of the affected numerical path must preserve this B1.11 behavior and must not reintroduce B0 bug compatibility.

## Existing SWAP5 owner boundary

Current production root uptake is deliberately narrower than legacy oxygen stress. The canonical `mod_root_water_uptake_process` owns the accepted nodewise root extraction sink for the restricted drought-only Feddes route.

PPA-WU05-C does not create another water-mass owner.

The invariant for every future oxygen slice is:

```text
potential transpiration / root demand
        |
        v
root uptake + independently qualified stress modifier(s)
        |
        v
one nodewise root_extraction_sink
        |
        v
one accepted root-water mass receipt
```

Oxygen factors, oxygen diagnostics, empirical reductions and numerical oxygen state are not separate water sinks.

This also preserves the groundwater-coupling rule from F-GC30. A root-sink response that depends on an oxygen process remains outside the currently admitted analytic tangent envelope until its derivative coverage is independently qualified. It must fail closed rather than silently reuse the drought-only derivative surface.

## Family A: oxygen reproduction, SWOXYGEN=2 and SWOXYGENTYPE=2

Recovered A23AP evidence is unusually strong for this family.

The historical source-bound contract covers both macro and microscopic root-extraction call paths. Its effective inputs are:

- immutable oxygen slope and intercept coefficients;
- current node water content;
- current hydraulic saturation water content;
- current node soil temperature;
- node depth and bottom coordinate;
- the cumulative gas-filled-porosity numerator through the node.

The output is a root-water-uptake reduction factor.

The recovered architecture removes the legacy saturation replica and binds saturation to the current hydraulic representation:

`theta_s(node) = CofGen(2,node)`.

The cumulative porosity work is a caller prefix:

```text
prefix(node) = prefix(node-1)
             + (theta_s(node) - theta(node)) * dz(node)
```

The historical gate compared the transformed scalar/prefix algebra to the legacy array implementation for 100,000 evaluations, including 4,539 gas-zero cases, with zero bitwise mismatches. A controlled dynamic case exercised 16,116 reproduction calls across both macro and microscopic root extraction, with 194,924 current-saturation requests and zero stale-saturation requests.

### State classification

For this family, the recovered evidence supports:

```text
physical persistent state     none
new persistent profile state  none
shared mutable process state   none
call-local scratch             current theta_s scalar
                               cumulative porosity prefix scalar
```

This conclusion is restricted to the reproduction family. It must not be generalized to Feddes oxygen or the Bartholomeus physical model.

The temperature and hydraulic fields remain externally owned read-only views. The reproduction process does not own soil temperature or hydraulic storage.

### Mass semantics

The reproduction factor is not an accepted mass flux.

It may change the nodewise root sink that the existing root-uptake owner finally publishes. That final sink is booked exactly once by the root owner.

## Family B: SWOXYGEN=1 Feddes wetness/oxygen route

The current project surface proves that this route is outside the admitted drought-only SWAP5 root uptake. It does not contain enough byte-exact B1.11 routine materialization to freeze the complete equation and state contract.

PPA-WU05-C therefore refuses to infer that the route is stateless merely because classic Feddes stress is often algebraic.

Frozen conclusions are limited to:

- it is a separate physical option from the current drought-only route;
- it must compose through the existing single root-sink mass owner;
- it may consume only clean owner views;
- production implementation requires an exact B1.11 equation and call-path oracle first.

Status:

`PPA-WU05-C2 = HELD_SOURCE_MATERIALIZATION_REQUIRED`.

## Family C: SWOXYGEN=2 and SWOXYGENTYPE=1 Bartholomeus physical oxygen model

This route is deliberately not inferred from A23AP, because A23AP explicitly excludes it.

Recovered S9/S11 ownership evidence does establish one useful boundary. Six per-node arrays used by the oxygen process were successfully separated as immutable-after-construction derived data:

- `d_soil_term1`;
- `d_soil_term2`;
- `gfp100`;
- `capac_term`;
- `nmin1`;
- `mplus1`.

They were removed from transaction snapshots and attached to shared data. When construction invokes hydraulic retention under hysteresis, the initial hysteresis branch is part of the complete construction key.

That is corroborating ownership evidence, not current production authority and not proof that the complete Bartholomeus process has no persistent state.

The exact B1.11 source is still required to determine:

- complete physical continuation state, if any;
- current versus lagged oxygen variables;
- exact Newton/restart semantics;
- exact dependencies on water content, temperature, bulk density and root geometry;
- the complete reachability of the SWAP-007 numerical guard.

Status:

`PPA-WU05-C3 = HELD_SOURCE_MATERIALIZATION_REQUIRED`.

## Transaction rules

All later oxygen production slices must satisfy these rules.

1. Rejected trials publish no accepted root-water sink.
2. Any true oxygen continuation state is checkpointed, trial-local, and committed atomically with the accepted outer interval.
3. Rejected-trial oxygen state cannot become hidden history for a retry.
4. Call-local algebra, porosity prefixes and numerical workspace remain worker scratch.
5. Immutable precomputations are shared only under a complete construction key.
6. The SWAP-007 representability guard is part of corrected-reference numerical semantics wherever its path is present.
7. No mass tolerance may be relaxed to admit oxygen stress.

## Thermal and hydraulic ownership

PPA-WU05-C does not reopen the thermal owner.

The current sensible-soil-temperature production route can eventually provide a clean read-only temperature field to a qualified oxygen slice. Its existence does not itself admit oxygen stress, frost or latent heat.

Likewise, oxygen code may consume current hydraulic water content or saturation only through explicit owner views. It may not import a stale compatibility copy or HeadCalc/Newton/Jacobian internals.

## Frozen migration slicing

### PPA-WU05-C1

Scope: typed pure `SWOXYGEN=2 / SWOXYGENTYPE=2` reproduction factor.

This is the first permitted implementation target because it has the strongest recovered authority and the simplest state topology.

Required gates include:

- exact factor oracle against a pinned source-equivalent reference;
- macro and microscopic call-path coverage;
- current theta/theta_s ownership;
- read-only thermal ownership;
- O0/O2 identity;
- A/B/A replay;
- exactly-once root-sink mass preservation;
- no parallel-root or groundwater-derivative scope widening.

### PPA-WU05-C2

Scope: Feddes oxygen/wetness modifier.

Held until exact B1.11 source materialization fixes its equation, option inputs and state semantics.

### PPA-WU05-C3

Scope: Bartholomeus physical oxygen process.

Held until exact B1.11 source materialization fixes physical state, shared-derived data, Newton/restart behavior and the SWAP-007 path.

### PPA-WU05-C4

Scope: MICRO/Jong-van-Lier composition with an independently admitted oxygen modifier.

Held on both MICRO owner authority and the relevant oxygen slice.

## Non-claims

PPA-WU05-C does not claim:

- production oxygen stress;
- a complete Bartholomeus state model;
- that SWOXYGEN=1 is stateless;
- MICRO/Jong-van-Lier production;
- salinity, frost or compensation stress;
- oxygen derivative coverage for groundwater coupling;
- parallel oxygen throughput;
- a new root-sink mass owner;
- a new soil-temperature or hydraulic owner;
- any solver, tolerance, timestep or mass-policy change.

## Review verdict

`OXYGEN_FAMILY_BOUNDARIES_FROZEN_C1_READY_FOR_SEPARATE_IMPLEMENTATION_AUTHORITY_C2_C3_SOURCE_HELD`

PPA-WU05-C can therefore close as a review-only authority unit once its repository validator confirms the corrected-reference identities, current owner boundaries, fail-closed holds and zero production/reference delta.


## Qualification

The review-only authority gate passed on the candidate evidence head:

- workflow run `35406174674`;
- authority job `105796281149`: PASS;
- independent-contract job `105796280957`: PASS.

The gate independently checks B1.11 identity binding, SWAP-007 preservation, the existing single root-water mass owner, the restricted no-persistent-state conclusion for the reproduction family, fail-closed C2/C3 holds, C1..C4 migration slicing, and absence of any `src/` or `reference/` mutation.

No production admission follows from this qualification.
