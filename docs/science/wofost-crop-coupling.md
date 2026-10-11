# WOFOST81 crop state and SWAP coupling

This page documents the bounded WOFOST81 scientific surface admitted for the frozen SWAP5 Status-A review baseline. It deliberately separates three questions:

1. which WOFOST-owned crop trajectories are scientifically preserved;
2. how one accepted daily crop event is published transactionally;
3. where crop state crosses into SWAP hydrology.

It is not a complete WOFOST81 theory manual and does not claim that every historical WOFOST or SWAP crop option belongs to the admitted baseline.

## Qualified crop-owned state surface

The immutable F-WOF-PP01 reference compares a verified SWAP 4.3.1 WOFOST81 Fortran donor with ten independent PCSE 6.0.13 Spring Barley potential-production cases. The qualified crop-owned surface contains twelve trajectories:

- development stage `DVS`;
- leaf area index `LAI`;
- organ nitrogen amounts `NamountLV`, `NamountRT`, `NamountSO`, `NamountST`;
- cumulative nitrogen uptake `NuptakeTotal`;
- total above-ground production `TAGP`;
- organ dry matter `TWLV`, `TWRT`, `TWSO`, `TWST`.

The PP01 campaign found these WOFOST-owned outputs equivalent to floating-point roundoff within the immutable reference precision contract.

Two quantities are deliberately outside that equivalence surface:

- `RD`, because rooting depth remains a SWAP rooting-interface quantity;
- `TRA`, because transpiration remains a SWAP hydrology-interface quantity.

This distinction is essential. Crop-state equivalence does not imply whole coupled SWAP-WOFOST equivalence.

## SWAP5 migration preservation

F-WOF-PP02 replays the migrated SWAP5 WOFOST81 implementation against the PP01 scientific reference. Its ten-case preservation campaign covers 1045 states and 1035 accepted transitions, with no first divergence. The largest observed difference is floating-point roundoff and remains far below the unchanged PP01 tolerance.

PP02 qualifies the migrated process kernels, versioned parameter/state contracts, composite crop owner, daily assimilation/rate correction, leaf structure and two-phase daily owner composition. It does not itself activate the runtime path.

The practical claim is therefore bounded but strong:

**for the admitted twelve WOFOST-owned trajectories, the migrated SWAP5 crop implementation preserves the independently qualified donor behaviour across the PP02 ten-case surface.**

## One accepted daily crop event

F-CI89 admits the runtime activation of that bounded WOFOST81 route. The runtime unit is one accepted daily crop event.

The transaction state contains the WOFOST81 crop owner plus identity of the last consumed event. Event forcing is constructed from an accepted SWAP window and carries accepted-window aggregates together with an event identity.

The runtime checks that:

- the event belongs to the intended interval;
- the owner state is valid;
- an accepted event cannot be consumed twice;
- failed candidate evolution does not alter committed crop state;
- crop owner state and consumed-event receipt are published atomically;
- source-event retirement is gated by the committed receipt.

The admitted numerical execution contract is intentionally narrow: model-certified temporal execution, no retry budget and one committed substep for the crop event. This is a runtime/lifecycle contract, not a new crop-growth equation.

## Hydrology-to-crop information

The accepted crop-event forcing contains accepted-window hydrological aggregates including:

```text
actual_root_uptake
potential_transpiration
```

Both must be finite and nonnegative before the crop event forcing is considered ready.

This makes an important ownership distinction explicit. Hydrology supplies accepted information to the crop event; a rejected soil-water trial cannot become authoritative crop forcing.

The PP01/PP02 equivalence contract still excludes `TRA` as a donor-equivalent crop-owned variable. The fact that potential transpiration and actual root uptake cross the runtime seam does not turn the entire SWAP hydrology calculation into a WOFOST-owned process.

## Crop-to-root-water-uptake contract

The frozen baseline exposes a canonical crop root-uptake input containing:

```text
crop_emerged
potential_transpiration
rooted_nodes
cumulative_root_fraction(0..rooted_nodes)
```

For an emerged crop, potential transpiration must be finite and nonnegative. The cumulative root-fraction vector must start at zero, end at one and be monotonically nondecreasing. An inactive crop canonicalizes to no transpiration demand and no active root distribution.

This contract is the crop-side input boundary for the separately documented [root-water-uptake process](evapotranspiration-root-uptake.md). It does not make WOFOST the owner of the soil-water extraction equation.

## Crop-to-ET canopy view

The frozen crop layer also contains a stateless canopy-view provider. From leaf area index `LAI` and direct/diffuse extinction coefficients it computes

```text
optical_depth = KDIR * KDIF * LAI
vegetation_cover_fraction = 1 - exp(-optical_depth)
```

For an emerged crop, crop factor is obtained from the development-stage table `CFTB(DVS)`. If the admitted CO2 correction is enabled, a transpiration factor is interpolated from the CO2 table; otherwise the factor is one.

When the crop has not emerged, the provider can still expose the vegetation-cover reconstruction required by the retained ET interface while crop-specific `CF` and CO2 dependencies are inactive.

This formula is documented as the exact frozen implementation contract. F-WOF43A owner qualification explicitly stated that independent scientific verification was still required before treating that workunit itself as scientific admission. F-DOC23 therefore does not use F-WOF43A to widen the scientific denominator or to claim that this small provider independently establishes the full ET formulation.

For actual ET partition and root extraction, see [Evapotranspiration demand and root-water uptake](evapotranspiration-root-uptake.md).

## Nitrogen scope

The bounded scientific preservation surface includes organ nitrogen amounts and cumulative nitrogen uptake. F-CI89 runtime activation additionally preserves the PP02 N-unlimited request-equals-supply route.

That is not a general Soil-N coupling claim. F-CI89 explicitly excludes a new Soil-N coupling policy. F-DOC23 therefore documents nitrogen state preservation within the admitted WOFOST-owned surface but does not infer nutrient-limited soil-crop exchange beyond the qualified route.

## Accepted state, restart and MultiSWAP

The crop owner is persistent model state. A trial crop update is tentative until the transaction commits. On rejection or failed evolution, committed owner state and the accepted-event receipt remain unchanged.

The broader F-WOF qualification chain establishes persistence/restart completeness for the admitted owner state and serialized MultiSWAP isolation. The capability review remains the controlling summary for release admission.

## What this page does not establish

This page does not claim:

- full WOFOST81 ecosystem compatibility;
- every historical crop model or crop option;
- donor equivalence for `RD` or `TRA`;
- arbitrary subdaily WOFOST stepping;
- a new root-growth or transpiration law;
- general Soil-N coupling;
- that the canopy-view provider alone proves the full ET science;
- EB, Ross/RossFast or groundwater semantics;
- whole-application SWAP 4.3.1 versus SWAP5 equivalence.

## Authority map

The controlling documentation matrix is `integration/f-doc/F-DOC23_AUTHORITY_MATRIX.md`.

The principal scientific and runtime authorities are F-WOF-PP01, F-WOF-PP02 and F-CI89. Frozen implementation seams referenced here include `src/crop/mod_crop_root_uptake_input_contract.f90`, `src/crop/mod_crop_et_canopy_view_provider.f90` and `src/runtime/mod_fmr_wofost81_crop_transaction.f90` in scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`.

See also [WOFOST admitted runtime](../capabilities/wofost-runtime.md), [Water balance, signs and units](water-balance-and-conventions.md) and [Status-A traceability](../status-a/TRACEABILITY.md).
