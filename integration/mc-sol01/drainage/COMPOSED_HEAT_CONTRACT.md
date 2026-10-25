# Numeric heat with existing Boesten, drainage and Cauchy owners

Baseline `d6378c7ac492a9e051b04468b814be6d1d54d121`, HIST-INTEGRATION01.
This is an existing-owner composition. Physical equations, water/solute/energy
criteria, trial acceptance and root demand reconciliation remain unchanged.
Boesten SPEV/SAEV remain in `fmr_b110_boesten_evaporation_state_t`, whose base
already carries optional soil temperature. No new kernel state class is added.

The existing constructor gains an optional final `parameters` argument, following
the established base-state constructor contract, to certify initial heat identity.
The Boesten optional-state family accepts its inherited ready numeric heat state;
without heat its existing contract and bytes stay unchanged. Existing caller
interfaces remain source compatible; all affected compiled consumers are rebuilt.

Thermal restart S5PT0001 remains byte exact. Additive S5PT0002 is selected only for
Boesten plus heat, under the existing Boesten template. It stores exact SPEV/SAEV
after the pressure/water/pond/groundwater/temperature payload, with existing CRC,
immutable heat/chemistry parameter binding and atomic publication. Boesten COFRED
is included in the new heat parameter vector. Wrong tags, pair values, parameters,
checksums and initialized targets reject before authoritative destination mutation.
The launcher inventories temperature output for either thermal tag.

The thermal joint route validates the same gross Boesten forcing provenance as
the nonheat joint route, then stages water/heat and external chemistry. Numeric
heat trace admission extends to the existing Boesten template; DRAMET3 and
Picard/Cauchy retain their present physical and numerical restrictions. The new
combinations still exclude macrosolute, snow/frost, analytic heat, elasticity,
power tails and active KSATEXM/Picard. A successful constructed profile is not a
claim of full original Andelst migration.
