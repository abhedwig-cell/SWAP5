# TAB-HYD typed-provider admission boundary

Date: 2026-09-20

Status: **research architecture note; no production admission**

This note records the smallest current SWAP5 architecture surface that a future tabulated-hydraulics capability would need to cross. It does not authorize implementation or change the admitted hydraulic denominator.

## Current canonical authority

Reconciled against:

- `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`;
- frozen Status-A scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`;
- current constitutive contract in `src/solver/mod_soil_water_solver_contract.f90`;
- current analytical provider in `src/solver/mod_b110_default_mvg_provider.f90`;
- current production binding in `src/adapter/mod_b110_production_soil_water_task2.f90`.

Repository authority remains controlling; this research branch is not an admission source.

## Existing seam is sufficient for the K0 value-provider problem

The existing abstract `constitutive_hydraulics_provider_t` already supplies the exact value surface required by a table provider:

- pressure head input;
- water content output;
- conductivity output;
- capacity output;
- reserved `dconductivity_dhead` output.

The admitted analytical provider binds through this contract. Therefore a future `tabulated_hydraulics_provider_t` does **not** require a new solver ABI merely to support the admitted `SWKIMPL=0` route.

The current production adapter, however, constructs and binds `b110_default_mvg_provider_t` directly. There is no admitted typed table-data owner or explicit provider-selection branch.

## Current production-performance consequence

The production adapter currently rejects:

`swkimpl /= 0`

in `production_route_admitted()`.

That makes the research performance result asymmetric:

- **K0 / currently admitted production regime:** bounds-safe raw-head tables are hydrologically faithful but approximately runtime-neutral relative to analytical MvG;
- **K1 / research legacy-input regime:** raw-head tables show a repeatable roughly 9.6-11% speed reduction in the currently bounded cases, and raw-head plus exact theta/C reuse reaches about 12.8% in the Hupsel benchmark.

The K1 result cannot be translated into a current SWAP5 production speedup claim because the production K1 route itself is not admitted.

Therefore **performance alone does not currently justify production-migrating tabulated hydraulics for K0**. A production table provider may still be valuable for application compatibility, externally supplied hydraulic curves, or future K1 work, but those are separate capability arguments.

## Smallest future typed capability shape

If later authority admits implementation, the minimal design should be:

1. **Dedicated typed table data owner**
   - per material/layer or per node mapping;
   - raw pressure-head knots;
   - water-content ordinates;
   - log-conductivity ordinates;
   - preprocessed interpolation metadata;
   - explicit wet theta branch and Ksat plateau metadata where those semantics are part of the accepted table-generation contract.

2. **Dedicated provider**
   - extends `constitutive_hydraulics_provider_t`;
   - owns no committed hydrological state;
   - evaluates only constitutive response;
   - performs preprocessing outside the nonlinear hot loop;
   - keeps the analytical provider unchanged and independently selectable.

3. **Explicit provider selection**
   - selection must be typed and fail closed;
   - do not silently interpret `SWSOPHY=1` while binding the analytical provider;
   - do not depend on legacy `numtab/sptab/ientrytab` globals as the production ownership model.

4. **Separate K0 and K1 admissions**
   - K0 can use the existing value-provider ABI;
   - K1 requires its own numerical/scientific authority because current production explicitly excludes `SWKIMPL=1`;
   - the reserved derivative output is not itself K1 admission.

5. **Reference preservation**
   - Full Richards + analytical MvG remains the reference production route;
   - table selection is opt-in;
   - failure or invalid table metadata must not fall through silently to a different constitutive model.

## Research candidate to carry forward

For generated MvG-equivalent tables, the current research frontier is:

- 400 physical knots distributed uniformly in `log10(-h)` on the continuous branch;
- explicit final Ksat plateau;
- explicit wet theta/C branch;
- TSPACK preprocessing;
- raw pressure head as runtime interpolation coordinate;
- per-node/family last-interval hint with bounds-safe binary-search fallback;
- optional exact theta/C reuse, currently promising mainly for K1.

This is a **research representation**, not yet the input contract for arbitrary user-provided tables.

## Admission blockers

A production work unit should not start until the research line closes at least these points:

- expanded K1 trajectory qualification across loam/wet-clay scenarios;
- disposition of the localized near-branch `dK/dh` differences;
- decision whether arbitrary external tables or only generated/validated tables are in scope;
- typed table-data schema and validation contract;
- independent qualification against the selected reference authority;
- explicit decision whether K1 itself is being admitted.

Until then the correct disposition is: **research qualified for bounded characterization, production implementation held**.
