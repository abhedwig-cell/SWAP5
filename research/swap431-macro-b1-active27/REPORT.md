# ACTIVE27 — gerichte selectie voor een actieve echte weigering

**Binnen drie gericht geselecteerde oorspronkelijke contexten is geen combinatie van actieve rang-één-aanvulling én echte afwijzing gevonden.** O0/O2 geven exact dezelfde uitkomsten: C1 en C3 convergeren met de aanvulling actief; C2 weigert werkelijk, maar zonder actieve aanvulling. De gevraagde actieve afwijzings-/rollback-/directe-retrykwalificatie is daarom **niet behaald**. Er is geen nieuwe PASS voor dat ontbrekende geval.

## Selectie vanuit bestaande bewijzen

Baseline is REJECT26 ba70d2f2eca6c5112223c0bf50ea94e3723554cc. De oorspronkelijke B-context uit REJECT26 leverde geen actieve update op. Daarom zijn nu bestaande originele DIAG19-weigeringen gekozen die destijds een andere node dan 52 als grootste residu hadden. Dat maakt ze gerichte kandidaten voor een resterende convergentiemoeilijkheid nadat de node-52-koppeling wordt meegenomen.

Aanvankelijk zijn twee contexten vooraf vastgelegd: C1, een oorspronkelijke node-57-weigering rond dagfractie 0,112, en C2, een latere node-56-weigering rond 0,442. Toen C1 accepteerde en C2 alleen inactief weigerde, is precies één laatste aanvulling geselecteerd: C3, de eerste oorspronkelijke niet-node-52-weigering in die reeks. Deze scopewijziging is vóór de C3-uitvoering vastgelegd in SCOPE_REVISION.json en git, zonder wijzigen van kandidaat of instellingen. De uiteindelijke grens is drie bestaande contexten. Daarna zijn de negatieve selectie-uitkomsten ook met O0 bevestigd; er is geen verdere contextzoektocht gestart.

| Context | Oorspronkelijke DIAG19-poging | Begin t1900 | Oorspronkelijke dt, dag | Grootste oorspronkelijke residu op node |
| --- | ---: | ---: | ---: | ---: |
| C1 | 624 | 35797,112023434041 | 0,000282842712474619 | 57 |
| C2 | 3502 | 35797,441763104143 | 0,0000789652864720362 | 56 |
| C3 | 224 | 35797,082345100527 | 0,000020951312035156963 | 57 |

Alle drie oorspronkelijke DIAG19-pogingen waren uitgeput na 30 iteraties. Dit selectiebewijs is niet verward met een weigering van de nieuwe kandidaat.

## Oorspronkelijke aanloop behouden

Elke route begint in een vers native proces op dezelfde bestaande afgesloten daggrens 35797. De originele V1/Darcy-aanloop wordt behouden; alleen op de vooraf geselecteerde originele t/dt-context wordt de bestaande current-operator/rang-één-kandidaat geactiveerd. Er wordt geen later headprofiel of voorraad geïnjecteerd.

De nieuwe prefix_budget.txt is per optimalisatie bytegelijk aan de oude oorspronkelijke NEXT18/DIAG19-route over respectievelijk **296, 1522 en 116 geaccepteerde stappen** vóór de selectie. De oorspronkelijke tijd- en dtwaarden worden op de levende host gecontroleerd. De aanloop is dus niet stilzwijgend met de nieuwe kandidaat doorgerekend, waardoor een andere targetcontext zou zijn ontstaan.

Alle Fortranbronnen zijn bytegelijk aan REJECT26 behalve de onderzoeksdriver voor contextselectie, prefixregistratie en stop. De rang-één-formule, actuele operator, fysieke providers, voorraadgrens, criteria, MAXIT, dtgrenzen en reductiepolicy zijn ongewijzigd. Geen weigering is afgedwongen met een kleinere iteratielimiet of grotere dt. Per selectie zijn maximaal vier oorspronkelijke pogingen toegestaan en wordt bij een fluxreductieverzoek gestopt; de werkelijke routes gebruiken één of twee pogingen.

## Werkelijke uitkomsten met de kandidaat

| Context | Eerste headpoging | Iteraties | Actieve rang-één-iteraties | Grootste eindresidu | Selectie geschikt? |
| --- | --- | ---: | ---: | ---: | --- |
| C1 | Geconvergeerd | 5 | 1 | 4,218925642868188e-8 | Nee: geen weigering |
| C2 | Echt afgewezen | 30 | 0 | 4,313964211692667e-5 | Nee: update inactief |
| C3 | Geconvergeerd | 2 | 1 | 8,501548728750974e-7 | Nee: geen weigering |

De eerste somresiduen zijn respectievelijk 2,769783786344802e-7, −2,006203381984762e-4 en 5,558688809726689e-6. C1 en C3 voldoen aan de oorspronkelijke criteria en ondergaan een echte verse V1-certificering. Hun eerste rang-één-activering is aantoonbaar in de lineaire trace; dat alleen maakt een route nog geen actieve weigering.

C2 levert wel een echte dt-verkleiningsaanvraag na 30 iteraties. De originele rollback en TimeControl(5) leiden tot dt=2,6321762157345398e-5. Deze kleinere retry accepteert in drie iteraties, eveneens zonder actieve rang-één-aanvulling. De onderzoeksdriver laat de eerste werkelijk geaccepteerde stap per context door de oorspronkelijke hostintegratie committeren en stopt daarna.

De uiteindelijke inventarisafwijkingen blijven in alle drie routes binnen de ongewijzigde geïntegreerde totale residugrens:

| Context | Afwijking inventaris, cm | Gebruikte dt × CritDevBalTot, cm |
| --- | ---: | ---: |
| C1 | 7,834122695178636e-11 | 2,8284271247461902e-9 |
| C2, kleinere retry | −8,24150425367872e-12 | 2,63217621573454e-10 |
| C3 | 1,1646193614049953e-10 | 2,0951312035156965e-10 |

Deze lokale geaccepteerde commits bevestigen de werkelijke uitkomsten; zij leveren geen ontbrekend bewijs van rollback na een actieve weigering.

## O0/O2 en rekengrenzen

| Route | O0 | O2 |
| --- | ---: | ---: |
| C1 | 2,263 s | 1,576 s |
| C2 | 9,254 s | 7,052 s |
| C3 | 0,885 s | 0,823 s |

Er zijn zes modelroutes uitgevoerd, drie oorspronkelijke selecties per optimalisatie. Alle stoppen normaal en ongecensureerd onder twintig seconden per route. Er zijn geen extra setupfouten, parameterroosters, langere periode of brede campagne toegevoegd.

Alle niet-timingvectors, prefixregels, operator-/Jacobiaantraces, voor-/na-velden en commit-/ledgerexports zijn per context bytegelijk tussen O0 en O2. Het negatieve selectieresultaat is dus geen onbesliste optimalisatie- of timeoutkwestie.

## Besluit en geldigheidsgrens

Status is NO_SUITABLE_ACTIVE_REFUSAL_IN_THREE_SELECTED_ORIGINAL_CONTEXTS. Er is geen passende context geselecteerd. Daarom zijn **geen DIRECT-routes** gestart en is geen actieve rollback/directe-retry-PASS toegekend. Een directe kleinere berekening bij een geaccepteerde grote stap of opnieuw een inactieve weigering zou het gevraagde bewijs niet leveren.

Het resultaat bewijst niet dat een actieve echte weigering nergens bestaat. Het bewijst alleen dat deze drie bestaande originele afwijzingen met de nieuwe kandidaat niet aan beide voorwaarden voldoen. De selectie is niet uitgebreid tot een open zoektocht totdat een gewenst resultaat verschijnt, en de ongewijzigde acceptatiecriteria zijn niet aangepast.

De eerdere lokale active-acceptatie-PASS uit JAC24/COMMIT25 en inactive-weigerings-PASS uit REJECT26 blijven elk binnen hun eigen scope. Zij worden hier niet samengevoegd tot bewijs van een actieve afwijzing. Ook algemene solvertoelating, native herstart en volledige periodebalans blijven buiten deze ronde. De bestaande IEEE_DENORMAL-instrumentatiemelding blijft in de ruwe uitvoer bewaard.

assess_active27.py beoordeelt uitsluitend bestaande bestanden. SELECTION.json, SCOPE_REVISION.json, RESULT.json, driver_only.patch, oorspronkelijke prefix-/targetexports, builds en de geverifieerde ACTIVE27_EVIDENCE.zip vormen het herstelpad. Geen officiële promotie.
