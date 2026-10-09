# Kalmthoutse Heide SWAP5 pilot

This work directory is an operational research pilot and is not a canonical scientific admission record.

## Official domain

The PCP-WISE use-case extents received on 2026-10-09 replace the earlier screenshot-derived provisional boxes.

All pilot processing uses **EPSG:32631**.

| extent | xmin | ymin | xmax | ymax | size |
| --- | ---: | ---: | ---: | ---: | ---: |
| total | 579980 | 5674020 | 619980 | 5715020 | 40 x 41 km |
| minimal | 592980 | 5683020 | 608980 | 5699020 | 16 x 16 km |

The supplied total-extent GeoPackage is correctly tagged EPSG:32631. The supplied minimal-extent GeoPackage has srs_id=99999 / Undefined SRS; its coordinate range and project context place it on the same EPSG:32631 grid. The pilot therefore records EPSG:32631 explicitly in domain.json instead of inheriting the broken CRS tag.

## Pilot grid and representative column

The minimal extent is divided into a 500 m grid: 32 x 32 = 1024 cells. Cell IDs are row-major from the southwest. Because the exact domain centre lies on a four-cell intersection, the deterministic tie-break is west and south. The representative central cell is therefore:

```text
KAL_0496
centre: E 600730, N 5690770 (EPSG:32631)
lon/lat: 4.4467564872 E, 51.3592544265 N
bounds: 600480,5690520,600980,5691020
```

build_grid.py regenerates the full grid from domain.json.

## Meteorological period

The current pilot forcing period is 2024-01-01 through 2026-10-01 inclusive. The hourly meteorological extraction point is the representative cell centre above. The current fetcher uses ERA5 through the archive API used by this research pilot; this is distinct from the final PCP-WISE data-delivery contract.

## Current numerical status

The long-run application work remains experimental. The Rutter/dynamic atmospheric boundary has been stress-tested with real hourly rainfall and exposed a strict transaction/mass-tolerance issue under wet forcing. The pilot must not be cited as a qualified SWAP5 application until the focused owner/preservation gates close.
