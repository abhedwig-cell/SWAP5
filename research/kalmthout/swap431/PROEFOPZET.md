# Kalmthoutse Heide: onafhankelijk SWAP 4.3.1-referentiespoor

Status: proefopzet vastgelegd; nog geen gecompileerde of uitgevoerde historische run.
Datum: 2026-10-18
Werkspoor: research/kalmthout-swap431-independent-20261018
Doel: een zelfstandige, reproduceerbare SWAP 4.3.1-run realiseren naast de risicovollere SWAP5-run.

## Wetenschappelijke en technische uitgangspunten

1. Gebruik de **ongewijzigde B0 SWAP 4.3.1-distributie** als primaire historische referentie. De repository legt vast: `SWAP_4.3.1.zip` SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`; geneste `tools/SWAP/source/SWAP.ZIP` SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`. Zie `docs/legacy/swap-4.3.1-baseline.md`.
2. Houd B0 en eventuele B1-correcties gescheiden: corrigeer een eventuele historische fout niet stilzwijgend in deze baseline; documenteer een afwijkende B1-run afzonderlijk.
3. Koppel SWAP4.3.1 niet aan SWAP5-kernelmodules, solver-API's of in ontwikkeling zijnde processen. Geen wijzigingen aan canonical vanuit deze proef.
4. Hergebruik waar mogelijk exact dezelfde externe data en scenario-aannames als het Kalmthout-SWAP5-spoor. Registreer verschillen waar de oude invoerstructuur omzetting vereist.
5. Doelperiode: 2024-01-01 00:00 tot en met 2026-10-01, met expliciet vastgelegde eindtijd en outputaggregatie. Voor vergelijkingsanalyses moet de interpretatie van 'tot en met 1 oktober' expliciet zijn.

## Eerste experiment: een kolom

- Geometrie: de Kalmthoutse Heide-testlocatie binnen de eerder aangeleverde `Kalmthoutseheide_extent(1).gpkg` en `Kalmthoutseheide_minimal_extent(1).gpkg`; exacte kolomcoördinaten/representativiteit nog te verifiëren.
- Meteorologie: werkelijke uurlijkse neerslag, straling, temperatuur, luchtvochtigheid en windsnelheid, met volledige Penman-Monteith-verdampingsroute conform de **historische SWAP4.3.1-implementatie**; eventuele externe afgeleide variabelen en terugvaloplossingen afzonderlijk markeren.
- Bodem, initiële toestand, vegetatie en onderrand: hergebruik van het gedefinieerde Kalmthout-scenario, maar pas geen waarden aan om een geslaagde run te forceren. Ontbrekende parameters zijn een aantoonbare invoerblokkade en worden expliciet gerapporteerd.
- Bewaar invoerbestanden, exacte code-identiteit, compileervlaggen, platform, runtime-log, eventuele waarschuwingen en dagelijkse balansreeksen.

## Uitvoeringsfasen met harde bewijscriteria

A. **Herstel van bron en executable**: vind B0-bron in lokale of repository-distributie, verifieer beide hashes, bouw de originele executable met beschikbare toolchain, draai een meegeleverd voorbeeld zonder modelwijziging. Resultaat: compileerlog en voorbeeld-output, anders expliciete blokkade.

B. **Forcingadapter, los van de fysica**: leg herkomst, tijdzone, ontbrekende uren, neerslagduur, eenheden, stralingsconventie en uurlijkse/dagelijkse aggregatie vast. Controleer voor de gehele periode dekking, tijdsvolgorde en geen dubbele uren. Gebruik dezelfde brondata als SWAP5, alleen verschillende formaatadapters.

C. **Kalmthout-case**: leg bodemopbouw, hydraulische functies, initiële vocht/drukprofielen, vegetatie, oppervlaktegrens en onderrand in legacy-SWAP-invoer vast. Bewijs parameterpariteit met SWAP5 waar inhoudelijk haalbaar; noteer onvermijdelijke verschillen.

D. **Gefaseerde uitvoer**: eerst 1 dag, daarna 30 dagen, een kalenderjaar en ten slotte volledige periode. Beoordeel bij iedere fase solver-convergentie, tijdstappen, waterbalans, neerslag, interceptie, verdamping, transpiratie, runoff, drainage en onderrandflux. Kies geen afwijkende vereenvoudigde atmosferische vraag om falen te verbergen.

E. **Vergelijking**: vergelijk pas met SWAP5 nadat de 4.3.1-run zelfstandig gekwalificeerd is. Harmoniseer tekenconventies, integratiegrenzen, tijdstempels en waterbalansdomein. Vergelijk forcing-dekking, dagbalansen, cumulatieve fluxen en toestandsvariabelen. Leg scenario- en codeverschillen vast voordat uitkomsten aan numeriek gedrag worden toegeschreven.

## Minimale rapportage

Eén manifest per run:
- `model_id`, `source_sha256`, `executable_sha256`, `compiler`, `compile_flags`, `git_ref`
- `case_id`, `start_datetime`, `end_datetime`, `timezone`
- `forcing_file_sha256`, `forcing_coverage`, `parameter_file_sha256`
- `status`, `exit_code`, `elapsed_seconds`, `solver_warnings`
- `precipitation_total_mm`, `evapotranspiration_total_mm`, `runoff_total_mm`, `bottom_flux_total_mm`, `storage_change_mm`, `water_balance_residual_mm`

Noem een run pas geslaagd als er echt een executable is uitgevoerd, de volledige periode is afgedekt, de uitvoer fysisch plausibel is en de waterbalans binnen een vooraf vastgestelde, gedocumenteerde tolerantie sluit. Een uitgewerkt plan of een beschikbare inputset telt niet als run.

## Eerste herstelacties

1. Zoek de reeds aanwezige B0-distributie en legacy-voorbeelden; download de historische distributie niet opnieuw wanneer dezelfde hash lokaal beschikbaar is.
2. Zoek het bestaande Kalmthout-forcingmanifest en de concrete uurlijkse meteorologische bestanden; maak geen tweede onafhankelijke forcingproductie.
3. Leg exact vast welke van de geüploade geopackages de kolomlocatie bepaalt; die geometrie is niet uit de bestandsnaam af te leiden.
4. Maak een apart reproduceerbaar runscript dat uitsluitend SWAP4.3.1 start; laat SWAP5-branches en canonical ongemoeid.
5. Voer de fasen A t/m E uit, documenteer per fase werkelijk bewijs.

## Recovery

Work unit: KALM-S431-01
Baseline: integration/f-ci-canonical, vastgelegde B0-archivehashes
Implemented: onafhankelijke proefopzet
Persisted: via deze werkbranch
Tested: nee
Qualified: nee
Next action: bronarchief en Kalmthout-data verifiëren, originele SWAP4.3.1 bouwen en voorbeeldcase draaien
Dependency surface: legacy B0-bron, Kalmthout-forcing, geometrie, bodem/crop/boundary-scenario
Canonical admission: niet van toepassing; onafhankelijk research-spoor
