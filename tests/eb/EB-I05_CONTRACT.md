# EB-I05 — De Vries Sensible Storage State Law

## Authority and purpose

EB-I05 formalizes the exact sensible-energy state function implied by the current admitted restricted soil-temperature heat-capacity law in its physical domain `0 <= theta <= theta_sat`.

Restart authority:

`integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`

Owner-qualified technical content head:

`945e97fd409c1e8e1e665bca70b52e3b91176b83`

Technical owner qualification:

- workflow run `34722716224`
- job `103631381048`
- current-canonical race guard: PASS
- frozen thermal-source preservation: PASS
- GNU Fortran `-O0`: PASS
- GNU Fortran `-O2`: PASS
- optimization-invariant evidence output: PASS

Production delta:

- `src/process/mod_linear_mixture_sensible_storage.f90`

The admitted thermal source remains byte-identical:

- `src/process/mod_soil_temperature_contract.f90` blob `baa13df3975de2c699b0ec910477bcfa9b47f15e`
- `src/process/mod_restricted_soil_temperature.f90` blob `fa4e1d7b48d3515e6569c9080d497178c25c4e85`

## Canonical heat-capacity law

The admitted restricted soil-temperature implementation evaluates

`C(theta) = C_solid + theta*C_liquid + (theta_sat-theta)*C_gas`

for physical water contents below saturation, with all capacities expressed in `J/cm3/K`.

The current source obtains the gas fraction as

`f_air = theta_sat - theta`

inside the physical interval. Consequently `C(theta)` is affine in `theta`.

EB-I05 does **not** duplicate the mineral, water or air density/specific-heat constants in production code. Instead it accepts the already assembled volumetric heat-capacity contributions explicitly. The test instantiates those parameters from the current source-bound SWAP values.

## Exact sensible-energy state

For a compartment with thickness `dz` [cm], water content `theta`, temperature `T`, and a common energy-reference temperature `T_ref`, EB-I05 defines

`U(theta,T) = 1e4 * dz * C(theta) * (T-T_ref)` [J/m2].

The factor `1e4` converts `J/cm2` to `J/m2`.

For interval endpoints 0 and 1:

`DeltaU = U(theta_1,T_1) - U(theta_0,T_0)`.

Because `C(theta)` is affine, arithmetic endpoint averages give the exact identity

`DeltaU = 1e4*dz*[ C(theta_avg)*DeltaT + (C_liquid-C_gas)*(T_avg-T_ref)*Deltatheta ]`.

EB-I05 exposes:

- exact endpoint storage change;
- start, end and average mixture heat capacity;
- the `C(theta_avg)*DeltaT` temperature-change component;
- the composition-change component proportional to `Deltatheta`;
- the algebraic decomposition residual.

## Relation to the admitted restricted solver

The admitted restricted soil-temperature solver currently reports sensible storage as

`sum(C(theta_avg) * dz * (T_new-T_old))`.

Within the EB-I05 physical scope, this equals exactly the first component of the state-law identity above. It omits the second component whenever both:

- water content changes, and
- the average temperature differs from the common reference temperature.

Therefore the present `C(theta_avg)*DeltaT` bookkeeping is not, by itself, the endpoint difference of the full linearly mixed sensible-energy state when pore occupancy changes.

EB-I05 does not modify the admitted solver or declare it incorrect for its previously qualified restricted scope. It adds a conservation accounting primitive that makes the omitted composition-storage term explicit for later energy-balance composition.

## Water-for-air replacement identity

For the current SWAP source values used by the EB-I05 reference test,

- liquid volumetric heat capacity is `4.18 J/cm3/K`;
- air volumetric heat capacity is `0.001212 J/cm3/K`.

When `theta` increases at fixed porosity, added liquid displaces the same pore volume of air. The exact storage-composition slope is therefore

`dC/dtheta = C_liquid - C_gas`,

not `C_liquid` alone.

For the qualified reference case (`dz=10 cm`, `theta: 0.20 -> 0.22`, `T_avg=11 C`, `T_ref=0 C`):

- pure-liquid moisture contribution: `91960.000 J/m2`;
- displaced-air contribution: `26.664 J/m2`;
- exact mixture composition contribution: `91933.336 J/m2`.

This distinction is small numerically for air but is required for a formally closed sensible-storage state law.

## Relation to EB-I04

EB-I05 has no source dependency on the unadmitted EB-I04 branch.

Conceptually, EB-I04 isolates liquid-water sensible storage/transport, whereas EB-I05 describes the complete **current linear sensible mixture storage law** for fixed solid fractions plus liquid and gas pore occupancy.

A future composition must not add the full EB-I04 liquid storage change on top of the full EB-I05 mixture storage change. Doing so would double count liquid sensible storage. EB-I04 remains useful for mass-carried liquid energy transport and for phase-specific decomposition; EB-I05 is the stronger primitive for the total current sensible-storage state.

## Reference-temperature semantics

`T_ref` is an explicit gauge. For fixed composition (`Deltatheta=0`), the storage change is independent of `T_ref`. When composition changes, shifting `T_ref` changes the sensible-energy difference by the exactly predictable mass/composition term.

A later full control-volume balance must use one coherent reference convention across storage and all mass-carried energy fluxes. `T_ref` must never be tuned to reduce a residual.

## Physical and architectural scope

EB-I05 is a deterministic algebraic result primitive. It adds no dynamic state, restart state, solver workspace, files, I/O contract, calendar assumption, groundwater-specific behavior or MODFLOW dependency.

It deliberately requires `0 <= theta <= theta_sat`. The admitted restricted solver tolerates tiny numerical excursions around saturation for hydraulic-view validation and then clips air fraction with `max(0,theta_sat-theta)`. EB-I05 does not extend its exact affine-state claim into that tolerance/clipping region; a later composition must decide how such out-of-domain trial values are handled before conservation publication.

## Hard nonclaims

EB-I05 does not claim:

- a full SWAP5 energy balance;
- latent heat, freeze/thaw enthalpy or vapor transport;
- temperature-dependent thermophysical properties;
- pressure, chemical or salinity enthalpy;
- a replacement of the admitted soil-temperature solver;
- that the current solver's temperature trajectory is unchanged if a future energy-conservative formulation adds the composition-storage term to the governing equation;
- liquid advective-energy transport or donor/upwind temperature physics;
- runtime commit/rollback integration;
- MultiSWAP throughput or bounded-cost qualification;
- independent verification;
- canonical admission.
