# F-PE-ELASTIC — physical parameterization closure

Date: 2026-09-30

Status: SYNTHESIS_CLOSURE_MINERAL_PARAMETERIZATION_COMPLETE

Baseline:
`integration/f-ci-canonical@f9133b92cd7d128838029a162ee607bb8ba69689`

Purpose:
separate the physical ELAS/Ss conclusion from the later timestep,
globalization, transaction and MultiSWAP performance research.

This document introduces no new physical result. It consolidates already
qualified and admitted repository evidence.

## Closed question

For mineral BOFEK/BRO soil layers, should SWAP5 elastic storage be represented
as one global numerical constant such as `Ss = 1e-6 cm^-1`, or as a
soil-dependent physical parameter?

Decision:

`SOIL_DEPENDENT_PHYSICAL_PARAMETERIZATION`.

A uniform `1e-6 cm^-1` value remains useful as an experimental comparator,
but is not the admitted physical parameterization for generated mineral ELAS.

## Evidence chain

### ELASTIC13: mineral physical policy

`F-PE-ELASTIC13_PARAMETER_POLICY_RESULT.md` established the production-shaping
mineral policy on the frozen BRO/BOFEK population:

- 368 profiles;
- 1568 horizons/layers;
- 1356 MINERAL layers;
- 204 PEAT layers;
- 8 ORGANIC_RICH_NONPEAT layers;
- 0 UNKNOWN layers.

For MINERAL at the frozen reference state `h = -100 cm`:

- minimum: `1.7599e-6 cm^-1`;
- p10: `2.2677e-6 cm^-1`;
- median: `2.8388e-6 cm^-1`;
- p90: `4.1648e-6 cm^-1`;
- maximum: `2.5275e-5 cm^-1`.

`99.8525%` of the mineral population lies above `2e-6 cm^-1`.
Therefore `1e-6 cm^-1` is not representative of the generated mineral
population.

The `h=-100 cm` convention was robust against the preregistered
`h=-200 cm` sensitivity test: all mineral layers remained within
`0.8 <= Ss(-200)/Ss(-100) <= 1.25`.

The operational uncertainty factor is the independently derived multiplicative
factor `2.123968031921196`. This is an uncertainty envelope, not a confidence
interval.

Policy:

- MINERAL: `AUTO_STATIC_PRIOR_AT_H_MINUS100`;
- ORGANIC_RICH_NONPEAT: `RESEARCH_ONLY_NOT_AUTO_ASSIGNED`;
- PEAT: `RESEARCH_ONLY_NOT_AUTO_ASSIGNED`;
- UNKNOWN: `NO_AUTO_ASSIGNMENT`.

### ELASTIC14-17 and ELASTIC45: production-shaped application chain

The qualified/admitted chain separates physical inference, geometry and runtime
ownership:

`source descriptors`
-> deterministic horizon-to-node mapping
-> descriptor assembly
-> physical mineral prior materialization
-> explicit generated-prior binding
-> `elasticity_active + cofgen(24,:)`
-> runtime materialization
-> constitutive ELAS semantics.

The later admitted RD application-host chain preserves the same physical policy.

Important ownership rules remain:

- generated ELAS is default OFF;
- explicit/user ELAS has higher ownership than generated ELAS;
- only MINERAL is automatically assigned;
- PEAT and ORGANIC_RICH_NONPEAT fail closed for automatic assignment;
- the physical prior does not own timestep, solver or globalization policy;
- no live GIS/BRO/PDOK access occurs inside Richards/runtime.

### ELASTIC46: OFF versus fixed 1e-6 versus generated ELAS

ELASTIC46 directly compared:

- `OFF`;
- `FIXED_1E6`;
- `GENERATED`.

For the frozen real-source mineral profile, generated node-local Ss ranged from
`2.25036e-6` to `2.99817e-6 cm^-1`.

The generated values therefore materially differ from `1e-6 cm^-1`.

In unsaturated negative-control conditions all three regimes followed the same
numerical path, as expected because elastic saturated storage was inactive.

Under saturated equilibrium, pressure-head equilibrium remained identical while
water content differed in the physically expected direction due to elastic
storage.

Under perturbed saturated conditions, ELAS could strongly reduce nonlinear
iterations, retries and backtracking, but the effect was not monotonic across
state and forcing direction.

Therefore:

- ELAS has a real physical storage effect;
- ELAS materially interacts with numerical work near and above saturation;
- `FIXED_1E6` and `GENERATED` are not interchangeable;
- no general claim is justified that increasing ELAS always improves
  convergence or runtime.

### ELASTIC47-71: later numerical/performance work

The later ELASTIC line investigated the interaction with timestep acceptance,
mode-7 temporal budgets, transaction behavior and MultiSWAP execution.

Those results may govern execution policy for specific admitted routes, but
they do not redefine the physical Ss parameterization.

In particular, the later `0.20 cm` temporal head budget belongs to an
application-owned timestep policy. It is not an ELAS value and must not be
interpreted as part of the elastic-storage constitutive parameterization.

## Physical conclusion

For mineral BOFEK/BRO soils, the original research question is closed:

1. Elastic storage is treated as a physical constitutive/storage parameter,
   not merely as a numerical regularizer.
2. A single universal `Ss = 1e-6 cm^-1` is rejected as the general generated
   mineral parameterization.
3. The qualified generated mineral policy uses soil-dependent values derived
   from the frozen physical predictor and a fixed `h_ref = -100 cm`
   convention.
4. The generated mineral population is centered near
   `2.84e-6 cm^-1`, with substantial genuine material variation.
5. Explicit/user-provided ELAS remains authoritative when present.
6. Numerical benefits are secondary consequences and are not used to tune the
   physical prior.

Classification:

`MINERAL_ELAS_PHYSICAL_PARAMETERIZATION_CLOSED`.

## Remaining scientific boundary

The remaining physical parameterization gap is not mineral soil.

It is:

- PEAT;
- ORGANIC_RICH_NONPEAT.

The existing predictor can produce descriptive values for those regimes, but
the repository explicitly does not admit automatic scalar-linear assignment
there.

A future physical study should therefore target peat/high-organic constitutive
storage behavior directly. It should not reopen the already closed mineral
policy unless new independent physical evidence invalidates its dependency
surface.

## Practical SWAP5 interpretation

For present SWAP5 development:

- use the generated soil-dependent mineral prior when the explicit generated
  ELAS route is selected;
- retain `1e-6 cm^-1` only as a comparator or deliberately user-selected
  value;
- do not use solver speed as a calibration target for Ss;
- keep ELAS physics and timestep/performance policy separate;
- do not auto-assign the mineral relation to peat or high-organic layers.

No new solver, timestep, MultiSWAP or production-source change follows from this
closure.
