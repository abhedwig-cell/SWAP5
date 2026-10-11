# WOFOST admitted runtime scope

WOFOST is part of the SWAP5 Status-A baseline only through its **bounded qualified runtime scope**. The current claim concerns the admitted production path and its preservation evidence; it is not a blanket statement about every WOFOST interface, crop configuration or external implementation.

## Scientific role

Within the admitted composition, WOFOST supplies crop-development/production behaviour to the SWAP application through the qualified runtime path. The crop component interacts with the soil-water system through the interfaces and state exchanges admitted by the owning capability records.

The bounded scientific surface and the SWAP coupling boundaries are described in [WOFOST81 crop state and SWAP coupling](../science/wofost-crop-coupling.md). That page distinguishes the independently qualified crop-owned trajectories from SWAP-owned `RD`/`TRA` interfaces and from the runtime event-delivery contract.

## Status-A position

The WOFOST runtime capability is contained in the pinned scientific production baseline `50346642…`. F-CI89 is the current capability-specific runtime qualification/admission authority named by the Status-A traceability map. Same-tree scientific WOFOST smoke and extended checks are inherited by the Status-A release-readiness record.

The exact implementation and qualification details remain distributed across the owning WOFOST records; [Status-A traceability](../status-a/TRACEABILITY.md) is the navigation authority.

## SWAP 4.3.1 / Python WOFOST equivalence

The admitted runtime scope must not be confused with a complete proof that the Fortran WOFOST path in SWAP5 is scientifically equivalent to every independent WOFOST 8.1 implementation or to a particular Python reference experiment.

The review portal therefore keeps those questions separate:

- **Status-A WOFOST runtime admission**: current and admitted within its bounded contract;
- **additional SWAP 4.3.1 / Python WOFOST equivalence evidence**: useful supplementary validation when a properly defined experiment is accepted.

See [SWAP 4.3.1 and SWAP5 equivalence](../review/SWAP431_EQUIVALENCE.md) for the general equivalence discipline.

## Transaction and persistence considerations

Any crop state that is part of accepted model continuation must obey the same committed/candidate ownership rule as the rest of the admitted runtime. A future change that introduces new persistent crop state, retry-sensitive state or restart dependencies must establish those dependencies explicitly rather than inheriting coverage by assumption.

## Explicit nonclaims

The Status-A WOFOST row does **not** claim:

- a broad stable public WOFOST API;
- unrestricted compatibility with arbitrary external WOFOST implementations;
- proof of all crop-model options or crop files;
- automatic restart/MultiSWAP qualification for newly introduced crop state;
- application-wide SWAP 4.3.1 equivalence solely from the existence of F-CI89.

## Review questions

For a WOFOST-sensitive change, ask:

1. Is the change inside the admitted runtime path or a new mode?
2. Are soil-water/crop exchanges unchanged in meaning, units and timing?
3. Does new state affect restart, retry or MultiSWAP ownership?
4. Which scientific smoke/extended checks protect the changed surface?
5. Is an equivalence claim being made that requires an independent reference experiment rather than only regression evidence?

## MC-CROP01 authentic daily weather and rooted production continuation

**Current / canonically admitted at PR1207; O0/O2 qualified and preserved
(2026-10-11).** The authoritative stages and exact evidence are in
`integration/audits/MC_CROP01_ROOTED_WEATHER_PRODUCTION_STATUS.json`. This
successor extends the admitted PR1206 pre-emergence profile; it does not change
the pinned Status-A denominator or close the complete historical lifecycle.

The production entry point is the existing
`fmr_production_application_bootstrap_t`. Its `initialize_weather_crop_daystart`
and `run_weather_crop_daystart` methods commit the crop through the existing
F-WOF38/F-KT executor. Its `run_weather_interval` method uses the actual accepted
soil state and unchanged production dispatcher. The explicit configuration
requires both `file_weather_daystart` and `file_weather_rooted`, the Gregorian
epoch, latitude, emergence dry weight, DVS root-depth/density tables, maximum
root depth, existing Feddes parameters and canopy parameters. Stem/storage
area coefficients must match the crop transaction parameters. The rooted
interval requires the current committed crop with the application-owned
accepted lineage/revision/time; caller-supplied canopy does not authorize
the grown-root route.

One opaque record from the authenticated daily file supplies reference ET,
rain and air temperature to hydrology and temperature/radiation/astronomy to
the crop. The adapter retains the original radiation in kJ/m2 and Gregorian
day of year. Growth uses the historical `1000.d0 * radiation` conversion,
literal astronomy and `(tmax+tmin)*0.5d0` temperature operation order.
Explicit site parameters are not inferred from a weather filename.

Morning processing reads the next weather record and the previous accepted
soil state. The previous committed preparation/sowing/germination flags
authorize delayed emergence before new task3 accumulation. Initial biomass
is constructed in the crop candidate only. Later morning events complete
the preceding crop day with its retained immutable weather record and its
actual accepted root-uptake receipt. The next morning's weather cannot
substitute for that preceding growth forcing, and acceptance of the new
day's ending hydrology is not required for morning processing. Derived roots
and canopy then feed that new day's physical hydrological intervals.

The integrated regression uses seven authentic weather days, cold sowing
delay, germination, delayed emergence, four crop-growth completions and five
days of positive physical root uptake. It compares every leaf cohort and
crop continuation field plus accepted head/water/temperature/Richards
derivative postimages across O0/O2 and uninterrupted/pending-restart runs.
It retains the original four-day root-free cases and literal historical
oracles. Negative parameter/retry/duplicate checks require no committed
crop mutation; every accepted hydrological interval retains the hard mass
criterion. A separate existing-owner composition and next-day-weather
negative witness check the growth day and actual uptake receipt.

This profile is single-column annual IDSL1, reference ET, AIR/no-snow,
default-MVG bottom7 with ROOT_COMP_OFF. It does not qualify a complete
Andelst soil/crop trajectory, detailed meteorology, compensation, oxygen,
CO2 correction, alternative roots, harvest/rotation/fallow or SWINCO=3.
The joint opaque in-process continuation retains accepted soil/heat,
meteorological provenance, crop and event windows; an external disk codec
and a legacy CLI front end remain separate open requirements.

## MC-CROP01 current-day growth completion successor

**Implemented, persisted, O0/O2 tested, qualified, preserved and canonically
admitted by PR1209 (2026-10-11).** The owning receipt is
`integration/audits/MC_CROP01_DAYEND_PRODUCTION_STATUS.json`, under the
[current-window contract](../science/MC_CROP01_DAY_END_PRODUCTION_CONTRACT.md).
The existing bootstrap's `file_weather_dayend` opt-in and
`run_weather_crop_dayend` complete the current accepted F-KT daily window
using its own stored authentic meteorology and actual root extraction.
The crop transaction remains an ordinary positive interval; no soil replay,
synthetic tomorrow record or new state owner is introduced.

The next real daystart authenticates its meteorology and opens its physical
window without repeating the completed crop event. Joint in-process restart
covers partial, pending and accepted end-completed phases. The seven-day
integrated regression completes five emerged growth days, including the last
actual meteorological day, and retains full bitwise hydrology/uptake identity
with the admitted morning profile. Full crop/soil/heat/Richards O0/O2,
candidate rejection/retry, duplicate and foreign-owner refusal are checked.

The full moving F-CI and PPA-WU03 preservation controllers both terminated
with exit0 on clean head `9825deeef3c6c51dc28702e92291dcbdf7f439cf`, source
tree `b52c70dc50742fdbf5b03f71ec68709b191d0ec7`. Complete highest frost
qualification covers24 fresh configurations and144 fine comparisons,
byte-identical to the original authority. Raw owner, frost and full-controller
archives and exact execution postimages are pinned by the owning receipt.
Canonical merge `97f2d96e3cbe1cf34efba703a46e5ada0ea090a6` has exact tree
`4404f5f7daf30a2d527959445571b73dbdb49259`; source, execution dependencies
and all archived members verify against the qualified postimage.

This is growth completion, not the complete historical day-end chain.
Harvest, output-before-reset, physical rotation/fallow/new-season authority,
broader root/weather profiles and external disk restart remain open. All
PR1207 profile restrictions and the frozen Status-A denominator remain.
