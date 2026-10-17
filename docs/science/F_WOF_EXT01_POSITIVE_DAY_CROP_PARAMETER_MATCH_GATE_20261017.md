# F-WOF-EXT01 positive SWAP5–PCSE daily equivalence: independently confirmed parameter mismatch (2026-10-17)

## Executed paired-source gate

At SWAP5 research commit `26d33e4c5c746d358b7cd5808cc3974daf06dc3e`, [Actions run 39072642044](https://github.com/abhedwig-cell/SWAP5/actions/runs/39072642044) **SUCCESS**, both `native-fortran` and `protocol-probe`. New `tests/fwof/ext01/test_cross_source_crop_parameter_authority.py` checks *the real native rooted-weather test's Fortran `make_bundle`* against *the actual PCSE source YAML variety `Spring_barley_301`* in the same runner where the repositories are checked out.

Log marker: `EXT01_AUTHENTIC_SWAP_VS_PCSE_CROP_PARAMETER_NONMATCH_PROVEN`.

| Scientific control | Native physical rooted-weather SWAP5 | PCSE Spring_barley_301 |
|---|---:|---:|
| TSUM emergence→anthesis | 1000 | 800 |
| TSUM anthesis→maturity | 800 | 750 |
| Daylength development mode | 1 | 0 |

This difference is **intentional in the independent existing SWAP5 physical benchmark**, not a proven SWAP5 WOFOST bug. The actual accepted hydrological event is additionally anchored to 1999-01-23; the currently qualified PCSE barley case is on a 2010 crop calendar. Therefore plugging the real native accepted numerical flux into the unrelated PCSE crop cannot establish physically matched-day equivalence even though numeric transport and PCSE atomic commit PASS separately.

## Scientific consequence and next research implementation

A positive coupled scientific experiment requires one *single authority* for crop variety/parameter version, initial state and meteorological input used by both the physical SWAP5 hydrological experiment and the external PCSE day. Two valid construction routes remain: (1) instrument a physical SWAP5 trial driven by the already pinned Spring_barley_301 PCSE parameters/2010 weather, with full mass and time authority; (2) implement and qualify a PCSE-compatible 1999 driver for the actual SWAP rooted weather data and matched SWAP rooted crop parameter set. The 2010 route may be more directly reusable with the existing proven Python–Fortran new-barley scientific qualification, but it requires matching physically accepted SWAP5 water rather than transplanting numbers.

An end-to-end acceptance gate should refuse mismatched `crop_parameter_sha256`, `weather_source_sha256`, calendar-day, source cell/column lineage + accepted revision, physical mass-balance preimage and actual/potential cm/day integrated units. It must not trust caller-supplied unverified prose claiming physical acceptance. Research PRs SWAP5 #1279 and PCSE #9 remain open; do not merge to canonical or change admitted WOFOST81 physics until a positive experiment passes.

## Persisted paired-source identity artifact

The executed mismatch check was extended into a versioned `F-WOF-EXT01/CROP-PARAMETER-PAIR/1` JSON manifest (research commit `cfadead9e368c0ebfec1085ef677244c0e1406ed`), with raw SHA256 of real `tests/fmig431/test_crop_file_weather_production.f90`, PCSE `pcse/tests/test_data/ext01_barley_wofost81_source.yaml`, native SWAP source `b111-andelst_meteo.999.gz` and PCSE `wofost81_qualification_weather.yaml`. It explicitly sets `same_crop_parameter_case=false`, `same_calendar_and_weather_case=false`, `positive_daily_science_admitted=false` and records the physically distinct native 1999 versus pinned PCSE 2010 crop calendars. The paired native workflow retains this JSON in `ext01-research-native-fortran-comparison`. **EXECUTED PASS:** [SWAP5 Actions run 39072967988](https://github.com/abhedwig-cell/SWAP5/actions/runs/39072967988) completed SUCCESS in both protocol-probe and native-fortran jobs; native log contains `EXT01_AUTHENTIC_SWAP_VS_PCSE_CROP_PARAMETER_NONMATCH_PROVEN` and `EXT01_O0_O2_IDENTICAL_NO_SCIENCE_ADMISSION`. The paired-source manifest and comparison materials are retained in actual artifact `ext01-research-native-fortran-comparison`, id **12116061778**. Neither this manifest nor any transport test may be used to manufacture a positive matched daily SWAP–PCSE scientific comparison.
