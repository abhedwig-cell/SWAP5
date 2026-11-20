# Proposed original Divdra overlap bookkeeping correction

This is a proposed corrected reference, pending standalone actual production
O0/O2 qualification and later bounded integrated admission. It does not open
any public guard or change the existing Frost geometry qualification.

The actual original `Lev2Comp` returns the thickness above a supplied level
and the thickness below it. `Divdra` requests the above-bottom thickness for
the bottom of an infiltration layer, then overwrites it with the thickness
below the water level when both levels occupy one cell. The existing later
intersection formula consequently subtracts the within-cell extent twice.

The original production Frost/Divdra driver fails at a cell spanning depths
30–70 cm, water level 50 cm and infiltration bottom 70 cm. Actual conductivity
is positive (`2e-10 cm/day` horizontally); the saturated interval is 20 cm.
The observed original calculation produces `KDsat=0` and traps on division.
All required interface fields and the original fixed conductivity floor are
present; no substitute conductivity or epsilon water is selected.

The proposed change removes only the overwrite. The actual `Lev2Comp` result
and the existing transmissivity/intersection equations then operate on their
declared geometric quantities. Qualification must compare the actual complete
production procedure against an independent geometric conductivity integral,
including within-cell water levels, one-cell infiltration intervals, original
zero/negative results and unaffected intervals. It must retain the original
failed native execution and both whole source identities.

No balance receives compensating mass. Existing tolerances, conductivity
equations, front interpretation and transaction semantics remain unchanged.
Use of this corrected reference outside explicitly qualified bounded domains
remains unadmitted.
