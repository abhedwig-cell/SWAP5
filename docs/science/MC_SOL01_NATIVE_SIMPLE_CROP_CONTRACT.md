# Native simple-crop preparation successor

Status: locally qualified bounded preparation successor. Canonical admission is
recorded in the existing MC-SOL01 recovery record; not whole-model admission.

This MC-SOL01 successor prepares a single original SWP/CROPTYPE=1 period,
CRP tables and a consecutive native daily MET calendar. The explicit executable
`swap5_read_crop` writes day-start DVS, LAI, vegetation cover, bounded root depth
and potential ETref partitions. It does not advance accepted water or chemical
state and must not be described as actual transpiration or a live coupled crop.
The remaining hydraulic/root/solute handoff is a separate composition obligation.

`mod_crop_fixed_phenology` ports the two original `fixed.f90`
`update_cropfixed` branches. A day event proposes a candidate from an immutable
input state. IDEV=1 uses `min(DVS+2/LCC,2)`; IDEV=2 uses the mean-air-temperature
excess and the denominator selected from the **beginning** DVS, including a day
crossing anthesis. No within-day phase splitting is invented. Temperature sums
must be strictly positive, excluding the original division by zero. The original
IDEV=1 reader leaves TBASE unspecified; its TSUM is not an admitted output. The
new typed parameters initialize it to zero, without changing the fixed-cycle DVS.

Existing production calendar, rate-table, canopy, ETref and DVS-root-depth owners
supply the other equations. Native TTUTIL supplies dates, strings and tables.
The executable accepts one explicit CRP/MET basename, a whole-day run beginning
before or on emergence, immediate preparation/sowing/germination, SWETR=1,
SWCF=1, SWRD=1, no interception/CO2 correction, and SWCFBS=SWREDU=0.
Harvest is calendar based or checked after the original end-of-day DVS update.
All input and computed daily values are validated before creating output.

No crop stress parameters, actual root density/extraction, irrigation, heat,
snow, water age, nutrients, source-full default orchestration or restart of a
coupled crop is admitted by this preparation adapter. Their state and execution
owners remain unchanged. No existing reader or physical column is activated by
this option. A caller must not confuse these prepared potential rates with an
accepted hydraulic receipt.

Affected architecture invariants: 2,3,7,9,21,23,29. File parsing stays outside the
process module; biological daily events have explicit ordering; rejected proposals
leave inputs unchanged; no solver choice changes physics.

Qualification selects a small native O0/O2 driver against literal original
`fixed.f90` procedures, native TTUTIL import, exact production canopy/ETref/root
composition, invalid-state/input rejection and repeat/split continuation. Existing
water/solute/NUT numerical inputs are unchanged and their current capsule is
validated against every executed provider. New potential forcing values do not
select fresh unchanged solver qualification. Full F-CI is NOT_SELECTED_IMPACT;
highest low-air is NOT_SELECTED_POLICY.

The native proof executes 52 processes, compares 576 values exactly with the
original executable, repeats eight prepared schedules in independent processes,
and rejects 22 invalid inputs before any CSV creation. Both checked optimization
levels also execute the one-provider state contract through the existing modular
runner. Very small positive thermal denominators saturate the same final DVS
without an overflowing intermediate division; invalid cumulative-state bounds
reject rather than emit an unusable candidate.

Build and use explicitly (the executable creates `crop_daily.csv` in its working
directory; all three source files must be staged there):

```bash
python -B tools/solute/build_crop.py --optimization O2 --output /tmp/crop-reader
/tmp/crop-reader/swap5_read_crop input.swp crop.crp weather.met
python -B tests/modularity/run_modular_tests.py --case fixed_crop --output /tmp/crop-contract
```

A single original crop is a one-row native table with column names
`CROPSTART CROPEND CROPFIL CROPTYPE`; scalar assignments are not the original
RDATIM/RDFTIM grammar. The adapter validates each array count before the TTUTIL
fixed-count reads. Original malformed-input diagnostics and early development
failures remain in the evidence capsule and do not count as passing runs.
