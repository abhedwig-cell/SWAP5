# GC-RZM06D03 cross-time origin-selection result

Date: 2026-09-22  
Preregistration: `c1f96aa01d07564c2166f1346ef383ec2357406a`  
Qualified workflow: `35739393743`, job `106784863436`  
Production changes: none

## Decision

D03 is qualified as:

`QUALIFIED_CROSS_TIME_STRICT_DISCOVERY_NO_MATCH__H2_NOT_PROBED`.

D02R1 had already shown that original ROM library time can be treated as provenance for this pure-hydraulics carrier when both selected profiles are later reseeded at one common canonical time. D03 therefore removed only the extra same-library-time constraint. The physical H2 gates were unchanged.

## Census

The exact ROM1AR2 artifact was verified at its retained digest. Selection used only DISCOVERY state provenance and 16-node H/theta records.

- 768 total state records seen;
- 512 DISCOVERY metadata records;
- 475 eligible records with producing interval `FALLBACK=F`;
- 37 DISCOVERY records excluded because their producing interval used research fallback;
- 0 HELD_OUT node observables parsed;
- 0 response/exchange fields parsed;
- 98,693 different-history candidate pairs;
- 808 pairs satisfying `|delta W_profile| <= 1e-4 cm`;
- 0 pairs also satisfying `|delta M1| >= 1e-2 cm`.

The strongest water-matched pair was D02 step 64 versus D08 step 44:

- `|delta W_profile| = 6.094551292790129e-05 cm`;
- `|delta M1| = 0.007836912353482717 cm`;
- 78.37% of the frozen M1 requirement.

No HeadCalc response probe was performed.

## Interpretation

The result does not falsify H2. It shows that the existing strict DISCOVERY library does not contain a state pair that satisfies the preregistered equal-water/different-distribution construction gate.

The next justified move is not threshold relaxation or held-out unblinding. It is prospective state-space expansion on the qualified C01 carrier, with forcing chosen to alter vertical redistribution while preserving total storage as directly as possible.

A particularly clean construction is a fixed-flux control pair: one equilibrium-throughflow family and one closed-column family. Equal top and bottom fluxes make the external integrated flux divergence zero by construction, while changing the flux level changes the internal hydraulic gradient. E01 preregisters that construction before execution.

No production admission follows from D03.
