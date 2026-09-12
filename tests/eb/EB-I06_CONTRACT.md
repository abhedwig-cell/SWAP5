# EB-I06 — Oriented Water Donor Temperature Contract

## Authority and purpose

EB-I06 defines the minimal donor-temperature selection rule required to attach a physically explicit temperature to an already quantified, oriented liquid-water transfer without embedding geometry, boundary type, solver internals or application context in the energy primitive.

Restart authority:

`integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`

Owner-qualified technical content head:

`ec8a58335047ef322cba70b8965f3d968e472381`

Technical owner qualification:

- workflow run `34723155525`
- job `103632549039`
- current-canonical race guard: PASS
- exact technical delta: PASS
- GNU Fortran `-O0`: PASS
- GNU Fortran `-O2`: PASS
- optimization-invariant evidence output: PASS

Production delta:

- `src/process/mod_oriented_water_donor_temperature.f90`

## Orientation contract

The input `oriented_water_amount_cm` is an interval water amount with an already defined orientation between two logical endpoints A and B.

- `Q > 0`: water moves `A -> B`; donor is A.
- `Q < 0`: water moves `B -> A`; donor is B.
- `Q = 0` exactly: no water is transported, therefore no donor temperature is required.

EB-I06 does not reinterpret or change the magnitude or sign of `Q`.

There is deliberately **no small-transfer tolerance**. Any finite nonzero transported water amount requires a valid donor temperature. This prevents small but real mass transfers from silently losing their associated sensible-energy transport.

## Availability and fail-closed behavior

Only the endpoint that is the donor for the actual transfer direction is required to have an available, finite temperature.

The unused endpoint may be unavailable or non-finite without invalidating the transfer.

If the selected donor temperature is unavailable, EB-I06 fails closed with `OWDT_DONOR_UNAVAILABLE`.

If the selected donor is declared available but its temperature is non-finite, EB-I06 fails closed with `OWDT_INVALID_DONOR_TEMPERATURE`.

A non-finite water amount fails with `OWDT_INVALID_TRANSFER`.

## Geometry and process independence

A and B are logical endpoints, not hard-coded meanings such as upper/lower, soil/atmosphere, SWAP/MODFLOW, drain/soil, root/soil or surface/subsurface.

The owning adapter or runtime composition is responsible for mapping the physical process to A/B and for supplying temperatures. Examples of later use are:

- internal soil face: A and B are neighboring compartments in the chosen flux orientation;
- top boundary: an inward transfer needs an explicit external-water donor temperature, while outward water uses the soil-side donor temperature;
- bottom boundary: groundwater inflow needs an explicit external groundwater-water temperature, while drainage/outflow uses the soil-side donor;
- root uptake or drainage sink: the donor is the source compartment if the transfer is oriented from soil to sink;
- irrigation, precipitation, ponding, snowmelt or other external additions: the external source temperature must be provided explicitly by the appropriate forcing/component contract.

These examples are mapping rules for later adapters, not additional physics implemented by EB-I06.

## Relation to upwinding

For sensible-energy advection, EB-I06 implements the minimum donor/upwind selection implied by the direction of the transported water amount. It does not implement spatial reconstruction, higher-order advection, dispersion, mixing, thermal equilibration during transit or temporal quadrature.

A future numerical transport formulation may use a higher-order face temperature, but it must still preserve conservation and must state explicitly how the transported water's energy is defined. EB-I06 therefore qualifies a first-order donor rule, not all possible energy-advection discretizations.

## Relation to other EB owner branches

EB-I06 has no production dependency on EB-I01, EB-I03, EB-I04 or EB-I05.

Conceptually, a later composition can combine:

1. an accepted/trial interval water amount,
2. this donor-temperature rule,
3. an explicit liquid-water sensible-enthalpy law,
4. transactional energy-ledger publication.

That composition is a separate workunit and is not qualified here.

## Temperature provenance

EB-I06 never invents a temperature. In particular it does not assume that:

- precipitation temperature equals air temperature;
- irrigation temperature equals air or soil temperature;
- groundwater temperature equals bottom-soil temperature;
- ponded water equals surface-soil temperature;
- root xylem or drain water temperature can be inferred without an explicit process rule.

Such provenance belongs to forcing, component or coupling interfaces outside this selector.

## Time semantics

The transfer amount may represent any qualified interval `[t0,t1]`. EB-I06 has no day, month, year or fixed-step concept.

The selected donor temperature is a value supplied for that transfer. EB-I06 does not state whether it is an endpoint, midpoint, average or flux-weighted interval temperature. A later composition that converts interval water amount to interval energy must qualify that temporal convention explicitly.

## Transaction semantics

The selector is deterministic and stateless. It is safe to call during trial/retry calculations, but EB-I06 itself does not publish accepted results and does not alter committed state. Rollback/commit integration remains the responsibility of the later transactional energy composition.

## Hard nonclaims

EB-I06 does not claim:

- a full SWAP5 energy balance;
- any Joule or heat-flux calculation;
- a source of precipitation, irrigation, groundwater, pond, snowmelt, root or drainage water temperature;
- a temporal averaging/quadrature rule for donor temperature;
- higher-order advective heat transport, dispersion or mixing;
- vapor transport or latent heat;
- freeze/thaw phase transport;
- runtime transaction publication;
- MultiSWAP throughput or bounded-cost qualification;
- independent verification;
- canonical admission.
