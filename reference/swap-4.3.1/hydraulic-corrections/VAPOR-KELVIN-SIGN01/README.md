# VAPOR-KELVIN-SIGN01

This is a separate correction to the original SWAP4.3.1 isothermal vapor conductivity. Original models8..11 pass absolute suction to Kvap_func, whose Kelvin exponent has the wrong sign. Only that sign changes. Original diffusivity, density, units, liquid conductivity, retention and capacity parameters remain unchanged.

The primary PDI publication is [Peters2013](https://doi.org/10.1002/wrcr.20548). The [PDI authors' archived implementation](https://zenodo.org/records/10950456/files/pdi.py?download=1) applies a negative exponent to positive suction. The [2024 PDI overview](https://doi.org/10.1002/vzj2.20338), equation26, gives the Kelvin relation.

The manifest binds the complete original module and both complete corrected variants. The second variant composes the independently qualified model7 capacity derivative correction with the Kelvin sign correction; it introduces no other edit.

Component source and 80-digit exponential comparisons are research evidence. Coupled water/CDE, temperature/restart and public source/raw qualification are still required. This reference does not itself grant admission or whole-model equivalence.
