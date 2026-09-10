# F-PM06E Restricted B1.10 Surface-Evaporation Capacity Candidate

## Purpose

F-PM06E implements only the hydraulic scalar capability identified by F-PM06D. It provides the signed atmospheric hydraulic surface-evaporation capacity `Emax` required by the already independently qualified F-PM06C structural surface-evaporation process. It does not compose that process into runtime.

The production candidate is `41628858477d6fa8d6a46de8ff1a9e69459c2eb0`, directly parented by current canonical authority `adf79478f55458c05444ad9b90e52644e6cf36b6`.

## Frozen scientific scope

The candidate is deliberately narrow:

* B1.10 default Mualem-van Genuchten hydraulics only;
* atmospheric limiting pressure head `hatm = -2.75e5 cm`;
* frost inactive;
* macropore surface scaling inactive, implemented conservatively as macropore inactive;
* conductivity mean policies `SWKMEAN=1..6` only;
* no snow widening, interception, runoff, SWREDU=1/2, or full BOUNDTOP migration.

Legacy B1.10 defines, under the frozen frost/macropore-off scope,

`ksurf = K_1(hatm)`

`k1Atm = HCOMEAN(SWKMEAN, ksurf, K_1(h1), dz1, dz1, ...)`

`Emax = -k1Atm * ((hatm-h1)/disnod1 + 1)`.

The modern geometry field `node_distance(1)` is already source-bound by the existing serialized legacy adapter to `disnod(1)`. The new concrete provider consumes that explicit parameter and the exact trial base state's top pressure head. It does not read legacy globals or solver scratch.

## API boundary

`mod_surface_evaporation_capacity_contract` defines a soil-hydraulic capability interface and a small result object containing only status, signed evaporation capacity, and a diagnostic route. This keeps the process API independent of HeadCalc arrays, Newton vectors, Jacobians, raw conductivity profiles and the concrete Richards implementation.

The B1.10 implementation is `mod_b110_surface_evaporation_capacity_provider`. It binds immutable/shared geometry and hydraulic parameter references plus the selected conductivity-mean policy. Evaluation reads the exact supplied physical base state and creates no persistent state.

The existing B1.10 MvG provider receives one narrow scalar conductivity entry point. This reuses the same constitutive functions as the established all-node provider without invoking moisture capacity or `dK/dh`, and without creating an artificial step-duration dependency for `Emax`.

No top-boundary provider is changed or selected. No runtime composition is added. No F-PM06C source is copied into canonical production.

## Fail-closed boundaries

The capability returns unsupported configuration for active frost, active macropores, unknown conductivity-mean policies, and `SWKMEAN=7`. SWKMEAN=7 is not approximated. The legacy implementation delegates that case to `sub_Kavg_Szym`; no clean modern Szymkiewicz hydraulic capability is currently present in the canonical solver layer. Supporting it requires its own source-bound hydraulic workunit.

Missing or inconsistent top state, non-finite ponding/head/geometry, non-positive top distance, or an invalid constitutive result returns invalid input.

Negative finite Emax remains signed. Clamping belongs only to the downstream structural surface-evaporation process and is therefore outside this hydraulic provider.

## Transactions, state and mass

The provider is pure in the lifecycle sense: it reads the supplied trial base state and immutable/shared parameter references and writes only a trial-local result. No persistent state is added. No checkpoint, rollback or committed state is mutated.

F-PM06E does not publish an accepted evaporation flux and does not alter the solver boundary. Therefore it adds no independent water-mass term. When runtime composition is separately qualified later, the accepted solver top flux remains the sole water-mass authority for the soil column.

No calendar concept is introduced. `Emax` is a rate from instantaneous hydraulic state and geometry.

## Qualification boundary

The owner gate verifies exact production scope, exact candidate blobs, source-lock continuity, scalar conductivity identity with the established B1.10 provider, mean policies 1 through 6, signed negative Emax, fail-closed unsupported cases, state immutability and O0/O2 identity.

This is not independent scientific admission. After a green exact-head owner gate, a separate F-VQ workunit must independently reconstruct the frozen B1.10 equations and qualify the exact production candidate before any runtime materialization or canonical admission.
