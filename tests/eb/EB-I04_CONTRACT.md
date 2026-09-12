# EB-I04 — Liquid-Water Sensible Enthalpy Contract

## Authority and purpose

EB-I04 is a small, solver-independent energy primitive for liquid-water sensible storage and liquid-water sensible-energy transport. It is intentionally separate from the unadmitted EB-I01, EB-I02 and EB-I03 owner branches.

Restart authority:

`integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`

Owner-qualified technical content head:

`09335cfd8233d2b1c5747ce50bbc3772afe9fd98`

Owner qualification:

- workflow run `34721280461`
- job `103627495883`
- current-canonical race guard: PASS
- frozen thermal-context preservation: PASS
- GNU Fortran `-O0`: PASS
- GNU Fortran `-O2`: PASS
- optimization-invariant evidence output: PASS

Production delta:

- `src/process/mod_liquid_water_sensible_enthalpy.f90`

Frozen current-canonical thermal context remains byte-identical:

- `src/process/mod_soil_temperature_contract.f90` blob `baa13df3975de2c699b0ec910477bcfa9b47f15e`
- `src/process/mod_restricted_soil_temperature.f90` blob `fa4e1d7b48d3515e6569c9080d497178c25c4e85`

## Physical scope

EB-I04 uses a constant-property liquid-water sensible-energy convention with explicit parameters:

- liquid-water density `rho_w` [kg/m3];
- liquid-water specific heat `c_p,w` [J/kg/K];
- energy reference temperature `T_ref` [degC].

No production constant for `rho_w`, `c_p,w` or `T_ref` is hidden in the module. The tests use `rho_w = 1000 kg/m3` and `c_p,w = 4180 J/kg/K` because those are the current source-bound liquid-water values in the admitted restricted soil-temperature implementation.

This workunit does not model vapor sensible/latent transport, ice, freeze/thaw latent heat, pressure enthalpy, salinity, temperature-dependent properties or a complete soil/surface energy balance.

## Liquid sensible storage

For liquid-water depth `W` in cm at temperature `T`, the energy relative to `T_ref` is

`U_l = 0.01 * rho_w * c_p,w * W * (T - T_ref)` [J/m2].

For one soil compartment of thickness `dz` [cm] and liquid volumetric water content `theta`,

`U_l = 0.01 * rho_w * c_p,w * dz * theta * (T - T_ref)`.

Between interval endpoints 0 and 1, EB-I04 evaluates the exact constant-property endpoint difference

`DeltaU_l = K * dz * [theta_1*(T_1-T_ref) - theta_0*(T_0-T_ref)]`,

with `K = 0.01*rho_w*c_p,w`.

Using arithmetic endpoint averages, this has the exact algebraic decomposition

`DeltaU_l = K*dz*[theta_avg*DeltaT + (T_avg-T_ref)*Deltatheta]`.

EB-I04 exposes both components and their decomposition residual. The first component is the temperature-change contribution at average liquid content. The second is the sensible-energy consequence of changing liquid-water storage at average water temperature.

This distinction is important because a bookkeeping scheme based only on `C(theta_avg)*DeltaT` cannot by itself represent the liquid-water storage term proportional to `Deltatheta`.

## Relation to the current restricted thermal solver

The admitted restricted soil-temperature solver evaluates a total sensible heat capacity at average water content and multiplies it by temperature change. That total capacity contains solid, liquid-water and air contributions.

EB-I04 must therefore **not** be added wholesale to the current restricted `sensible_storage_change` as though it were an independent complete correction. A later composition must avoid double-counting the liquid `theta_avg*DeltaT` part and must explicitly decide how gas/air sensible storage is scoped when water content changes.

Consequently EB-I04 alone does not prove whole-soil energy conservation.

## Liquid sensible transport

For an already oriented liquid-water transport amount `Q` [cm] and an explicitly supplied advected-water temperature `T_adv`, EB-I04 evaluates

`E_adv = 0.01 * rho_w * c_p,w * Q * (T_adv - T_ref)` [J/m2].

The sign of `E_adv` inherits the sign of `Q`. EB-I04 never changes the transport orientation and never infers the donor/upwind temperature.

This is deliberate. A later composition must qualify the physical temperature supplied for each interface, including at least:

- internal soil faces;
- infiltration from precipitation or irrigation;
- evaporation/outflow at the top boundary;
- capillary inflow from groundwater;
- drainage/outflow at the bottom boundary.

Using air temperature automatically for infiltrating water, or soil temperature automatically for groundwater inflow, is outside this contract and must not be introduced silently.

## Reference-temperature semantics

`T_ref` is an explicit energy-reference gauge. Changing it changes the reported sensible energy whenever water mass/storage or transported water amount is nonzero. EB-I04 tests the exact expected reference-shift identities.

`T_ref` must never be tuned to make an energy residual appear smaller. A physically consistent control-volume balance must apply one coherent reference convention to storage and all mass-carried energy terms so that observable closure does not depend on an arbitrary gauge choice.

## Data and transaction semantics

The parameter type is immutable configuration by intended use. All calculated energies are result data. EB-I04 adds no dynamic state, restart state, solver workspace or worker scratch.

The routines are deterministic algebraic evaluations. They mutate no committed model state and can be recomputed cheaply. Transactional publication into a committed energy ledger is intentionally deferred to a later composition workunit.

## Relationship to later EB composition

EB-I04 has no source dependency on the unadmitted EB-I01 ledger, EB-I02 thermal conservation view or EB-I03 hydraulic phase-flux view.

A later current-canonical recomposition may combine independently qualified/admitted equivalents of those capabilities. That later work must still qualify:

1. transaction/rollback behavior of energy entries;
2. mapping from signed liquid transport to physical donor temperature;
3. internal-face cancellation and boundary bookkeeping;
4. avoidance of storage double counting;
5. gas/vapor and phase-change coverage semantics;
6. energy-reference consistency across all external mass fluxes.

## Hard nonclaims

EB-I04 does not claim:

- a full SWAP5 energy balance;
- a full soil sensible-energy storage law;
- vapor or latent-energy transport;
- freeze/thaw enthalpy;
- a qualified donor/upwind temperature rule;
- precipitation, irrigation or groundwater temperature physics;
- runtime commit/rollback integration;
- MultiSWAP throughput qualification;
- bounded-cost qualification;
- independent verification;
- canonical admission.
