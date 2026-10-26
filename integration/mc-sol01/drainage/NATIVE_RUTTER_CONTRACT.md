# Original crop/Rutter forcing preparation

HIST-INTEGRATION01 baseline e15d5ffd1b28701eb96da7ae817f85c47a15a597.
The original native reader rejects SWINTER3. Add an explicit preparation-only
`native-rutter` option, retaining the default rejection until full native water
application is supported. Reuse production phenology, cover, ETref and Rutter
source-window owners. No hydraulic process or generic dispatcher is changed.

Original MOD_meteo:ETpot provides dry/wet transpiration and wet-canopy evaporation
under SWETR1/SWMETDETAIL0. Original MOD_cropdevelopment:interception reads
SICCAPLAI in [0,.5] and initializes SICACT to zero. Source SICACT text is not an
override of that historical behavior. Capacity is SICCAPLAI*LAI. The admitted
INT13 capacity transition to surface throughfall is deliberately retained,
as specified in integration/audits/F-MIG431-INT13_CORRECTED_REFERENCE.md.

The additive production ETref entry point must reproduce the actual original
ETpot procedure, with unchanged ordinary demand outputs. Explicit crop preparation
emits a companion immutable Rutter demand table. This does not claim the full
original macro/heat/crop application, a file restart or original-model parity.
Invariants2,3,7,9,13,21,23,29 remain unchanged.

Use small O0/O2 real-provider/original-source tests, original crop and weather
preparation, no-interception output differential, rejection before publication,
and existing production Rutter source-window composition. No broad F-CI or long
original112-node rerun is selected for this input/process seam.
