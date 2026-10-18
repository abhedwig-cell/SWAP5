# KALM-S431-01: historical SWRAIN=3 integration smoke, 2026-10-18

Status: TESTED on GNU-built SWAP 4.3.1; NOT a Kalmthout scientific result.

## Source authority
- Source code inspected: `SWAP/MOD_meteo.f90`, `LoadRainData`.
- `SWRAIN=3` with `SWMETDETAIL=0` loads `RAINFIL`, fields `DAY,MONTH,YEAR,TIME,AMOUNT`.
- `TIME` is fraction of day in range [0,1], and `AMOUNT` (mm) is divided by the elapsed time since the previous endpoint to make a flux. Interval endpoint placement therefore matters, as do calendar-day crossings.

## Real executed test
- Starting point: shipped `cases/1.hupselbrook` in a separate local case copy.
- Case copy: `/mnt/data/kalm431/trials/hupsel_hourly_rain_smoke`.
- GNU SWAP4 executable: `/mnt/data/kalm431/build/swap_gnu`.
- Changed only test-case settings: `SWRAIN=3`, `RAINFIL='test.rain'`, `TEND=2002-01-05`, optional CSV output disabled as in previous smoke.
- Created 5 days of synthetic hourly endpoint rain records, retaining each day's original Hupsel daily amount in one midday interval. This is synthetic data for reader testing; NOT ERA5 or Kalmthout forcing.
- Executable process exit code: 100 (previous reference example also uses 100; do not interpret through Unix zero-only success semantics without program-specific confirmation).
- Log includes `RAINFIL: all rain data read and stored.` and `Swap simulation okay!`; model run-time 0.014611 sec.
- Two warnings: existing `Ksatexm` configuration and large dz solute warning. Neither is evidence for qualification of Kalmthout parameters.

## Identified Kalmthout source paths
- Sibling SWAP5 work branch `work/kalmthout-pilot-current-20261017`.
- `research/kalmthout_pilot/domain.json`: cell KAL_0496, EPSG:32631 E=600730/N=5690770, lat=51.3592544265/lon=4.4467564872.
- `research/kalmthout_pilot/fetch_era5land_daily.py`: produces 2024-01-01 through 2026-10-01 inclusive, UTC, hourly precipitation and daily SWAP-PM basic weather variables from ERA5 archive. Do not claim source files have been fetched until a real non-synthetic CSV is present and checked.
- Standalone local converter `/mnt/data/kalm431/convert_kalmthout_forcing.py` exists; it has not been exercised with real Kalmthout weather and is not yet scientifically qualified.

## Next test gates
1. Fetch or recover the exact non-synthetic 24,120-hour weather CSV and store its hash.
2. Run converter and check 1005 complete days, no missing hours, exact preservation of total precipitation and daily weather variables.
3. Run short SWAP4 case with these real converted files, then full duration; require input parity, physically qualified parameterization, model closure and scientific comparison.
4. Consider deriving a fresh independent input source only with explicit provenance, never substitute Hupsel forcing as Kalmthout forcing.
