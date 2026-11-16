# HISTORY13 — beschikbare oorspronkelijke cumulatieve historie

**Er is oorspronkelijke historie beschikbaar, maar geen complete exacte uitvoerhistorie voor de huidige native kandidaatroute vanaf het bedoelde periodebegin.** Verzegelde dagelijkse B0/V1/V2-uitvoer bevat oorspronkelijke beginvoorraden en twee dagrecords. De eerste volledige exacte ledger-snapshots in de onderzochte keten ontstaan pas in LEDGER12, na een bootstrap die de eerdere cumulatieven niet bevatte. Het lokale continuïteits-PASS blijft geldig; de volledige periodebalans blijft ongekwalificeerd.

Er zijn geen modellen gestart, geen totalen gecorrigeerd en geen product-/referentiebronwijzigingen gedaan. Deze onderzoeksbranch is uitsluitend bewijsinventarisatie en contractafbakening. Basis: LEDGER12 `f17f26ae632d08cd1b4a01dae68acacbeb559e2c`. Remote canonical is nog `f9ada0cb2134971f92267a209f3a1fc86901dda8`; geen nieuwe afhankelijkheidsdelta.

## Wat daadwerkelijk is gevonden

| Bewijs | Beschikbare historie | Bruikbaarheid |
| --- | --- | --- |
| ACCEPT01 verzegelde tar.xz, B0/V1/V2 O2 en V1 O0 | Aanvangsregel1997-12-31; dagrecords1998-01-01 en1998-01-02; matrix-/macrovoorraden en geprinte balans-/fluxcomponenten | Historische controles van die varianten, afgeronde dagaggregaten |
| Native NATIVE09 TRIAL, lokaal overgebleven CSV | Alleen aanvang en eerste dag; numerieke regels exact gelijk aan de verzegelde V1-regels | Aanvullende bevestiging van de oorspronkelijke koude aanloop; nu apart gekopieerd/gehasht, niet ten onrechte als vroeger verzegeld gepresenteerd |
| STATE02 t/m MIDNIGHT11 verzegelde meetvectors | Druk-/vochtvelden, macrovoorraad, actuele rates, sorptiehistorie, eigen bestanden en geselecteerde gebeurtenissen | Geen complete cumulatieve carry-in; de eigen bestanden bevatten deze uitvoervelden aantoonbaar niet |
| LEDGER12 V3 en exacte ledger-snapshots | Volledige geselecteerde132veld-uitvoertoestand op de onderzochte daggrens en vervolgstep | Exacte lokale opslag/voortzetting vanaf de laatste bootstrap; geen oorspronkelijke periodehistorie |

De oorspronkelijke geprinte macro-aanvangsvoorraden zijn **1,58200cm MB** en **0,04949cm IC**. De eerdere formulering “geen historie” was dus te ruim. Wat ontbreekt is de complete, exacte en bij de werkelijk uitgevoerde route behorende carry-in. De oude dagelijkse gegevens staan in `DAILY_HISTORY.json` en `recovered/`, met exacte archiefpaden en SHA256. Hun bronarchive is geverifieerd op SHA256 `80c6adaf4228e9332fabcecbe3ec3582636c005d6081916e85135ec301f0cf71`.

`SOURCE_INVENTORY.json` beschrijft acht geverifieerde native bewijscapsules plus ACCEPT01. `history13.py` controleert in de verzegelde native meetvectors van beide optimalisaties op numerieke cumulatief-/beginvoorraadvelden; ACCEPT01 txt/dat/csv-exports worden eveneens gecontroleerd. Alleen LEDGER12 bevat die onderzochte exacte ledger-snapshots. Dit is een afgebakende conclusie over de onderzochte bewijsketen, geen universele claim over iedere externe back-up. In deze keten is geen volledige exacte carry-in vóór LEDGER12 teruggevonden.

## Waar de dekking verloren ging

De keten bevat meerdere fysieke handoffs zonder uitvoerhistorie:

1. NATIVE09 TRIAL loopt werkelijk vanaf de oorspronkelijke start tot B en schrijft daar fysieke toestand, maar geen cumulatieve wateruitvoer.
2. DAY10 leest dat B-bestand, zet de fysieke voortzetting door en schrijft de laatste subdagcheckpoint op t35796,99991333311, opnieuw zonder ledgers.
3. MIDNIGHT11 en LEDGER12 beginnen bij die laatste subdagfile. Alleen LEDGER12 voegt vervolgens echte cumulatieven aan het nieuwe daggrensbestand toe.

De exacte lokale LEDGER12-dekking loopt dus van **35796,99991333311** via **35797** tot **35797,0001733362**. Zij omvat de laatste grensstap en eerste volgende-dagstap, met de bestaande beginwaarden van die bootstrap. De nulwaarden van WaSrDm1Ini/WaSrDm2Ini zijn aantoonbaar niet de oorspronkelijke beginvoorraad. De uitvoerlabeldatum TSTART1998-01-01 maakt dit niet alsnog een volledige periodebalans.

Ook de bron-/beleidshistorie moet expliciet blijven. In de kwalificatieharness blijft de Darcy-patch uit tijdens de oorspronkelijke aanloop en wordt zij pas in de geselecteerde levende context ingeschakeld. Een volledige-periodeclaim voor een kandidaat die de patch vanaf de start gebruikt, is daarmee niet bewezen. Afzonderlijke snapshots of oude V1-dagtotalen mogen dit verschil niet verbergen.

## Waarom bestaande dagrecords het gat niet sluiten

De oude records zijn dagelijkse, geformatteerde aggregaten, geen binaire132veld-toestand. Afronding en aggregatie verliezen onder meer exacte cumulatieven op een subdaghandoff, profielen, tussenperioden en tijdgewogen wandhistorie. Zelfs waar een vroege gedrukte dagregel overeenkomt, is dat geen bewijs van bitgelijke volledige native historie. ACCEPT01 gebruikte bovendien Linux-gfortran14.2, de native lijn een andere geregistreerde compilerclosure; STATE02 toont kleine native/Linux-toestandsverschillen.

Verder horen B0/V1/V2-eindtotalen bij hun eigen uitwisseling en acceptatie, zonder de latere CONTRACT06-patch. Oude totaalfluxen optellen bij de huidige eindvoorraad zou varianten mengen. De geprinte nulbalans is geen vrijbrief om die oude totalen als huidige waarheid te gebruiken.

Alleen de nulbeginvoorraden vervangen door1,58200 en0,04949cm is evenmin voldoende: de bijbehorende exacte fluxen en eventuele perioderesets ontbreken nog. Omgekeerd mag het balansbegin niet stil op de bootstrapdatum worden gezet terwijl de uitvoer het oude TSTART blijft melden. Een kortere lokale periode is alleen geldig als zij expliciet zo wordt benoemd, met echte exacte startinventaris en bijbehorende nulgestelde lokale fluxen; dat is een ander contract.

## Minimale aanvulling voor een geldige volledige periodebalans

**Eerst het bedoelde begin, einde en de route vastleggen.** De hier bedoelde begrensde volledige periode is de oorspronkelijke start1998-01-01 tot de onderzochte daggrens na2januari. De oorspronkelijke invoerperiode tot april1999/481dagen is een veel grotere, ongekwalificeerde claim. Leg tevens vast of de historische staged route wordt gevolgd of de vaste kandidaat vanaf T0; geen ongedocumenteerde wijziging tijdens de periode.

**Voor uitsluitend de totale macrobalans is minder nodig dan132 velden.** De minimale fysieke rekensom vraagt de exacte oorspronkelijke MB-/IC-beginvoorraad, de13 toepasselijke CQMp-fluxcomponenten sinds datzelfde begin en de huidige voorraden. De131/132 tussen-/profielvelden zijn niet alle noodzakelijk voor die ene totaalsom. Voor een volledige matrix-plus-macro-waterbalans komen daar de exact passende matrix-, oppervlakte-, canopy-/eventueel sneeuwinventarissen en externe regen-, irrigatie-, ET-, bodem-, drainage- en runoffintegralen bij. Interne matrix-macrouitwisseling mag in het gecombineerde saldo niet nogmaals als externe bron worden geteld. De132veldset blijft nodig voor de afzonderlijk gekozen uitvoercontinuïteit, niet als bewijs dat al die velden een mathematisch minimum voor een totaalsaldo zijn.

**Exacte carry-in verkrijgen of de ontbrekende prefix éénmaal vastleggen.** Als een bestaande same-candidate-ledger op de eerste handoff alsnog beschikbaar komt, moet die aan bron, tijdstip, beginvoorraden en dekking worden gebonden. In de huidige onderzochte evidence is zij niet gevonden. Het alternatief is een afzonderlijk geselecteerde gerichte aanvulroute vanaf het verklaarde balansbegin, die de oorspronkelijke integralen zonder onderbreking tot de gekozen checkpoint opbouwt en opslaat. Men kan de ontbrekende handoffs voorzien van uitvoerhistorie, of alle ongedekte tussentijdse fysieke bestandswissels vermijden. Alleen de laatste grensstap opnieuw uitvoeren kan het eerdere gat niet herstellen.

**Dekkingsmetadata toevoegen.** V3 bewaart de getallen, maar bewijst niet dat ze vanaf het uitvoerlabel compleet zijn. Een kleine aanvulling moet de exacte ledger-oorsprong, gedekte eindtijd/uitvoeringsfase, bron-/beleididentiteit en expliciete volledige/onvolledige carry-in vastleggen. Een verzoek om volledige periodeuitvoer moet onvolledige dekking afwijzen. Nul is een geldige cumulatiefwaarde en mag daarom niet als detector voor ontbrekende historie worden gebruikt. Ook een niet-nul ledger kan onvolledig zijn. De huidige bootstrap moet expliciet “onvolledig” blijven; metadata mag haar niet promoveren.

**Daarna de echte periodebalans kwalificeren.** Controleer met O0/O2 het onafhankelijke externe saldo van de oorspronkelijke inventaris naar de eindinventaris, cumulatieve toenamen, eventuele reset-/venstergrenzen en de daadwerkelijk geplande periode-uitvoer met correcte labels. De LEDGER12-OUTBMA-probe bewijst rendererequivalentie, niet de geldigheid van het oorspronkelijke periode-etiket of een natuurlijk eindperiode-event. Een geformatteerde CSV-nul is geen vervanging voor de oorspronkelijke residu-/inventariscriteria.

## Besluit en grenzen

Er is een concrete minimale bron- en dekkingsaanvulling bepaald. De huidige bewijzen volstaan voor lokale native herstart en uitvoercontinuïteit, maar niet voor een geldige volledige oorspronkelijke periodebalans. Er zijn geen modellen of nieuwe campagnes gestart. Een eventueel gerichte prefix-capture vraagt een nieuwe expliciete selectie, dezelfde20seconden/route en de bestaande stopregels; zij wordt hier niet automatisch uitgevoerd en selecteert nooit een481-daagse campagne.

Herstelpad: STATUS.json, RESULT.json, SOURCE_INVENTORY.json, DAILY_HISTORY.json en history13.py. De herbeoordeling verifieert archives en hergebruikt vastgelegde informatie zonder modellen. Lokale aanvullende CSV is duidelijk van eerder verzegelde bronnen onderscheiden. Geen referentiepromotie of wijziging van bestaand kwalificatiebewijs.
