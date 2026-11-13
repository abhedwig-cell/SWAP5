# RESTART08 — afgebakend native macroherstartcontract

Voor een geldige eigen herstart ontbreekt meer dan een macrovoorraadveld in het bestand. De minimale verdedigbare aanvulling bestaat uit **een versiegebonden macroblok, herstel na constante initialisatie zonder tijdintegratie, en hervatten van de oorspronkelijke subdagfase met dezelfde volgende dt en forcing**. Alleen macroarrays toevoegen aan `inoutend` lost de aangetoonde herstartfout niet op.

Dit is een brongebonden, voorgesteld contract. Er is geen Fortran gewijzigd, geen nieuwe modelroute gestart en geen herstart-PASS afgegeven. De RETRY07-afwijzing/herstel/directe-retrykwalificatie blijft geldig; de oorspronkelijke eigen herstart blijft FAIL. De kandidaat en officiële referenties blijven ongewijzigd.

## Basis en beoogde grens

Basis: RETRY07 `fd5f1065a6c7673f871526a2042f3ed6e3428660`, bewijsarchive SHA256 `4fc7108ef0ab93a7840174f5fcae7298c63e8a479f2d8b8f7cb74df8c5c6c9fb`. De remote kandidaat en canonical zijn gecontroleerd; canonical blijft `a6720a0e8d7de6541069bdbdfd407fb1f41d3614`. Alle wijzigingen staan uitsluitend in `research/swap431-macro-b1-restart08/` op een nieuwe onderzoeksbranch.

De eerste implementatie moet uitsluitend de bestaande oorspronkelijke B-checkpoint ondersteunen: na volledige water-/integraal-/warmte-/tijdafhandeling en direct na TimeControl(3), vóór de volgende hoststap. Er mag geen afgewezen proef openstaan. Het betreft SWMBF=1, SWABS=1, SWDRA=1, SWFROST=0, SWHYST=0, SWSOLU=0, SWHEA=1, SWCROP=1 en een schone ongereduceerde grens. De oorspronkelijke kleilagen hebben SWSOILSHR=1: dynamische scheurhistorie is hier dus relevant.

`CONTRACT.json` bevat veldgroepen, vormen, acties, invoegvolgorde en toelatingsproeven. `SOURCE_MAP.json` bevat 24 genummerde bronfragmenten met bronhashes. `contract08.py` controleert deze verklaringen tegen de oorspronkelijke bronnen en bestaande meetgegevens zonder modeluitvoering. Dit controleert traceerbaarheid en noodzaak; het bewijst nog geen voldoende implementatie.

## Welke toestand ontbreekt?

| Toestand | Minimale behandeling | Reden |
| --- | --- | --- |
| `WaSrMpDm(1:NumDm)` | Bewaren | Voor SWMBF=1 is dit de domeinvoorraad die ratebeperkingen en de volgende commit gebruiken. Zij volgt niet uit matrixdrukhoogten. |
| `TimAbsCumDmCp`, `ThtSrpRefDmCp`, `SorpDmCp` | Bewaren per domein/compartiment | Lopende sorptie gebruikt verstreken eventtijd, opgebouwde referentie en beginsorptiviteit. Bij herstart vanuit nul ontstaat een nieuw event. |
| Geaccepteerd `VlMpDmCp` en de scheurvertakking `VlMpDyCp` | Geaccepteerde geometrie bewaren; branchcache bewaren of exact reconstrueren | MPVOLUME(1) leest bestaande scheuren bij bevochtiging. MPVOLUME(2) kan het domeinvolume bovendien begrenzen op aanwezige watervoorraad. H/theta alleen bepalen deze historie niet. |
| Domeinbodem, watertop en waterniveau; natte wand; volume-/voorraadsommen; `AwlCorFac` | Coherent herstellen vóór eerste gebruik | Hiervoor kan een zuivere reconstructie uit bewaarde voorraad/geometrie worden gemaakt. De bestaande MACROSTATE is daarvoor ongeschikt. Direct bewaren van deze kleine caches is aanvankelijk minder ingrijpend. |
| Oppervlaktegeometrie `ArMpTp`, `ArMpTpDm`, `ArMpSs`, `KsMpSs`, `SubsidCp` | Fasegetrouw behouden totdat reconstructie bewezen is | MPVOLUME(2) vermeldt expliciet dat de oppervlaktefractie niet mee wordt bijgewerkt met de gecorrigeerde geometrie. Vers herberekenen kan daarmee een andere fase creëren. |
| Exact checkpointtijdstip, volgende dt, dagfase en actuele dagelijkse forcing | Herstellen via een expliciete hervatroute | De huidige opstart voert een nieuwe dagstart uit en kiest daardoor een andere dt en dagklok. |

De lijst is de kleinste verdedigbare directe uitbreiding van de bestaande route, geen bewezen minimumaantal bytes. `VlMpDyCp` kan bijvoorbeeld uit de opgeslagen domeinvolumes worden afgeleid met precies de oorspronkelijke aftrek-/som-/max-volgorde; twee representaties bewaren is dan niet informatie-theoretisch noodzakelijk. Ook totalen kunnen uit domeinwaarden volgen. Zulke verkleiningen mogen pas na een zuivere, volgordevaste reconstructiecontrole.

Het gemeten tekort blijft concreet: negen compartiment-/domeincellen hebben een lopende klok; bij de oorspronkelijke herstart verdwijnt die klok geheel (maximaal 0,02002999974 dag). De macro-totaalvoorraad verschilt 0,010407692 cm en de domeinvoorraad maximaal 0,032567926 cm, terwijl matrix h/theta exact zijn teruggelezen. De native tekstuitvoer bevat H en DT, maar geen van de bovenstaande macrohoofdvelden. O0 en O2 geven dezelfde bevindingen.

## Wat hoeft niet als oude proefgeschiedenis mee?

De oorspronkelijke SoilWater(2) bewaart vóór headcalc opnieuw de actuele h/theta/pond en MacroStateVar(1) opnieuw de actuele domeinbodem, volume- en watervoorraadarrays. De M1-waarden van de voorgaande stap mogen niet na deze stapbasisopslag teruggezet worden. Bij de gekozen grens moeten de nieuwe M1-waarden dus uit de herstelde actuele toestand ontstaan.

MACRORATE wist de uitwisselings-/instroom-/drainagerates en afgeleiden. ABSORPTION(1) stelt eventflags en interne keuze-/afgeleidecaches opnieuw vast. `FlEndSrpEvt` is daarmee bij deze grens een herberekenbare uitvoer van de nieuwe rate-evaluatie; de blijvende klok, referentie en beginsorptiviteit zijn dat niet. Dit onderscheid verhindert dat alle tijdelijke arrays ten onrechte tot verplichte bestandsinhoud worden verklaard. De echte rate(1)-vóór-rate(2)-vóór-commit-volgorde moet wel behouden blijven.

Constante geometrie, hydrauliek, sorptieparameters en domeinverdeling mogen uit identieke invoer terugkomen. Bestand, modelkandidaat, raster, domeinen en forcing moeten daarvoor aantoonbaar dezelfde identiteit hebben.

De numerieke reductiehistorie is afzonderlijk relevant: `IDecMpRat`, `dtold` en de lokale SAVE-teller `headcalc::NStep` bepalen wanneer een reductie wordt opgeheven. Daarom ondersteunt de eerste versie uitsluitend de schone ongereduceerde grens. Voor IDecMpRat>0 is expliciete toegang tot die teller en aparte kwalificatie nodig; hem stil op nul zetten is geen geldige algemene herstart. `fldtmin` en de volgende dt blijven ook bij ongereduceerde hervatting betekenisvol.

## Waarom alleen lezen/schrijven niet volstaat

De native lezer draait vroeg in ReadSwap. Daarna voeren de oorspronkelijke MACROINIT en MACROSTATE een koude voorraadinitialisatie en geaccepteerde-toestandsberekening uit. MACROSTATE telt debiet×dt op en werkt de sorptieklok en referentie bij. Een ingelezen macroblok mag dus niet daarna door deze koude route worden overschreven, en MACROSTATE mag evenmin als hulpmiddel worden aangeroepen om herstelcaches te vullen. Dat zou de toestand nogmaals laten doorgaan.

Daarnaast zet TimeControl(1) `flDayStart=true`, `tcum=0` en diverse tellers terug. De eerste hostlus roept vervolgens TimeControl(2) aan. Daar staat `dt=max(dt,sqrt(dtmin*dtmax))`. Met de oorspronkelijke grenzen 10⁻⁵ en 0,002 dag verklaart dit exact de waargenomen eerste herstart-dt **0,0001414213562373 dag**, tegenover **0,00001 dag** continu. Het bestand bevat DT wel; de dagstart verandert hem daarna.

Dezelfde dagstart voert meteo-, crop-, irrigatie- en interceptiehandelingen uit. Alleen `flDayStart=false` zetten zonder actuele dagelijkse context te herstellen is daarom evenmin voldoende. Forcingbestanden moeten op hetzelfde kalender-/laadvenster en dezelfde gebeurtenis gezocht worden. In SWRAIN=3 hangt de dagelijkse regenaggregatie mede van TSTART af; een verplaatst starttijdstip mag niet ongemerkt een andere dagdefinitie geven. Dit is een brongebonden risico; in deze ronde is geen nieuwe kwantitatieve forcingfout bewezen. De volgende pre-head-forcingvergelijking moet dit beslissen.

Voor deze casus betreft dat concreet de meteo-/regencursor en updateflag, actuele dagelijkse temperatuur/radiatie/regen, ET-potentiëlen (`epond`, `peva`, `ptra_dry`, `ptra_wet`), interceptiecontext en actuele eenvoudige gewasgeometrie. Het oorspronkelijke cropbestand heeft SWINTER=3 (Rutter). `sicact` staat al in de native uitvoer onder sleutel `SIACT`; de aanvulling moet hem behouden en het benodigde canopy-/ET-context vóór de volgende echte Rutter-aanroep beschikbaar maken. De verdampingsreservoirs SPEV/SAEV staan eveneens al in het bestand. `reduceva` wijzigt ze per stap: een voorbereidende meteo(3)-aanroep plus opnieuw de echte meteo(3) zou dubbel integreren en is dus geen geldige contextreconstructie. `CONTRACT.json` benoemt de concrete contextvelden; herberekenbare debieten kopiëren vervangt deze hostafhandeling niet.

## Minimale voorgestelde aanvulling

1. **Een herkenbaar native macroblok.** Voeg aan de bestaande volledige binaire eigen uitvoer een vaste, getypeerde trailer met versie, exacte real(8)-tijd, fase, dimensies, identiteit en geaccepteerde macrotoestand toe. Laat macrovrije bestanden ongewijzigd. Ontbrekende/ongeldige macro-inhoud moet een expliciet verzoek om exacte macrohervatting afwijzen; geen stille matrix-only fallback. De bestaande tekstdatum is alleen bootstrap, geen nauwkeurige checkpointtijd.
2. **Uitgesteld, niet-integrerend herstel.** Lees de trailer eerst in een kleine lokale buffer. Bereid vervolgens constante geometrie en modelparameters voor, sla de koude voorraad-/commitroute over, installeer de volledige gevalideerde geaccepteerde toestand en herstel caches zonder debietintegratie of klokupdate. Valideer het complete blok vóór installatie; geen stil clampen of gedeeltelijk herstel. Dit vraagt beperkte aanpassing van inoutend en macro-initialisatie, geen algemene serializer.
3. **Een expliciete hervatfase in de bestaande host.** Herstel exacte tijd, oorspronkelijke kalender-/forcingoorsprong, volgende dt, tijdstapbeleid, dagfase en actuele dagelijkse context. Start vervolgens dezelfde volgende hostovergang als continu, inclusief nieuwe trialbasis, rate-evaluatie en volledige commit. Sla alleen reeds uitgevoerde dagstarthandelingen over. Er is geen plaats voor replay of handmatig geïnjecteerde solveruitkomst.

## Vereiste bewijsgrens en resterende uitsluitingen

De eerstvolgende implementatieproef moet in dezelfde B-context aantonen: eigen schrijver verandert de toestand niet; verse lezer herstelt voorraad/historie/geometrie en exacte tijd/dt; vóór headcalc zijn forcing, warmte-/cropcontext en nieuwe rollbackbasis gelijk; één volledige echte stap heeft dezelfde dt én eindtijd en dezelfde fysieke toestand als continu. Controleer opnieuw de onafhankelijke waterinventaris en gepaarde uitwisseling, met O0/O2 en maximaal twintig seconden per route. Bronveranderingen aan het rollback-invoegpunt selecteren daarnaast de bestaande echte afwijzing/directe-retryproef. Een eerdere PASS erft niet automatisch over een veranderde seam.

Exacte cumulatieve uitvoer is een afzonderlijke, expliciete grens. De macro-integralen en beginvoorraden staan evenmin in de eigen uitvoer. Bovendien declareert MACROINTEGRAL lokaal een `FrMpWalWetOld` die de modulevariabele overschaduwt en geen expliciete SAVE heeft. De huidige RETRY07-modulemeting observeert die lokale array niet. Hieruit volgt geen nieuwe bewezen fysieke fout, maar wel dat module-old-wall gelijkheid geen bewijs voor exacte uitvoercontinuïteit is. Een toekomstige volledige output-/PEARL-continuïteitsclaim moet dit gericht oplossen en kwalificeren; deze ronde introduceert geen aanpassing van die uitvoersemantiek.

KWT/SWMBF=2, SWABS=2, gereduceerde checkpoints, hysterese/frost, droge-event-/h=0-overdracht en brede trajecten blijven uitgesloten. Een geldige fysieke eigen herstart voor de geselecteerde context is hiermee concreet afgebakend, maar nog niet gebouwd of bewezen. De eerstvolgende stap kan de drie beperkte wijzigingen implementeren en op deze ene bestaande checkpoint toetsen. De oorspronkelijke herstart krijgt tot dat moment geen PASS.
