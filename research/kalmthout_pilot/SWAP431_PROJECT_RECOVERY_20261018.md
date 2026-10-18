# SYMPHONICA Kalmthout: SWAP4.3.1, automatische bronnen en eerste lokale bodemresponsen

Datum18oktober2026. Leidende gebruikerskeuze: dit project levert SWAP-resultaten op met SWAP4.3.1. SWAP5 en het performanceonderzoek zijn buiten het project geparkeerd. Er zijn voor deze voortzetting geen SWAP5-builds, solvertests of Actions gestart.

Onderzoeksbranch `research/kalmthout-local-sources-20261018`. Regionale broninventaris: remote `bb6ef25c17b3fbf92d1d3b7da6cf423b503160ce`. Eerste SWAP4-pipelinecheckpoint: `d8c31312edaff41f72f6d1bddd22004d2b70ec75`. De huidige definitieve commit bevat deze recovery, de bijgewerkte scripts en de uitvoeringsevidence. Geen wijziging van canonical door dit spoor.

## Uitgevoerd resultaat

Het ene projectcommando heeft bronnen, parametrisatie, selectie en oorspronkelijke SWAP4-uitvoering achter elkaar afgehandeld.42 verschillende scenario's voltooien1januari2024 tot en met1oktober2026:1005 dagen met dezelfde24.120-uurs ERA5-bron, volledige dagelijkse SWAP Penman-Monteith-route en werkelijke uurlijkse neerslagverdeling. Neerslagsom2216.6mm. Native code100, succesmarker en volledige dagelijkse uitvoerkalender zijn voor alle42 gecontroleerd.

De42 scenario's vertegenwoordigen21 daadwerkelijk gebruikte donorprofielen, elk met nulflux en vrije drainage als twee afzonderlijke onderrandscenario's.140 scenarioverwijzingen koppelen deze bodemresponsen aan70 van de1024 cellen. Identieke bodemprofielen, forcing en onderrand zijn eenmaal berekend. Een echte herhaling van het projectcommando heeft alle42 native resultaten via hashes gecontroleerd en hergebruikt; er zijn daarbij geen nieuwe native berekeningen uitgevoerd.

Dit zijn expliciete kale-bodemscenario's voor de dominante gekarteerde bodem. Het zijn geen volledige70-celwaterbalansen, geen heidesimulaties en geen gebiedsdekkende voorspelling. Vegetatie en gemeten onderranden zijn nog niet toegepast. De andere bodemfracties in een cel worden niet ongemerkt met dezelfde uitvoer ingevuld.

## Automatisch verzamelde gegevens

| Gegevens | Werkelijk opgehaald en vastgelegd |
| --- | ---: |
| Regionale bodemobservaties, gepagineerd en op unieke volgorde gecontroleerd |20049 |
| Oorspronkelijke XML-textuurexports, inclusief fractiegrenzen en eenheid |789, nul resterende ophaalfouten |
| Bodemlocaties uit de eerdere gebiedsuitsnede |396 |
| Bodemhorizonten/diepte-intervallen |896 |
| Bodemmonsters |873 |
| Historische profielbeschrijvingsobjecten |119 |
| Bodemclassificaties |346 |
| Ondiepe grondwaterfilters met bekende filteronderkant<=5m en peilmetadata |193 |
| Oorspronkelijke peilmetingen uit hun XML-exports |101568 |
| Daarvan binnen2024-01-01 tot en met2026-10-01 |17144 |

De voorafgaande broninventaris bevat verder2965 bodemkaartvlakken,11811 BWK/habitatobjecten en10m-landgebruik2022/2025 voor alle1024 cellen. Dat zijn echte gegevensuitsneden, geen screenshots. Zie `LOCAL_SOURCES_AND_TIMING_20261018.md` voor de primaire bronpagina's, coördinaten, dekking en bronvermelding.

De meest recente opgehaalde ondiepe peilmeting is van19mei2026. Een aantal XML-reeksen loopt verder door dan de WFS-metadata suggereren. Daarom zijn ook oudere ondiepe filters opgehaald. Volledige dekking tot1oktober2026 is daarmee nog niet aangetoond. Er is niet geëxtrapoleerd, geïnterpoleerd of automatisch een peilrandvoorwaarde van gemaakt. Peilhoogten blijven in mTAW; buisreferentiehoogte is geen celmaaiveld.

## Parametrisatie en selectie

De eerste bodemroute gebruikt uitsluitend werkelijk geanalyseerde textuurfracties, op oorspronkelijke monsterdiepten. De grenzen0-2,2-50 en50-2000 micrometer worden naar klei, silt en zand gegroepeerd. Een afrondingsverschil van maximaal0.5 procentpunt wordt expliciet met een opgeslagen factor naar100% herleid; grotere afwijkingen, overlappende fracties of een klassegrens die door een meetinterval loopt worden uitgesloten.

Een profiel moet vanaf maaiveld aaneengesloten zijn, minimaal80cm bestrijken en een bekende, eenduidige organische-koolstofwaarde per gebruikt monster hebben. De eerste minerale route sluit C>12% uit als conservatieve toepassingsscreening; dat is geen algemene veendefinitie. Ontbrekende horizonten worden niet aangevuld. De kolom eindigt op de waargenomen profieldiepte, maximaal200cm.

Rosetta3, pakket `rosetta-soil==0.3.2`, schat theta_r, theta_s, alpha, n en Ksat uit zand/silt/klei. Het is model2, zonder verzonnen bulkdichtheid of vochtmetingen. Alpha is per cm en Ksat in cm/d. Geometrische schattingen en de ruwe spreidingsuitvoer worden bewaard. De bodemscenario's gebruiken de standaard Mualem-exponent0.5 en dezelfde voorspelde Ksat voor beide SWAP-geleidbaarheidsvelden. De afzonderlijk door Rosetta voorspelde K0 en L worden als ruwe modeluitvoer bewaard, maar niet ongemerkt als een gelijkwaardig SWAP-contract toegepast.

Van de complete profielen zijn kunstmatige grondcodes voor overdracht uitgesloten. Bij12 profielen wijkt de directe Belgische classificatie af van de bodemkaartcode op het meetpunt. Die12 worden evenmin als donor gebruikt.40 profielen blijven onder deze eerste screening over. Het doel is deze bronconflicten zichtbaar te houden, niet hun oorzaak door een willekeurige codevertaling te verbergen.

Een cel krijgt alleen een bodemresponsverwijzing bij exact dezelfde dominante bodemkaartcode en een donorafstand<=5km. Die5km is een expliciete eerste projectselectie, geen bewezen universele representativiteitsafstand. Het gekozen profiel, monsterexports, hashes, afstand, oorspronkelijke percentages en alle uiteindelijke SWAP-parameters staan in ieder `case_manifest.json`.

Overige scenarioaannamen blijven zichtbaar: kale bodem, geen wortelopname/interceptie, uniforme initiële h=-75cm, geen lokale initialisatie, geen drainage/irrigatie/sneeuw/vorst/warmte/solute, gedeelde bestaande ERA5-forcing van de representatieve locatie en de historische SWAP4-numerieke instellingen. BDENS1500 is ongebruikte vereiste invoermetadata met warmte/solute uitgeschakeld, geen gemeten bulkdichtheid. ERA5 is reanalyse, geen stationsmeting. Deze invoer is geen lokaal gekalibreerde parameterverzameling.

Rosetta-implementatie en methodereferenties: https://github.com/usda-ars-ussl/rosetta-soil . De bron noemt onder meer Zhang & Schaap2017, DOI10.1016/j.jhydrol.2017.01.004. Gebruik van de PTF maakt geschatte hydrauliek niet tot een lokale hydraulische meting.

## Waterbalans en uitvoeringskosten

Alle scenario's behouden de oorspronkelijke SWAP4-acceptatiecriteria. De grootste native dagbalansafwijking is0.00094cm, oftewel0.0094mm. De grootste volledige-periodesluitfout uit de afgeronde dagelijkse componenten is ongeveer0.1065mm. De CSV-controle houdt rekening met aantoonbare afdrukafronding; zij wijzigt geen solvercriterium. De afzonderlijke fluxen en bergingsveranderingen staan in `local_sources/scenario_water_balances.csv`, de volledige dagreeksen in het evidence-archief.

In42.252 geaccepteerde dagtoestanden ligt de matrixberging binnen de grenzen uit de gebruikte theta_r/theta_s en is de plas niet negatief. Grootste plas1.42662cm. De peilexports bevatten geen niet-eindige getallen; hun waardenbereik is-1.22 tot26.70mTAW. Dit vervangt geen kwaliteitsbeoordeling van individuele meetreeksen. Zie `local_sources/physical_output_audit.json`.

Voorbeeld KAL_0196, lokaal donorprofiel op circa818m, kolom150cm:

| Volledige periode, mm | Nulflux onderrand | Vrije drainage |
| --- | ---: | ---: |
| Neerslag |2216.6|2216.6|
| Bodemverdamping |1938.287|1465.908|
| Plasverdamping |45.301|0|
| Runoff |167.690|0|
| Netto onderrandflux, positief naar de kolom |0|-810.030|
| Bergingsverandering |65.327|-59.339|

Dit voorbeeld laat de gevoeligheid voor de onderrand zien. De vrije-drainageflux is een scenario-uitkomst, geen lokaal gevalideerde grondwateraanvulling.

De oorspronkelijke volledige technische SWAP4-referentie kostte1.14s. De nieuwe lokale scenario's verschillen in profiel, compartimenten en dagelijkse uitvoer; hun afzonderlijke gemeten wandtijden liggen tussen circa1.44 en33.55s, gezamenlijk circa259.85s voor de42 verschillende uitvoeringen. Deze waarden zijn geen geïsoleerde, overdraagbare performancekwalificatie. Een hervatting hergebruikt de42 geverifieerde postimages.

## Wat nog openstaat

De1024 cellen zijn nu uitputtend geclassificeerd naar status:70 hebben een dominante-bodemrespons,490 missen een compleet passend donorprofiel binnen5km,319 vallen onder een aparte oppervlakte-/vegetatieroute en145 missen bodem- of landgebruiksdekking van de gebruikte Vlaamse bronnen. De laatste groep vereist onder meer de Nederlandse gegevensroute.

Voor alle vier geselecteerde heidekandidaten ontbreken onder de huidige strikte regel donors: KAL_0416/Zegb, KAL_0480/Zeg, KAL_0876/Zegb en KAL_0910/Sggz(v). Zij hebben dus nog geen verantwoorde lokale SWAP-invoer uit deze route. Er zijn geen homogene testparameters ingevuld om toch een resultaat te kunnen tonen.

De volgende inhoudelijke stap is een onderbouwde aanvullende bodemafleiding voor die heide-eenheden en overige donorhiaten, gevolgd door lokale vegetatie, seizoenverloop, beworteling/interceptie en locatieonderranden. Een kaartklasse levert geen LAI of worteldichtheidsprofiel. Oude bewortelingsobservaties mogen niet automatisch gelden voor de vegetatie van2024-2026. Mengcellen vereisen afzonderlijke bodem/vegetatie-eenheden en oppervlaktegewogen fluxen/berging. Deze beslissingen blijven aan de bronnen gebonden en worden niet door de automatisering verzonnen.

## Eén commando en herstart

Installeer de Python-dependencies uit `swap431/requirements.txt`. Gebruik de al herstelde oorspronkelijke GNU SWAP4.3.1-build, of bouw die met de bestaande `swap431/build_gnu.py` en de originele B0-distributie. B0-distributie SHA256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`. Bronarchief: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`. De nieuwe automatisering wijzigt deze baseline niet.

```sh
python3 research/kalmthout_pilot/swap431/run_symphonica.py \
  RUNROOT /absolute/path/swap_gnu \
  /absolute/path/weather.csv \
  /absolute/path/era5_endpoint_20261002.json \
  /absolute/path/grid_500m.csv
```

Het commando verzamelt ontbrekende regionale bronnen, maakt bronfracties en kandidaatcellen, haalt de bodemobservaties met volledige paginering op, bewaart textuur- en peilexports, bouwt de expliciete bodemscenario's, voert SWAP4 uit en controleert de volledige dagkalender/waterbalans. Gevalideerde bronbestanden en identieke native resultaten worden uit de cache hergebruikt. Geen planningstaak of externe berichten, geen SWAP5-vereiste.

Voor exacte reconstructie: pak eerst `evidence/KALMTHOUT_LOCAL_SOURCES_20261018.tar.xz` uit, daarna `evidence/SYMPHONICA_SWAP431_PROJECT_20261018.tar.xz`, beide in dezelfde RUNROOT. Het tweede archief voegt de oorspronkelijke forcing, extra bodem- en peilgegevens, scenario-invoer en resultaten toe. Weatherbestanden worden per scenario bij hervatten uit de gedeelde forcing gereconstrueerd. `local_sources/project_evidence_manifest.json` bevat de individuele hashes; `local_sources/swap431_project_summary.json` bevat de archiefidentiteit en exacte tellingen.

De native modelroute, volledige bronpaginering,789 textuureenheden,1024-celboekhouding,42 verschillende scenariopostimages,140 cel/scenarioverwijzingen en hervatting zijn echt uitgevoerd/gecontroleerd. De scripts zijn op Python-syntax gecontroleerd. Incidentele TTUTIL-type-, solute-template-, uitvoerdiepte- en cacheproblemen zijn hersteld; vroege negatieve evidence is bewaard. Dit is uitvoerings- en bronkwalificatie binnen de genoemde scope, geen lokale wetenschappelijke validatie of canonical-admission.
