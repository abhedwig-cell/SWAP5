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


## Updated performance disposition after typed-provider qualification

The earlier statement that K0 performance alone did not justify a production work unit is superseded by the typed-provider research evidence.

Bounds-safe research now shows:

- typed provider-only evaluation over all 30 Staring rows: approximately **19.4% faster** than the canonical analytical provider;
- direct Reference Richards on 32-node research profiles: approximately **24-30% faster** with the same nonlinear iteration count and very small state/flux differences;
- serialized Reference/FMR equilibrium runtime: approximately **25-31% faster**, with zero pressure-head difference in the tested equilibrium fixture, equal retries, equal mass residual, and 3/3 nonlinear iterations.

Thus the generated-MvG-equivalent K0 table route now has a material performance case at the current SWAP5 typed provider seam.

This does **not** yet authorize production implementation because capability/admission blockers remain.

### New primary blocker: temporal-indicator provider coupling

Current canonical `mod_reference_richards_temporal_indicator.f90` accepts only concrete `b110_default_mvg_provider_t` and returns:

`constitutive-policy-deferred`

for every other provider behind the common constitutive ABI.

See `TAB-HYD-005-temporal-indicator-provider-coupling.md`.

A dynamic serialized transaction route therefore needs separately qualified provider-agnostic temporal-indicator semantics before a table provider can become a drop-in production alternative.

### Dynamic fixture qualification boundary

The first research dynamic FMR forcing sweep is not usable as table evidence because the analytical reference itself rejected all predefined wetting/drying perturbations from 40% down through 1.25% under that synthetic external-full/half fixture.

No transaction tolerance has been relaxed and this result does not count against table fidelity.

### Application-envelope scope blocker

The current generated table provider deliberately excludes:

- `H_ENPR != 0`;
- KSATEXM extension.

The canonical M1 Hupsel production profile can activate the KSATEXM extension. Whole-application canonical Hupsel acceleration is therefore not yet demonstrated by the generated provider.

### Revised admission rule

A production-provider work unit may be proposed only after:

1. provider-agnostic temporal-indicator semantics are qualified analytically first;
2. a valid dynamic Reference/FMR gate exists in which the analytical route itself is admitted;
3. the intended application scope is explicit — default MvG only versus KSATEXM/H_ENPR extensions;
4. generated equivalent tables and arbitrary external user tables remain separate capability contracts;
5. canonical reference preservation and fail-closed provider selection are retained.

Performance feasibility is no longer the blocker. Dynamic temporal-certificate authority and application scope are.
