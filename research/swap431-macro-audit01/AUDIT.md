# SWAP431-MACRO-AUDIT01

Onafhankelijke audit, 12 november 2026. Onderzoeksbasis: canonical `f2377211d2be58d03d96e50fb0a6bc35ced3c90f`. Afzonderlijke afrondingsbranch: `research/swap431-macro-audit01-review-20261112`. Preregistratiecommit: `8ad3a40619b58e614e8c694639a3735c41329911`.

## Besluit en grens van de claim

**Optie B als gerichte experimentele vervolgroute: ontwikkel en kwalificeer uitsluitend de afsluitende gekoppelde acceptatie.** B0 blijft de onveranderde historische referentie. Er is geen nieuwe B1-patch geïmplementeerd, geen B1-snapshot toegelaten en geen wijziging van canonical of productie.

Zelfstandig B0 vertoont hetzelfde bevriezingsmechanisme als de hybride dag-438-proef. Twintig vroege, oorspronkelijk geaccepteerde Andelst-stappen zijn opnieuw geëvalueerd: zestien overschrijden dan de oorspronkelijke lokale residugrens, zeventien de totale grens. Dit is onafhankelijk herhaald met opnieuw gecompileerde oorspronkelijke en geïnstrumenteerde `headcalc`, de oorspronkelijke koude initialisatie en ongewijzigde fysica en criteria. Het verschil wordt volledig verklaard door gewijzigde matrix-macroporiënuitwisseling.

**De interpretatie moet precies blijven.** De oorspronkelijke code bevriest de uitwisseling bewust ter versnelling. Haar residu en Jacobiaan zijn dan onderling consistent voor dat bevroren deelprobleem. Het bewijs toont dat de melding van convergentie geen garantie geeft voor het opnieuw geëvalueerde gekoppelde probleem. Het bewijst geen fout in de uitwisselingswet, geen onbedoelde programmeerfout in de bevriezing en geen algemene onbetrouwbaarheid van historische B0-resultaten. Een afzonderlijk gedocumenteerd foutcriterium voor de splitsingsbenadering is in de onderzochte bronnen niet aangetoond. Ten opzichte van een volledig gekoppeld eindcriterium is de acceptatie ontoereikend; de grootte van de fysische trajectfout blijft hier onbekend. Klasse 1 geldt voor die beperkte criteriuminconsistentie, klasse 2 voor de bredere numerieke kwetsbaarheid.

De grootste gemeten lokale B0-overschrijding is ongeveer 1,39 maal de oorspronkelijke grens; de totale overschrijding ongeveer 2,25 maal. De lokale snelheidsafwijking maal `dt=0.002 d` is ongeveer `2.77e-9 cm` voor deze stap. Dit is geen bewijs van dezelfde miljoenvoudige overschrijding als in de hybride dag-438-toestand, noch van een aantoonbare drukhoogtefout van tientallen centimeters in B0.

Voor een migratiereferentie die volledige gekoppelde convergentie moet vertegenwoordigen, adviseer ik daarom eerst een kleine B1-acceptatieproef. Automatisch alleen de laatste flux verversen is geen verantwoorde reparatie: de matrix moet met dezelfde gepaarde flux opnieuw worden opgelost, of de stap moet worden afgewezen met correct herstel. Pas wanneer die proef convergentie, behoud en rollback aantoont, kan een minimale correctie als nieuwe B1 worden gekwalificeerd. Optie A is verdedigbaar voor historische reproductie, maar beantwoordt dit sterkere convergentiecontract niet. Optie C, een structurele numerieke herziening, is door deze proeven niet onderbouwd.

## Onafhankelijke afronding van het bestaande dossier

De preregistratie was reeds gepubliceerd in commit `8ad3a40619b58e614e8c694639a3735c41329911`; een volledig lokaal dossier met bronarchief, meetgegevens en conceptrapport was aanwezig. Deze afronding gebruikt dat dossier als toetsbare invoer, niet als zelfstandig gezag. Alle 63 bronleden zijn opnieuw gecontroleerd tegen het manifest uit de gepinde canonical. Alle geselecteerde bouwbronnen zijn opnieuw vergeleken met uitsluitend de gedocumenteerde DEC-platformselectie uit de ruwe archiefleden. Alle 62 hergebruikte objecten, de TTUTIL-bibliotheek en de compiler/frontend zijn op hun opgeslagen SHA-256 gecontroleerd. Controle- en observer-`headcalc` en de C-forkhelper zijn werkelijk opnieuw gecompileerd en gekoppeld met gfortran 14.2.0 op O2.

De nieuwe controle en observer voltooien beide de tweedaagse proef met code 100 en `swap.ok`. De twintig residu-/uitwisselingsvectoren reproduceren de eerdere gegevens byte voor byte. De vier vergeleken fysieke uitvoerbestanden, inclusief `result.end`, zijn bytegelijk tussen beide nieuwe uitvoeringen en gelijk aan de eerdere controle na uitsluiting van uitsluitend eventuele generatietijdregels. Dit bewijst de afwezigheid van observatie-invloed binnen deze geregistreerde uitvoer; het standaard eindbestand is geen volledige serialisatie van alle SAVE-toestand.

`VERIFICATION.json` en `VERIFICATION_BUILD.json` bewaren de nieuwe uitvoeringsidentiteiten, kosten en controle-uitkomsten. `VERIFICATION_EVIDENCE.zip` bewaart de nieuw gebruikte executables, meetvectoren en volledige korte uitvoer. De oorspronkelijke capsule en haar hash blijven afzonderlijk behouden. Setupfouten bij het opzetten van de onafhankelijke controle zijn geen modelresultaten; de afgeronde controles zijn afzonderlijk vastgelegd. Er zijn geen nieuwe hypothesen toegevoegd en geen volledige 481-daagse berekeningen uitgevoerd.

## 1. Referentie-identiteit en methode

Het geneste oorspronkelijke `SWAP.ZIP` is via de gepinde repository opgehaald. SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`. Alle 63 ruwe Fortran-bestanden zijn afzonderlijk op bytegrootte en SHA-256 gecontroleerd tegen `reference/swap-4.3.1/b0/file-manifest.sha256`. Geen ruwe B0-bron is gewijzigd.

De buitenste distributiehash `2b48353d…` is bestaande repositoryprovenance; het volledige distributiearchief is in de oorspronkelijke meetronde niet opnieuw verkregen of geverifieerd. De verificatieclaim hier betreft het exacte bronarchief en alle bronleden. `TTUTIL.ZIP` heeft SHA-256 `ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193`.

De veertien opgeslagen Andelst-projectbestanden komen byte voor byte overeen met hun Git-blobs in de gepinde tree. `swap.swp` heeft oorspronkelijk SHA-256 `c87ef0f8561f90277a2ae22f74fd12e050e4cafb26cb3b475768a737c76c059b`, gelijk aan de bestaande B0-Andelst-run. Dit is oorspronkelijke invoer, geen SWAP5-projectie.

Voor de korte proef is alleen `TEND` veranderd van `1999-04-26` naar `1998-01-02`. De koude oorspronkelijke initialisatie, neerslag, bodem, macroporiëninstellingen en numerieke criteria blijven gelijk. Er is geen aantoonbaar compleet zelfstandig B0-checkpoint voor dag 438 gereconstrueerd; de bestaande S5MAC006-checkpoints horen bij de hybride onderzoeksuitvoering en zijn daarvoor niet gebruikt.

Compiler: GNU Fortran 14.2.0, Debian 14.2.0-19, Linux x86_64. SWAP-vlaggen: `-O2 -cpp -Dlinux -finit-local-zero -ffree-line-length-none -fallow-argument-mismatch`. TTUTIL: `-O2 -finit-local-zero` met toepasselijke vrije/vaste regellengte. De bestaande `b0_source_runner.py` selecteert in afzonderlijke bouwkopieën de oorspronkelijke Intel DEC-platformtakken: Linux aan, MultiSWAP/SSS/ANIMO uit. Er is geen fysische bronpatch toegepast. Een expliciete systeem-GCC-linkerzoekweg was nodig voor de lokaal uitgepakte compiler. Dit is een GNU-bronuitvoering, geen bewijs van gelijkheid met de meegeleverde Intel-binary.

Controle-executable SHA-256: `8e3e27d91fa0cc4e7972169e7706214272f02079b3011213fddadde3625ec35c`. Observer-executable: `bf2772433b2d4bc91e165a8857a811651183e5be026f522c9239c935154f6263`. Alle bron-, object-, compiler- en inputidentiteiten staan in `BUILD_IDENTITY.json` en `CASE_IDENTITY.json` in de bewijscapsule.

## 2. Werkelijke oorspronkelijke berekening

Bronlocaties hieronder zijn regelnummers van de ruwe bronleden in het geverifieerde archief, niet van gegenereerde SWAP5-bestanden.

| Routine en locatie | Numerieke en fysische taak |
| --- | --- |
| `macropore.f90:115`, `MACROPORE(1)` | Controle, `MACROGEOM`, `MACROINIT`, initiële `MACROSTATE`, opslag en uitvoertellers. |
| `MACROGEOM:219`, `DEFINECOMPART:522`, `MACROINIT:698` | Domein- en compartimentgeometrie, MB/IC-verdeling, initiële voorraad, krimp- en sorptieparameters. |
| `MPVOLUME:1690` | Taak 1 werkt dynamische volumes tijdens iteraties bij vanuit matrix-theta; taak 2 werkt geaccepteerde geometrie verder bij. |
| `soilwater.f90:143` | Slaat aan het begin van de poging matrix- en geselecteerde macrotoestand op en roept `HEADCALC` aan. |
| `headcalc.f90:78 tot 420` | Richards-residu, tridiagonale Newtonstap, backtracking, hoofd- en balanscriteria, macrobevriezing, acceptatie. |
| `BOUNDTOP(2)`, `boundtop.f90:153 tot 172` | Matrixinfiltratie/ponding en potentiële laterale maaiveldinstroom `QMpLatSs`. Deze variabele is hier een staphoeveelheid; elders zijn veel Q-variabelen snelheden. |
| `MACROPORE(2/3):181 tot 190`, `macrorate.f90:4` | Taak 2 berekent werkelijke macrofluxen; taak 3 roept dezelfde rateberekening plus afgeleiden aan. |
| `MACRORATE:83 tot 145` | Actualiseert grondwaterprojectie (`CALCGWL`), verzadigde/perched classificatie, macrovolume en reductieniveau. |
| `SATFLOW:1453`, `ABSORPTION:1631`, `RAPIDDRAIN:1847` | Verzadigde uitwisseling, onverzadigde sorptie/Darcy-uitwisseling en snelle drainage. Domeinvoorraad en beschikbare berging begrenzen de potentiële hoeveelheden. |
| `swap.f90:433 tot 460` | Herhaalt bij mislukking met kleiner dt of gereduceerde macro-uitwisseling, met `SoilWaterStateVar(2)` en `MacroStateVar(2)`; pas daarna volgt `SoilWater(3)`. |
| `soilwater.f90:162 tot 189` | Actualiseert na acceptatie hydraulische grootheden, `CALCGWL`, matrixvoorraad, `FLUXES` en `MACROPORE(4)`. |
| `MACROSTATE:1298`, `MACROINTEGRAL:1169` | Integreert macrovoorraden, geometrie, natte wanden, sorptieklok en cumulatieve fluxen na acceptatie. |

De verbinding met Richards is concreet:

`F_i = Δtheta_i * FrArMtrx_i * dz_i / dt + drainage_i - bronnen_i + wortelopname_i + verticale_fluxdivergentie_i - QExcMpMtx_i`.

De getoetste Andelst-invoer gebruikt `SWMBF=1` (instantaneous bypass), `SWKIMPL=0`, `DTMIN=1e-5 d`, `CritDevBalCp=1e-6` en `CritDevBalTot=1e-5`. De proef kwalificeert niet alle andere macroporiënmodi. Bij `SWKIMPL=0`, zoals in deze oorspronkelijke Andelst-invoer, blijven de geleidbaarheden en externe sinktermen binnen de stap in hun oorspronkelijke semigeïmpliciete betekenis. De verse evaluatie houdt die betekenis vast: zij herberekent het oorspronkelijke `vector_F(1,hgrad)` en introduceert geen volledig impliciete SWAP5-vergelijking.

### Residu, Jacobiaan en acceptatie

`headcalc.f90:351 tot 370` zet na drie voldoende gunstige voortgangsbeoordelingen `flunsatok(3)` op waar, voor `dt<0.01 d`. Dat criterium vereist niet dat de volledige gekoppelde oplossing al voldoet. Vervolgens slaat `vector_F(2)` bij `521 tot 525` de macro-rateberekening over en herstelt het de bewaarde maaiveldhoeveelheid. `QExcMpMtx` blijft bevroren. De Jacobiaan slaat bij `686 tot 688` ook de macroafgeleide over.

Dat is consistent met een **bevroren** deelprobleem: de afgeleide van de bevroren uitwisseling is nul. Het is dus onjuist dit zonder meer als een analytische Jacobiaanfout aan te merken. Voor actieve macro-updates berekent `MACROPORE(3)` de lokale macrodiagonaal en trekt die van de Richards-diagonaal af. De bestaande hybride richtingsproef ondersteunt de geselecteerde afgeleiden op haar eigen toestand; deze audit promoveert die niet tot een volledige B0-Jacobiaankwalificatie.

De ontbrekende schakel staat bij `headcalc.f90:373 tot 378`: lokale, totale en hoofdcriteria worden op het gecachete residu beoordeeld; bij succes volgt geen verse gekoppelde eindcontrole. De nieuwe B0-proef laat zien dat deze eindcontrole daadwerkelijk een andere beslissing zou geven. De bedoelde bevriezing is dus geen toevallige schrijf- of tekenfout, maar het acceptatiecontract geeft geen bewijs van convergentie van de opnieuw geëvalueerde koppeling.

Bij minimumdt kan de oorspronkelijke code bovendien `IDecMpRat` verhogen (`442 tot 449`) en uiteindelijk na waarschuwing zonder convergentie doorgaan (`452 tot 463`). Dat is een aparte expliciete numerieke noodroute. De twintig waargenomen stappen kwamen uit de gewone convergentietak, met reductieniveau nul; die noodroute verklaart de bevinding niet.

### Toestand, SAVE en rollback

De kern gebruikt moduletoestand in `variables`, `MOD_swap_mp` en `MOD_macropore`, plus veel lokale `SAVE`-variabelen. In de onderzochte kernbestanden is geen uitvoerbare COMMON-declaratie gevonden; dat is geen uitspraak over alle TTUTIL- of externe code.

`MACRORATE` heeft omvangrijke opgeslagen werkarrays en verandert tijdens evaluaties ook grondwaterclassificatie, volume, candidatevoorraden en eventvelden. `ABSORPTION:1711 tot 1724,1802 tot 1805` kan sorptiereferenties en eindflags tijdens een iteratie veranderen. De sorptieklok zelf wordt pas in `MACROSTATE:1423 tot 1449` geïntegreerd. `MacroStateVar:1672 tot 1681` bewaart/herstelt slechts domeinbodems, volumes en onverzadigde compartimentvoorraden. Daarmee is volledige rollback van al het procesgeheugen nog niet bewezen.

Een tweede aandachtspunt is `MACROINTEGRAL:1189`: een lokale `FrMpWalWetOld` overschaduwt de gelijknamige modulevariabele. De lokale waarde wordt bij `1209 tot 1210,1241 tot 1242` tussen aanroepen als vorig kwadratuureindpunt gebruikt, maar heeft geen expliciete SAVE of initialisatie. De gekozen compileropslag en nulinitialisatie kunnen dit gedrag beïnvloeden. Dit is een concrete bronkwetsbaarheid voor reproduceerbaarheid en herstart; de audit heeft het gevolg niet onafhankelijk met een apart compilatie-experiment gekwantificeerd en noemt het geen nieuw gekwalificeerde correctie.

## 3. Gerichte echte B0-proeven

H1 was vooraf geregistreerd: kunnen de eerste twintig geaccepteerde stappen met actieve macrobevriezing na een verse evaluatie hun oorspronkelijke criteria overschrijden? H2: verandert herhaald evalueren, of een verzadigingsexcursie bij knoop 81 en herstel van dezelfde hydraulische invoer, het opnieuw berekende residu of de waargenomen macrovelden?

De observer draait uitsluitend in een Linux-fork van de complete levende Fortran-toestand, vóór de oorspronkelijke acceptatieafhandeling. De ouder wacht; alleen het kind roept de oorspronkelijke `vector_F` aan en verlaat daarna met `_exit`. Een kindlimiet van drie seconden voorkomt vastlopen. Er worden hoogstens twintig geaccepteerde bevroren stappen waargenomen. Geen kindtoestand keert terug naar de fysieke ouderberekening.

| Grootheid, slechtste lokale steekproef | Werkelijk gemeten |
| --- | ---: |
| Oorspronkelijke stapstart `t1900` | 35795.010121320345 |
| dt | 0.002 dag |
| Iteraties / knopen / reductieniveau | 4 / 112 / 0 |
| Gecachet maximaal residu | 7.213432838719456e-12 |
| Vers maximaal residu | 1.387360372412513e-6 |
| Oorspronkelijke lokale grens | 1e-6 |
| Gecachet totaal residu | -1.8359451598042713e-10 |
| Vers totaal residu | 2.2460010243790122e-5 |
| Oorspronkelijke totale grens | 1e-5 |
| Maximale verandering macro-uitwisseling | 1.387365270933338e-6 |
| Maximaal restant `(Fnieuw-Foud)+(Qnieuw-Qoud)` | exact 0 in opgeslagen double precision |

De residuen zijn de oorspronkelijke snelheidsbalansen, niet dagelijkse balanshoeveelheden. In de twintig opeenvolgende geselecteerde stappen falen zestien verse lokale criteria en zeventien verse totale criteria. De eerste drie controles hebben exact gelijke verse en gecachete vectoren. De vierde overschrijdt alleen het totale criterium; vanaf de vijfde falen beide. Het is een selectieve vroege steekproef van bevroren stappen, geen frequentieschatting voor alle stappen of voor 481 dagen.

H1 is bevestigd in B0. De mate van overschrijding is hier veel kleiner dan de hybride dag-438-waarde 4.3198. Bevestiging van hetzelfde mechanisme bewijst niet dat B0 op dag 438 dezelfde toestand, residugrootte of grondwaterfout heeft.

H2 vindt op deze twintig toestanden geen afwijking: twee opeenvolgende verse evaluaties geven exact dezelfde residu- en uitwisselingsvector; de knoop-81-excursie en herstel keren exact terug. De geregistreerde eventflags, natte wanden en onverzadigde macrovoorraden veranderen na terugkeer niet. Dit spreekt tegen een noodzakelijke evaluatiegeschiedenisfout op deze toestanden. Het is geen algemene rollbackproef na een werkelijk afgewezen tijdstap en controleert niet elk intern SAVE-veld.

De oorspronkelijke en geïnstrumenteerde tweedaagse berekening voltooien normaal met code 100 en `swap.ok`, in respectievelijk 0.442 en 0.585 s. Een aanvullende observatiecontrole zet uitsluitend `SWEND=1` en vraagt bestaande water- en macrobalansvelden op. Beide uitvoeringen voltooien in 0.417 en 0.593 s. Alle vier bleven ruim onder hun limiet van twintig seconden. De som van de modelwandtijden is circa 2.04 s; compilatie zit daar niet in.

Controle en observer leveren byte-identieke dagelijkse CSV, macrogeometrie en krimpkarakteristiek. De uitgebreide uitvoeringen leveren ook een byte-identiek volledig standaard `result.end`, inclusief 112 drukhoogten. Zelfs de headers zijn gelijk; de beoordelaar staat alleen een generatie-tijdstempelverschil toe, maar die uitzondering was niet nodig. De uitgebreide uitvoer behoudt alle oorspronkelijke RAIN/DRN/GWL-records exact, en de twintig observatierecords zijn tussen beide uitvoerprofielen byte-identiek. Dit onderbouwt niet-inmenging voor de waargenomen fysische uitvoer; het standaard eindbestand bevat niet alle verborgen SAVE-toestand.

## 4. Waterbehoud en overgangssituaties

`MACRORATE:1410 tot 1435` vormt de domeinuitwisseling en sommeert dezelfde fluxen tot `QExcMpMtx`. Die wordt in het matrixresidu afgetrokken (`headcalc:628`), terwijl `MACROSTATE:1325 tot 1326` de domeinvoorraad met dezelfde uitwisseling vermindert en de snelle drainage afzonderlijk afboekt. De tekenconventie is daarmee intern gepaard. `FLUXES:41` gebruikt eveneens `QExcMpMtx`. Maaiveldinstroom wordt in `BOUNDTOP`, `MACRORATE` en `PONDRUNOFF` als gekoppelde hoeveelheid behandeld.

De uitgebreide B0-uitvoer geeft dagelijkse totale BALDEV van `-5.96535e-7 cm` en `-4.62874e-8 cm`; beide macro-domeinbalansen drukken als nul af. Dit zijn geprinte gegevens met eindige precisie, geen nieuw bewijs van exact nul op procesniveau. Ze tonen wel concreet dat kleine dagelijkse balansafwijkingen kunnen samengaan met een vers residu dat de oorspronkelijke stapcriteria overschrijdt. Behoud met bevroren fluxen is mogelijk zonder convergentie van de actuele hydraulische koppeling.

| Overgang | Bronbevinding en beoordeling |
| --- | --- |
| Verzadiging en perched verbinding | `CALCGWL` en `SATFLOW` schakelen compartiment- en connectiviteitsclassificatie. Scherpe fysische/procesgrenzen kunnen een gladde Newtonstap bemoeilijken; geen afzonderlijke bewezen oorspronkelijke connectiviteitsfout. |
| Eerste macro-instroom en infiltratiecapaciteit | `BOUNDTOP:153 tot 172` en `MACRORATE:161 tot 175` gebruiken drempels en max/min-begrenzing. De bevriezing kan de gewijzigde uitwisseling buiten het opgeloste deelprobleem houden; dat mechanisme is bewezen, alle overgangsgevallen zijn niet afzonderlijk doorgerekend. |
| Bijna lege domeinen en kleine hoeveelheden | `MACRORATE:126 tot 133,1325 tot 1330,1400 tot 1402` bevat voorraad-/fluxdrempels en nulzetting; `MACROSTATE:1327,1348` begrenst voorraad op nul. Mogelijke niet-conservatieve kleine correcties moeten apart worden gemeten; geen omvangrijke waterbron aangetoond. |
| Krimp en zwelling | `MPVOLUME` verandert beschikbare berging tijdens iteratie en na acceptatie; de samenhang met voorraadbegrenzing maakt de operator stuksgewijs. Geen bewijs dat een volledige nieuwe procesformulering nodig is. |
| Afwijzing | De expliciete herstelroute bestaat, maar herstelt zichtbaar een beperkte set macrovelden. Ontbrekende recomputatie of rollback blijft een gerichte open vraag. |
| Sterke neerslag | De korte proef bevat op dag twee 1.20740 cm regen. De residuobservaties zijn beperkt tot de eerste twintig vroege stappen op dag één; hieruit volgt geen stresskwalificatie van dag twee. |

Newton met backtracking en kleinere tijdstappen kan voor gladde delen geschikt zijn. De huidige proef rechtvaardigt vooral een afsluitende gekoppelde consistentievoorwaarde. Zij rechtvaardigt geen algemene dichte Jacobiaan, verzachting van fysische drempels of vervanging van alle numeriek.

## 5. Inventaris en afbakening van bestaande kennis

| Bevinding | Klasse | Bewijsgrens |
| --- | --- | --- |
| B0 accepteert bevroren oplossing die na herberekening eigen criteria overschrijdt | 1. Aangetoonde oorspronkelijke beperking van het gekoppelde acceptatiecriterium | Zelfstandig B0, oorspronkelijke koude toestand, twintig geselecteerde stappen. Geen aangetoonde fout in de uitwisselingswet zelf. |
| Lokale kwadratuurgeschiedenis met schaduwnaam; beperkte macro-rollbackset; kleine-voorraaddrempels | 2. Mogelijke oorspronkelijke numerieke kwetsbaarheid | Concrete bronlocaties; schadelijk gevolg niet afzonderlijk gekwantificeerd. |
| Hybride S5MAC006-toestand, dagvensters en kalendergebonden verversing | 3. Hybride toestandsoverdracht/migratie | `original_macro_policy.py` herstelt oorspronkelijke bevriezing, maar bouwt op gegenereerde eigenaren, budgetretry, maaiveldfeedback en expliciet gemaakt procesgeheugen. Dat is geen letterlijke B0-uitvoering. |
| Schakelen van verzadigde zones, instroom en beschikbare berging | 4. Fysisch verklaarbare procesovergang, met numerieke drempels | Een scherpe overgang is op zichzelf geen bug. De private V1 tot V9-migratieproeven bewijzen geen oorspronkelijk B0-defect. |
| Hybride dag438-residu 4.3198 en 79.511 cm GWL-afwijking; andere hele-trajectverschillen | 5. Onvoldoende verklaard als oorspronkelijke B0-trajectfout | Uitwisseling verklaart het hybride residuverschil; aandeel in de gehele GWL-fout en voorkomen van dezelfde B0-dag438-toestand blijven open. |

Geraadpleegde bestaande autoriteiten: `docs/science/ANDELST_JOINT_CONTACT_RESEARCH.md`, `FULL_TRAJECTORY_SCIENTIFIC_DISPOSITION.md`, `research/hybrid-water01/ORIGINAL_MACRO_DAY438_20261112.md`, `MACRO_DIRECTIONAL438_20261112.md`, `docs/audits/PPA_WU05_MIGMAC10_B0_ANDELST_REFERENCE_RUN.md`, `ADR-0005-reference-baseline-chain.md`, B0-identiteit en actuele Status-A-documentatie. De bestaande hybride vector-, richtings- en geschiedenisproeven zijn als afzonderlijke eerdere bewijslijn gebruikt; hun binaire capsules zijn deze audit niet opnieuw volledig gereproduceerd.

## 6. Gerichte Codex-vervolgopdracht, uitsluitend experimentele B1

Voer uitsluitend **SWAP431-MACRO-B1-ACCEPT01** uit op een nieuwe branch vanaf deze auditbasis. Dit is eerst een begrensde acceptatieproef, geen vooraf toegelaten referentiecorrectie. Lees ook het bestaande `reference/swap-4.3.1/b1-manifest.yml`: de huidige gecorrigeerde lijn heet B1.12. Een macro-experiment mag die snapshot of haar patchreeks niet stilzwijgend vervangen; registreer een eventuele latere patch afzonderlijk volgens ADR-0005. Laat canonical, actieve ontwikkelbranches, oorspronkelijke archieven en de macroporiënvrije release ongemoeid.

1. Reproduceer eerst de opgeslagen twintig B0-observaties en de exacte controle/observer-uitvoergelijkheid. Gebruik `B0_MACRO_AUDIT01_EVIDENCE.zip` en `assess.py`; leg nieuwe compileridentiteit afzonderlijk vast.
2. Ontwerp buiten B0 de kleinste experimentele wijziging in `headcalc.f90` die na voorlopige bevroren convergentie de actuele matrix/macroporiënkoppeling beoordeelt met de bestaande lokale, totale, pond- en hoofdcriteria. Werk bij falen het gekoppelde probleem opnieuw uit of gebruik de bestaande afwijzingsroute. Verander geen fysica, dtmin, reductiewet, grens of kalendervoorwaarde. Een losse fluxverversing gevolgd door acceptatie is onvoldoende.
3. Behandel die verse beoordeling als een trial: leg vast welke macrovelden worden veranderd en herstel ze bij afwijzing, of evalueer vanuit expliciet bewaarde stapbegintoestand. Maak geen nieuwe volledige toestandarchitectuur; neem alleen de echte afhankelijkheidsset van deze route mee. Behoud één gepaarde uitwisselingsflux voor donor en ontvanger.
4. Selecteer eerst uitsluitend dezelfde oorspronkelijke twee dagen. Bewijs op geaccepteerde B1-stappen dat gecachet en vers gekoppeld residu de oorspronkelijke criteria respecteren. Registreer iteraties, echte afwijzingen, IDecMpRat, pond/matrix/macro/drainagebalansen en veranderingen in drukhoogten tegenover B0. Dichter bij SWAP5 komen is geen acceptatiecriterium.
5. Voeg één korte werkelijke afwijzing/herhaling toe die behoud van stapbeginvoorraden én sorptiegeheugen controleert. Vergelijk bij dezelfde begincontext de retry met een verse kleinere stap. Alleen een eindbestand of twee gelijke evaluaties is onvoldoende rollbackbewijs. Controleer op de gewijzigde toestand de benodigde macroafgeleiden gericht met eindige verschillen; herhaal geen algemene 112-kolommen-campagne zonder aanwijzing.
6. Bouw de geselecteerde B0/B1-proef bij O0 en O2. Stel modeltijdlimiet twintig seconden per tweedaagse route in; een overschrijding is een kosten-/robuustheidsbevinding, geen toestemming om de limiet of criteria te verruimen. Geen 481-daagse run en geen hybride dag438-checkpoint als B0 vermommen.
7. Stop na maximaal twee concrete correctievarianten als geen robuuste conservatieve acceptatie ontstaat. Rapporteer dan een beperkte numerieke vervolgsvraag; promoveer geen B1 en activeer niets in productie. Alleen bij geslaagde korte kwalificatie volgt een aparte beslissing over een langere referentieproef en eigen herstart.

Een specifieke definitieve Fortran-patch is nog niet voorgeschreven: het ontbrekende gekoppelde eindcriterium is bewezen, maar een correcte heroplossing met behoud van het oorspronkelijke procesgeheugen is nog te kwalificeren. Dat onderscheid voorkomt dat de audit een nieuwe speculatieve migratiereparatie wordt.

## Bewijs en reproduceerbaarheid

De capsule bewaart beide werkelijk gebruikte executables, oorspronkelijke bronarchieven, alle gegenereerde bronkopieën, compiler-/objectidentiteiten, observatiebron en C-forkhelper, oorspronkelijke projectinvoer per korte run, vier uitvoerdirectories, twintig volledige oude/nieuwe residu- en uitwisselingsvectoren, eindtoestand, beoordelaar en apart gelabelde setupfouten. `RESULT.json` bevat het machineleesbare besluit.

Na uitpakken voert `python assess.py` alleen de gegevenscontrole uit, zonder compilatie of model. Voor nieuwe modelobservaties bouwt de bestaande `tools/vq/b0_source_runner.py:build_gfortran` uit de twee oorspronkelijke archieven; `prepare_probe.py` genereert de afzonderlijke observer. `OBSERVER_BUILD.json` bevat de daadwerkelijk gebruikte compile/linkcommando's. De huidige capsule bevat geen nieuwe B1 en geen algemene kwalificatie-infrastructuur.

De bronanalyse en B0-observatie zijn uitgevoerd; het gekoppelde acceptatieprobleem is aangetoond binnen de beschreven scope. B1-correctie, algemene rollback, volle Jacobiaanconsistentie bij alle overgangen, historische dag438-causaliteit en wetenschappelijke trajectnauwkeurigheid blijven afzonderlijke open kwalificaties. Canonical en productie zijn niet gewijzigd.

## Afbakening van toetsing

De twee preregistreerde hypothesen zijn afgehandeld: H1 bevestigd binnen de geselecteerde vroege B0-stappen, H2 zonder effect op diezelfde toestanden. Een echte afgewezen oorspronkelijke tijdstap, algemene rollback, een volledige B0-Jacobiaanproef, O0/O2-portabiliteit en oorspronkelijke dag438-causaliteit zijn niet onderzocht of gekwalificeerd. De open bronkwetsbaarheden leveren daarom geen tweede of derde speculatieve B1-patch op. Er is geen nieuwe algemene kwalificatie-infrastructuur of productie-interface gemaakt.
