# Kalmthout: lokale bronnen, celuitrol en gemeten rekentijd

Datum: 18 oktober 2026. Voortzetting van de technische vergelijking, geen afronding van de locatiesimulatie. De bestaande kale-bodemruns blijven numerieke referenties. Deze werkstap wijzigt geen productie-solvercontract en integreert niets in canonical.

Herstelbranch: `research/kalmthout-local-sources-20261018`, voortbouwend op de remote technische vergelijking `3ca98e1499940b4f2a3b3077018f28498158912d`. De eerdere reparatiebranch en concept-PR1312 blijven een afzonderlijk herstelpunt.

## Gemeten volledige native runs

De bestaande GNU13.3.0/O2-executables zijn opnieuw uitgevoerd met dezelfde kalendercorrecte ERA5-invoer, 24.120 uren en volledige PM-vraag. Compilatie is uitgesloten. Eén waarneming per variant, op dezelfde gedeelde x86_64-omgeving met Intel Xeon Platinum 8573C. Geen geïsoleerde performancekwalificatie; de 3cm-meting overlapt gedeeltelijk met GIS-verwerking. De JSON-bestanden leggen ook CPU-tijd, commando en executablehash vast.

| Variant | Wandtijd s | Gebruiker-CPU s | Resultaat |
| --- | ---: | ---: | --- |
| Onafhankelijke SWAP4.3.1, 200cm/34 compartimenten | 1.1393 | 1.1308 | Gehele periode, native code100 en succesmarker |
| SWAP5, oorspronkelijke 3cm-testkolom, budget40/32 | 98.9508 | 95.0254 | Gehele periode, massavalidator geslaagd |
| SWAP5, consistente 200cm/34 compartimenten, continue K-onderzoekskandidaat | 145.3887 | 144.9205 | Gehele periode, massavalidator geslaagd; uitvoer identiek aan eerdere aligned200_full.csv |

SWAP5/SWAP4 is hier circa127.6 voor de 200cm-proef. Het verschil omvat verschillende tijdintegratoren, acceptatiecriteria, transactionele uitvoering en I/O, niet alleen de lineaire/Newton-solver. De continue K-variant is bovendien niet hydraulisch identiek aan de historische referentie. Geen algemene snelheidsclaim uit deze verhouding afleiden. De 3cm-kolom heeft geen fysische betekenis als gebiedsprofiel.

Voor de 200cm-proef blijven210.982 geaccepteerde deelstappen en771.432 temporele afwijzingen nodig. Dit is de eerste concrete performancevraag vóór brede productie-uitrol. Bij identieke rekentarieven kost1024 maal deze proef circa41.4 uur serieel. Dat is een eenvoudige vermenigvuldiging, geen uitgevoerde multi-celbenchmark, parallelle schaaltest of prognose voor andere lokale profielen. Volledige O0-rekentijden zijn niet gemeten; compilatiekosten zijn UNKNOWN.

## Eerdere inventarisatie en actuele geometrie

Een eerdere projectinventarisatie noemde DOV-bodemkaart/profielen, grondwatermeetnetten, landbouwgebruikspercelen en CLCplus. Die namen zijn geen bewijs van eerder afgeleide lokale parameters. De huidige repository bevat nog de homogene experimentele bodem en kale bodem.

De actuele bron is `domain.json` met de ontvangen extent: EPSG:32631, x592980..608980, y5683020..5699020, 32x32 cellen van500m, totaal1024. De oudere voorlopige576-cellenopzet wordt niet hergebruikt. `export/grid_500m.csv` uit de bestaande Actions-evidence is opnieuw gebruikt.

## Daadwerkelijk opgehaalde gebiedsgegevens

Alle datasets zijn op18oktober2026 via openbare diensten benaderd; exacte ruwe postimages en hashes worden bij de evidence bewaard. Geen kaartafbeeldingen als categorie-invoer gebruikt.

| Bron | Opgehaald | Betekenis en begrenzing |
| --- | --- | --- |
| DOV `bodemkaart:bodemtypes` |2965 kaartvlakken | Bodemtype, textuur-, drainage- en profielcodes, substraten en verwijzingen naar toelichtingen. Kartering grotendeels1950-1970, schaal1:20.000. Geen directe gemeten theta(h)/K(h)-curve. |
| DOV `bodem:bodemlocaties` |396 locaties | Inventaris van boringen/profielputten met links naar bodemopbouw en observaties. Nog geen396 bruikbare hydraulische profielen. |
| DOV `bodem:infiltratiemetingen` |0 objecten in de extent | De specifieke dienst levert hier geen Ksat-locaties. Dit bewijst geen afwezigheid van alle metingen bij andere bronnen. |
| DOV grondwaterlocaties met metingen |557 filterobjecten |518 hebben peilmetingmetadata;193 hebben bekende filteronderkant<=5m.411 objecten behoren tot meetnet9, INBO/natuurorganisaties. Tijdreeksen nog niet opgehaald of op2024-2026-dekking gekwalificeerd. |
| BWK/Natura2000, live WFS `BWK:Bwkhab` |11811 unieke objecten | Catalogus beschrijft toestand2025. Geometrie, BWK-label, habitatcodes en binnenvlakse habitatpercentages blijven behouden; inventarisatiedata verschillen per object. |
| Landgebruik Vlaanderen2022 v3 |10m GeoTIFF-uitsnede | Historische nabijgelegen kaarttoestand, geen automatische waarheid voor2024. |
| Landgebruik Vlaanderen2025 v3 |10m GeoTIFF-uitsnede en originele SLD-legenda | Werkelijk landgebruik, niet juridische bestemming. Geen complete vegetatie- of verhardingsparametrisatie. |

De WCS-uitsneden liggen in EPSG:31370, x147530..163850/y219810..236130. Hun oorspronkelijke10m-categorieën zijn gepolygoniseerd en naar32631 getransformeerd; geen bilineaire interpolatie van categoriecodes. Kleine geometrische reparaties worden expliciet geteld. Bij BWK bleek offsetpaginering zowel duplicaten als ontbrekende objecten te kunnen geven. De eindinventaris gebruikt oplopende unieke UIDN en een vervolgfilter op de laatst ontvangen UIDN. Een afgebroken/onvolledige TIFF2022 is niet toegelaten; de volledig leesbare LZW-herdownload is gebruikt.

## Celinventarisatie en eerste selectie

`inventory_cell_sources.py` berekent voor alle1024 cellen bronfracties, expliciete ontbrekende oppervlakte en overlap. Bodem en BWK zijn ook onderling doorsneden. Het BWK-label en de habitatpercentages blijven als samenhangende bronattributen staan; een mozaïekpercentage krijgt geen verzonnen subvlakgeometrie. Zie `source_overlay_audit.json`, `cell_source_coverage.csv`, `cell_source_fractions.csv` en `cell_joint_units.csv` in de evidence.

De definitieve inventaris heeft145 cellen zonder dekking van deze Vlaamse bronnen. De bodemkaart bedekt het equivalent van851.620 volledige cellen;803 cellen zijn geheel gedekt. Beide landgebruiksrasters bedekken het equivalent van852.025 cellen;821 cellen zijn geheel gedekt. BWK bedekt852.022 celequivalenten. De dekkingstolerantie voor deze telling is1e-7; kleine kaartnaden verklaren dat veel BWK-cellen formeel niet volledig zijn. Maximale BWK-overlap is2.97e-5 van een cel, ongeveer7.42m2. De geometrische reparaties betreffen13 bodem- en24 BWK-objecten. De bodem/BWK-doorsnede bevat35.407 cel/broncombinaties, geen35.407 reeds geparametriseerde modelkolommen.

Het grensoverschrijdende domein vereist ook Nederlandse bronnen; ontbrekende fracties worden nooit stilzwijgend over de Vlaamse klassen verdeeld. PDOK/BRO Bodemkaart en bijbehorende profielgegevens zijn daarvoor de gecontroleerde ingang, met afzonderlijke schaal- en profielbeperkingen.

KAL_0496 is geometrisch centraal, maar is geen representatieve heidecel. Volgens landgebruik2025 is ongeveer75.494% huizen en tuinen,9.727% overige onbebouwde terreinen,8.656% transportinfrastructuur,2.870% overige bebouwde terreinen,2.843% industrie en0.410% bos. Huizen en tuinen betekent niet75.494% verhard. De bodemkaart is ongeveer95.362% Zcgb,2.487% w-Zegb en2.151% OB. Deze kaartinformatie mag niet worden verward met de eerder gebruikte homogene zandparameters.

`summarize_cell_sources.py` selecteert de twee hoogste beschikbare bronfracties voor droge heide4030, vochtige heide4010, bos, akker, landbouwgras, huizen/tuinen en open water, met verschillende cellen en expliciete voorwaarden. De selectie blijft een kandidaatset. Open water krijgt een afzonderlijke procesroute, geen kale-bodemkolom. De bronfracties van iedere resterende cel blijven beschikbaar; dit is geen selectie van slechts één centrale kolom.

De resulterende14 kandidaten zijn vastgelegd in `local_sources/candidate_cells.json`. Voor droge heide zijn dit KAL_0416 en KAL_0480 (bekende habitatfractie51.54% en47.00%); voor vochtige heide KAL_0876 en KAL_0910 (70.89% en70.13%). Bij negen passende habitat/celregels ontbreekt een percentage; die onbekende fracties zijn niet ingevuld en tellen niet mee in deze rangschikking. De selectie bewijst dus nog geen volledige representativiteit. Landgebruik2022 classificeert71.59% van KAL_0496 als huizen/tuinen; ook die oudere kaart maakt de centrale cel geen zuivere heidecel.

## Van kaart naar verantwoord model

De volgende implementatiefase moet per bodem/vegetatie-eenheid de laagopbouw en werkelijk beschikbare profielanalyses koppelen. Textuur, organische stof en dichtheid moeten eenheden en diepte-intervallen behouden. Pas daarna een expliciet gekozen, onderbouwde pedotransferfunctie of gemeten hydraulische relatie gebruiken, inclusief onzekerheid en toepassingsdomein. Een buitenlandse kaartcode rechtstreeks gelijkstellen aan een Staringreeks is onvoldoende.

Vegetatie vraagt seizoens-LAI, hoogte, beworteling, interceptie en weerstand; een BWK- of landgebruikcode levert die niet rechtstreeks. Een kale-bodemrun met een andere albedo is geen heidesimulatie. Landgebruik2022 en2025 eerst vergelijken; kaartverschil kan ook bron- of classificatiewijziging zijn, dus geen automatische jaarlijkse verandering construeren.

Voor de onderrand moeten ondiepe peilreeksen, maaiveldhoogte en relevante hydrogeologie samen worden beoordeeld. De technische nulflux op200cm is geen locatiegegeven en mag niet gebiedsbreed als gemeten randvoorwaarde worden gebruikt. Onttrekkingsfilters of diepe stijghoogten niet zonder beoordeling omzetten naar freatische onderrandsturing. Gebruik dezelfde gegevens niet tegelijk als opgelegde randvoorwaarde en onafhankelijke validatie.

Een cel kan meerdere bodem/vegetatiekolommen bevatten. Simuleer die afzonderlijk en aggregeer fluxen en berging naar oppervlakte; middel geen MVG-parameters of categoriecodes. Vermijd dubbel tellen van overlap en houd ontbrekende fracties zichtbaar. Begin met de brongebaseerde kandidaatcellen en verschillende natte/droge profielen; schaal daarna pas naar alle geschikte cellen. Noodzakelijke gates: parameters traceerbaar, gebiedsbalans, volledige tijddekking, transacties, lokale forcingdekking en gemeten uitvoeringskosten.

## Herhalen en status

`fetch_local_sources.py OUTPUT` legt publieke verzoeken en responsen vast. Het actuele script gebruikt voor BWK keysetpaginering vanaf de eerste pagina. `inventory_cell_sources.py GRID SOIL OUT --bwk BWK_PAGE1 BWK_PAGE2 --landuse LANDUSE2025 --landuse2022 LANDUSE2022` berekent de inventaris; daarna `summarize_cell_sources.py OUT`.

`benchmark_native.py [--cwd CASE] OUTPUT.json -- EXECUTABLE ARGUMENTS...` meet een bestaande executable. Native SWAP4 code100 alleen accepteren samen met zijn succesmarker. SWAP5-uitvoer valideren met `validate_completed_run.py`.

Geïmplementeerd en werkelijk uitgevoerd: rekentijdmetingen, bronophaling, broncontroles en celinventarisatie. Nog niet geïmplementeerd/gekwalificeerd: lokale hydraulische en vegetatieparameters, locatieonderrand, Nederlandse volledige dekking, volledige multi-celsimulatie en productie-admission van de continue K-kandidaat. Geen canonieke integratie door deze werkstap.

Het aanvullende evidence-archief `evidence/KALMTHOUT_LOCAL_SOURCES_20261018.tar.xz` bevat31 bestanden met de ruwe gebiedsuitsneden, exacte celuitvoer en benchmarkpostimages. Het is8.528.672 bytes; SHA256 `785b262bc94e723c4a53144fb4b5e4796a48835d501c8e0e01059ae726e7e748`. `local_sources/` bevat de kleine direct leesbare audits, selectie en rekentijden. Gebruik het manifest voor bestandsidentiteiten. De volledige oude forcing en modelbronidentiteiten blijven in het eerdere uitvoeringsarchief; die zijn niet opnieuw gedownload.

## Controleerbare bronpagina's

- DOV bodemkaarten: https://www.dov.vlaanderen.be/page/bodemkaarten
- DOV bodemdata/profielen/Ksat: https://www.dov.vlaanderen.be/page/bodemdata
- DOV diensten: https://www.dov.vlaanderen.be/page/dov-services
- DOV grondwatermeetnetten: https://www.dov.vlaanderen.be/page/grondwatermeetnetten
- BWK2025: https://www.vlaanderen.be/datavindplaats/catalogus/biologische-waarderingskaart-en-natura-2000-habitatkaart-toestand-2025
- Landgebruik2022: https://www.vlaanderen.be/datavindplaats/catalogus/landgebruik-vlaanderen-toestand-2022
- Landgebruik2025: https://www.vlaanderen.be/datavindplaats/catalogus/landgebruik-vlaanderen-toestand-2025
- Nederlandse BRO Bodemkaart: https://www.pdok.nl/introductie/-/article/bro-bodemkaart-sgm-

Bronvermelding: Databank Ondergrond Vlaanderen, specifieke lagen hierboven, geraadpleegd18/10/2026 op https://www.dov.vlaanderen.be; Bron: INBO voor BWK; Departement Omgeving/MercatorNet voor landgebruik. Datasetvoorwaarden blijven van toepassing.
