# Water balance, signs and units

This page defines the reviewer-facing conventions needed to read the SWAP5 hydrological documentation without silently conflating different sign systems or accounting scopes. It does not replace process-specific contracts or the normalized verification contract.

## One physical transfer, one authoritative booking

The hydrological column is governed by conservation of water. Over an accepted interval, the change in physically persistent water storage must equal the net water transferred across the accounting-domain boundary, including externally crossing source and sink terms.

At the normalized accounting level:

```text
delta_storage = storage_end - storage_start
net_external  = sum(external signed amounts)
residual      = delta_storage - net_external
```

A physical transfer may also appear in diagnostics, attribution or process-local results. That does not create a second water transfer. For example, actual transpiration may be reported as the sum of root extraction, but the soil-water sink and the transpiration attribution refer to the same withdrawal.

See the [mass-accounting contract](../verification/mass-accounting-contract.md) for the normalized verification record and [Status-A traceability](../status-a/TRACEABILITY.md) for current admission/preservation authority.

## Three conventions that must not be mixed

### 1. Hydraulic vertical-flux convention

The controlled SWAP scientific lineage used by the restricted reference Richards authority defines vertical coordinate `z` positive upward and hydraulic water flux `q` positive upward:

```text
q = -K(h) d(h + z)/dz
```

Under this convention an upward bottom flux has positive `q`, while downward percolation has negative `q`. This is a physical/numerical flux convention for the Richards formulation.

### 2. Process sink magnitudes

Some process interfaces expose a nonnegative sink magnitude rather than a signed hydraulic flux. The frozen restricted root-water-uptake process is an example: `root_extraction_sink(i)` is a nonnegative extraction rate for compartment `i`. In the soil-water balance it is subtracted as a sink.

A nonnegative sink magnitude therefore does **not** mean positive water entry. Its meaning comes from the process contract.

### 3. Normalized verification accounting

The VQ normalization convention is different and intentionally interface-oriented:

```text
positive signed amount = water entering the accounting domain
negative signed amount = water leaving the accounting domain
```

Examples include precipitation or upward bottom inflow as positive amounts, and transpiration, evaporation, drainage or downward bottom outflow as negative amounts.

Adapters may translate implementation-local conventions into this normalized record. A raw variable's sign must never be inferred solely from its name.

## Rate versus amount

Scientific process modules commonly produce rates. The restricted reference ET process, for example, exposes potential transpiration, potential soil evaporation and potential pond evaporation in `cm/day`. The corresponding frozen input reference ET is supplied in `mm/day` and converted by the process.

Mass verification, however, is based on **amounts integrated over the accepted interval**, not on instantaneous rates. A rate becomes an accounting amount only after integration over its applicable interval and with the correct area/depth basis.

The preferred normalized column basis is water-equivalent depth over the column area. A volume basis is valid only when sufficient area/basis metadata is retained for unambiguous normalization.

## Storage and internal transfers

The accounting domain includes each physically persistent SWAP-owned water store that is active for the configured model topology. Examples can include soil-water storage and, when the relevant admitted physics is active, surface, snow or other process storage.

Transfers between stores inside one accounting domain are internal transfers. They may be scientifically important, but they cancel in the external balance and must not be counted as additional external water.

Optional inactive physics must not be represented as invented persistent water merely to fill a schema.

## Trial versus committed accounting

SWAP5 separates numerical trial state from committed physical state. This distinction applies to water accounting as well:

- a trial may contain provisional storage and flux integrals for diagnostics and assessment;
- a rejected trial does not alter committed storage and contributes no committed flux/source amount;
- exactly one accepted trial may contribute committed accounting for an accepted interval;
- retry history must not duplicate physical transfers.

This is why a numerically computed flux is not automatically an authoritative model transfer. Authority follows acceptance and commit.

## Generic model time

The balance is defined over a model interval `[t0,t1]`. Day, month and year boundaries are not intrinsic to the conservation identity. If an interval is split at `tmid`, and no event changes the process contract, the end storage of the first interval must match the start storage of the second and the external amounts must compose additively, subject to the qualified numerical/accounting tolerance.

## Coupled boundaries

When water crosses between two coupled components, such as a SWAP column and a groundwater component, the same transfer is external to each component but internal to the combined system. Component-local balances and interface-pair balance therefore both matter.

A convergence condition on head or another coupling variable can never replace the water-transfer identity. The two sides must refer to the same accepted interval and physical interface.

## What this page does not establish

This page does not establish a universal raw-code sign convention for every legacy or process variable, a universal mass tolerance, a universal time step, or an exhaustive list of active stores and boundaries for every SWAP5 configuration.

Those claims remain owned by their process, capability and qualification authorities. Where a local implementation sign differs from the normalized accounting convention, the translation must be explicit rather than assumed.
