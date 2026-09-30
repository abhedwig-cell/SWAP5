# PPA-WU05-A5 P5 local multi-compartment drainage topology result

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / SOURCE_BOUND_DRAINAGE_TOPOLOGY_SUPPORTED`

## Exact B1.11 source authority

Exact `RAPIDDRAIN`, `macrorate.f90:1847-1933`.

## Ownership and topology

Rapid drainage is only active for:

`id == 1`

the Main Bypass Flow domain.

All other macropore domains return without rapid-drain flux.

This confirms that the source model has one external rapid-drain owner, even when several macropore domains are active.

## Drain-type/domain-bottom gate

For a drain-tube route, rapid drainage is only possible when the main-domain bottom is sufficiently deep relative to the rapid-drain level.

For open-drain topology, drainage may remain possible even when that depth relation is not satisfied.

Therefore drainage activation depends on:

- external drain topology;
- active main-domain bottom;
- macropore water level.

It is not simply a per-compartment sink switch.

## kD construction

For each active compartment from the top water compartment through the active domain bottom:

1. crack width is derived from the ratio `VlMpDmCp/Dz`;
2. a compartment `KDCrRlCp` is computed;
3. the partially saturated top compartment is weighted by `SatFr`;
4. total `KDCrRl` is the sum across active compartments.

The effective drainage resistance scales with:

`min(KDCrRlRef/KDCrRl, 1.1)`.

## Drainable-storage cap

The total candidate drainage amount is bounded by:

`WaSrDrainabl = max(0, WaSrMpDm - VlMpUndrDrL)`.

Thus water below the applicable drain level is protected from rapid drainage.

## Compartment distribution

After the total rapid-drain amount is determined, it is distributed over active compartments as:

`FlwOutDrRapCpPot(ic) = FlwOutDrRapPot * KDCrRlCp(ic)/KDCrRl`.

This distribution is conservative by construction.

## Local multi-compartment test

A four-active-compartment main-domain case with partial top saturation was evaluated.

Result:

- total rapid drainage: `0.4248455052 cm`;
- compartment contributions sum to the same total to machine precision;
- larger `kD` compartments receive larger drain shares.

Additional checks:

- domain 2 rapid drainage = exactly zero;
- high-head low-storage case is capped exactly at `0.03 cm`;
- drain-tube case with insufficient main-domain depth is blocked.

## P5 conclusion

`RAPID_DRAINAGE_IS_ONE_MAIN_DOMAIN_EXTERNAL_RECEIPT_DISTRIBUTED_BY_ACTIVE_COMPARTMENT_KD`.

This is fully compatible with the A4 external-outflow ownership model, but the current typed A4 process only implements a one-compartment reduction.

## H6 disposition

H6 is supported by the multi-compartment source-bound topology:

rapid drainage remains a single external owner after multi-domain composition.

## Next step

Compose P1-P5 into a typed A5 multi-domain process candidate:

- accepted top-partition amounts;
- source-consistent active geometry;
- distributed internal exchange;
- main-domain multi-compartment rapid drainage.

Then qualify one complete multi-domain candidate and proceed to P6 restart/replay.
