# CANOPY17 — minimale correctie BAL-canopyvoorraad

**PASS voor de BAL-wateropslag van dezelfde geselecteerde periode1–2januari, met O0/O2.** Begin-, eind- en verschilvoorraad bevatten nu het canopywater dat bij de bruto fluxgrens hoort. Alle1453budgetregels, fysieke meetvectors, temperaturen, gewascontext en de oude ledgerwaarden blijven exact gelijk aan BUFFER16. Er is geen wijziging van fysica, solver, reductiewet, toleranties of budgetformaat.

## Grondslag en beperkte wijziging

Basis is BUFFER16 `7ba226c35f6b4727cdc9879d8518bd94d432103c`. Canonical is nog `f1883e6fae59658112f6b5750c395a1b54543ed2`. De nieuwe onderzoeksbranch wijzigt uitsluitend deze onderzoekssubmap; B0, B1.12, canonical, release en andere werkstromen blijven onaangeroerd. Geen officiële promotie.

BUFFER16 had onafhankelijk aangetoond dat OUTBAL bruto regen en canopyverdamping gebruikt maar SICACT niet in de opslag opneemt. Alleen SICACT aan de eindvoorraad toevoegen is onvoldoende: bij volgende balansperioden kan canopywater al bij aanvang aanwezig zijn. De correctie omvat daarom:

1. Eén uitvoerbeginwaarde `MOD_integral::sicini`. Zij wordt tegelijk met de bestaande cumulatieve beginwaarden opgeslagen: bij de oorspronkelijke `iTask==1`/`flzerocumu`-reset. Voor SWINTER=3 is zij de actuele SICACT; anders nul. Er wordt geen bestaande fysieke variabele of integratie aangepast.
2. OUTBAL voegt voor SWINTER=3 SICACT toe aan de eindvoorraad, SICINI aan de beginvoorraad en hun verschil aan de opslagverandering. De twee oorspronkelijke schrijfvertakkingen blijven verder staan; deze proef kwalificeert alleen de actieve macro/SWSOLU=0-route. Fluxregels en bestaande opmaak veranderen niet.
3. Het native uitvoerblok bewaart de nieuwe beginwaarde. De versie is expliciet V5 met `WATER_LEDGER_V2` en133velden, zodat een oud bestand zonder deze informatie niet als exact herstel wordt behandeld. `canopy_BAL.patch` toont de kleine boekhoudingswijziging; `LEDGER_FIELDS.json` benoemt de aanvullende toestand.

SICINI is uitvoergeheugen, geen nieuwe waterbron, opslagdynamiek of algemene toestandsarchitectuur.

## Dezelfde oorspronkelijke periode en uitvoeringsgrenzen

Dezelfde ononderbroken oorspronkelijke coldprefix loopt van t1900=35795 tot de volledig afgesloten daggrens35797, met dezelfde V1+Darcycorrectie actief vanaf het eerste head. Het oorspronkelijke geplande DATEFIX2januari-uitvoerevent schrijft de BAL/BLC/BMA-records. Dezelfde native eigen herstart en eerste nieuwe-periode-stap volgen. De gebufferde budgetregistratie blijft identiek.

Er zijn vier positieve modelroutes (prefix en verse herstart voor O0/O2) en één vroege O2-afwijzing van een oud V4-bestand zonder de nieuwe beginwaarde. Langste modelroute **1,614seconde**. Alle routes blijven onder twintig seconden; geen censuur, bredere varianten- of481-daagse campagne.

## Resultaten

| Volledige precisie, cm | O0 en O2 |
| --- | ---: |
| Totale beginvoorraad inclusief canopy | 154,7122696654261 |
| Totale eindvoorraad inclusief canopy | 155,86570319971247 |
| Opslagverandering | 1,1534335342863642 |
| Canopy bij begin eerste periode | 0 |
| Canopy bij einde eerste periode | 0,0025926018136122326 |

De echte BAL-eindregel wordt nu **155,87cm**, tegenover155,86cm in BUFFER16. Begin wordt154,71cm en verandering1,15cm. De bestaande onafhankelijke afronding op twee decimalen blijft behouden; de volledige-precisietoets komt uit de afzonderlijke inventaris en niet uit het aftrekken van afgeronde tekstregels. Alle drie geprinte opslagregels voldoen aan de ongewijzigde afrondprecisie.

De complete BAL-fluxsectie is exact ongewijzigd. BLC, BMA en hun numerieke inhoud zijn eveneens ongewijzigd, afgezien van de standaard gegenereerde tijdstempel. Alle1453primitieve budgetregels zijn per optimalisatie bytegelijk aan BUFFER16 en onderling bytegelijk tussen O0/O2. De fysieke begin-, checkpoint-, begin-volgende-stap-, solverreturn- en eindvelden en de bestaande132ledgerwaarden blijven bytegelijk aan BUFFER16. De enige extra uitvoerwaarde is SICINI.

De onafhankelijke periodecontrole uit BUFFER16 is opnieuw uitgevoerd op deze resultaten. Matrix-, macro-, pond- en canopyveranderingen tegenover de werkelijke externe budgetintegralen geven dezelfde afwijking **+5,965585×10⁻⁷cm**, onder de ongewijzigde integraal van de totale residugrens (circa2×10⁻⁵cm). De oorspronkelijke vijf macro-domeinen sluiten op afrondniveau. De correctie verandert dus geen balansresultaat; de BAL-opslag stelt dat reeds gekwalificeerde resultaat nu juist voor.

## Niet-nul beginvoorraad, eigen bestand en reset

De geselecteerde eerste periode heeft aanvankelijk nul canopywater. Alleen die situatie testen zou een foutieve constante nulbeginwaarde niet uitsluiten. Daarom wordt ook de echte volgende periodereset gecontroleerd: SICINI wordt daar **0,0025926018136122326cm**, gelijk aan SICACT op35797. Continu en native herstart geven dezelfde waarde vóór en na de eerste volgende stap.

Daarnaast schrijft de echte typed ledgercode op dat moment het actuele blok, zet voor de test uitsluitend het uitvoerveld SICINI op nul, leest het blok terug en installeert de gelezen waarden. Alle133waarden worden exact hersteld, inclusief de niet-nul canopybeginvoorraad. Dit is een kleine uitvoercodec-probe in de bestaande modelroute, na de fysieke stap; geen aanvullende modelperiode of injectie van fysieke voorraad. De voor-/nadumps zijn bytegelijk.

Het volledige V5-eigen daggrensbestand herstelt de geaccepteerde toestand en uitvoerhistorie exact. Het natuurlijke resetgedrag en de volgende fysieke stap blijven exact gelijk tussen continu en herstart. Het oude V4-bestand wordt bij een verzoek om exacte uitvoerhistorie vóór installatie afgewezen. Er is geen stille nulaanname voor ontbrekende canopybeginhistorie.

## Geldigheidsgrens en herstelpad

De concrete BUFFER16-uitsluiting voor canopyvoorraad in de BAL-opslag is voor deze SWINTER=3-periode opgeheven. Status blijft **B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS**. Andere interceptiemodi, SWSOLU=1, andere hydrauliek, algemene latere periodes, native metadata-lifecycle, bestandsappend/PEARL en volledige lange trajecten krijgen geen nieuwe toelating. De tweede water-schrijfvertakking is consequent aangepast, maar haar combinatie is hier niet numeriek gekwalificeerd.

`assess_canopy17.py` herbeoordeelt bronidentiteit, oude fysieke/budgetgelijkheid, onafhankelijke periodebalans, echte BAL-regels, niet-nul reset-/codecgedrag en O0/O2 zonder modellen. STATUS.json, RESULT.json, canopy_BAL.patch, LEDGER_FIELDS.json en bewijsarchive vormen het herstelpad. Alleen een afzonderlijke concrete vraag selecteert verder werk; geen automatische brede campagne of referentiepromotie.
