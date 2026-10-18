# KALM-S431-01: echte Kalmthout meteorologie, volledige SWAP4.3.1 GNU-test

Datum 2026-10-18. Status: technische integratietest PASS; wetenschappelijke Kalmthout-kwalificatie OPEN.

## Gegevens gerecupereerd zonder API of nieuwe CI
- SWAP5 bestaande GitHub Actions run 39122723811, artifact 12135007790 (`kalmthout-current-pilot`, checksum van artifact sha256:78c54c055409e52717c5295029950e7d7888f4aeb64132eaae4cf96aad82e23f).
- `weather.csv` SHA256 `bfca10d3c536173d2009cccea5c7c4e66d137aa15a5a203d941e95834a4af66d`.
- Locatie KAL_0496: 51.3592544265 N, 4.4467564872 E.
- Bereik: 2024-01-01T00 tot 2026-10-01T23 UTC, precies 24.120 uur / 1.005 dagen.
- Oorspronkelijke cumulatieve uur-neerslag: 2216,6 mm.
- Omzetting uitgevoerd met `convert_kalmthout_forcing.py`: `kalmthout.met` SHA256 `8b174ca14ec62dd68076bdcfbb64e28dcb1ddaf436295ffd91109f3e08e7a191`, `kalmthout.rain` SHA256 `07490ab97f046749a358171bc8eb1f8bf9be77e3124c59fc0b1eb3e0d09a560e`.

## Uitvoering
- B0-archief exact geverifieerd in vorige run; GNU-gelinkte SWAP4 executable op basis van oorspronkelijke bron.
- Tijdelijke testcase `/mnt/data/kalm431/real/hupsel_soil_kalmthout_weather`: meegeleverde Hupsel-bodem, Hupsel-drainage en cropbestanden als technisch testsubstraat, echte Kalmthout-meteorologie, locatiecoördinaten, tijdzone UTC, `SWETR=0`, `SWRAIN=3`.
- Legacy `SWIRFIX=1` bevatte geen passende irrigatie-eventdatum na verschuiving van 2002 naar 2024. Voor technische test expliciet `SWIRFIX=0`. NIET beschouwen als gekwalificeerde Kalmthout-irrigatieaanname.
- Afzonderlijke run 2024-01-01 tot 2024-01-05: `Swap simulation okay!`; proces exit 100 (`Swap normal completion!`).
- Volledige run 2024-01-01 tot 2026-10-01: `Swap simulation okay!`; proces exit 100 (`Swap normal completion!`); gerapporteerd 1.28784692 s.
- Geproduceerd `result.bal`, met jaarlijkse waterbalans op afdrukprecisie:
  - 2024: instroom 107,09 cm, uitstroom 106,95 cm, berging +0,14 cm; residu ~0.
  - 2025: instroom 60,07 cm, uitstroom 60,51 cm, berging -0,44 cm; residu ~0.
  - 2026 tot 1 okt: instroom 54,50 cm, uitstroom 53,60 cm, berging +0,90 cm; residu ~0.
  - Opgetelde regen 221,66 cm = 2216,6 mm, exact forcing totaal.
  - **Let op**: titel van derde `result.bal` blok is '2025-01-01 until 2026-10-01', hoewel jaarsommen op 2026 duiden; identificeer deze legacy-outputlabelafwijking apart. Geen claim dat het label juist is.

## Grenzen
- Dit is GEEN Kalmthout bodem- of vegetatieparametrisatie. Hupsel-soil en drainage bepalen waterbalans en verdampingsrespons. Niet wetenschappelijk vergelijken met SWAP5 voordat parameterpariteit bewezen is.
- Forcingbron Open-Meteo ERA5 (`models=era5`) uit de SWAP5 pilot, niet gemeten stationregendata. Valse claim 'waargenomen neerslag' vermijden.
- SWAP4 GNU-bronvertaling/toolchain is nog niet cross-platform wetenschappelijk gekwalificeerd. Casekopie en originele B0 blijven gescheiden.
- Geen nieuwe GitHub Action gestart; artifact hergebruikt.
