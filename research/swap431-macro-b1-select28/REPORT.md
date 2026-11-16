# SELECT28 — verdere gerichte selectie en activeringsvoorwaarden

**Ook in deze verdere selectie is geen echte afwijzing met actieve rang-één-aanvulling gevonden.** Alle drie nieuwe oorspronkelijke contexten convergeren met de kandidaat. D1 en D2 hebben potentiële instroom en vallen daardoor buiten de activeringstak. D3 heeft nul instroom en drie actieve rang-één-correcties, maar convergeert in zeven iteraties. O0/O2 geven exact dezelfde numerieke resultaten. De gevraagde actieve rollback/directe-retrykwalificatie blijft **niet behaald**.

## Selectie en behoud van de kandidaat

Baseline is ACTIVE27 dd47bab261c47945437492f26e9fd92e02fe7717. Er zijn uitsluitend nog niet getoetste oorspronkelijke DIAG19-weigeringen geselecteerd, zonder andere dt, tolerantie of fysieke instelling te proberen. De eerste twee keuzes hadden de meeste extra line-searchpogingen in de oorspronkelijke node-57- respectievelijk node-73-groep vóór dagfractie 0,31. Beide oorspronkelijke pogingen waren werkelijk na 30 iteraties afgewezen.

Toen D1/D2 met de kandidaat convergeerden en hun Jacobiaantraces potentiële instroom als activeringsuitsluiting lieten zien, is één laatste vroeger gelegen context toegevoegd: de node-57-weigering met twaalf extra line-searchpogingen rond 0,1197, nabij de reeds bewezen nul-instroomfase. De uitbreiding van maximaal twee naar maximaal drie contexten is vóór die uitvoering vastgelegd in SCOPE_REVISION.json en git. Er zijn geen verdere contexten of parametervarianten geprobeerd. Vervolgens zijn de drie selectie-uitkomsten met O0 bevestigd.

| Context | Oorspronkelijke DIAG19-poging | Begin t1900 | Oorspronkelijke dt, dag | Oude grootste residunode | Oude extra line-searchtrials |
| --- | ---: | ---: | ---: | ---: | ---: |
| D1 | 2630 | 35797,265343787018 | 0,0002222222222222222 | 57 | 13 |
| D2 | 3066 | 35797,290420649493 | 0,000282842712474619 | 73 | 35 |
| D3 | 734 | 35797,119712565516 | 0,000282842712474619 | 57 | 12 |

Alle Fortranbronnen, inclusief onderzoeksdriver, zijn bytegelijk aan ACTIVE27. Alleen de geselecteerde oorspronkelijke contexten en werkpaden verschillen. De actuele residuoperator, analytische rang-één-formule, activeringsvoorwaarden, fysieke provider, native branchdrempels, V1, MAXIT, dtgrenzen en reductieregels blijven behouden. Geen criterium is aangepast om een gewenste weigering te produceren.

## Oorspronkelijke contexten werkelijk bereikt

Iedere route begint in een vers native proces vanaf dezelfde afgesloten oorspronkelijke daggrens 35797. De aanloop gebruikt de oorspronkelijke V1/Darcy-route zonder de nieuwe kandidaat op eerdere stappen te activeren. De prefixbudgetten zijn per optimalisatie bytegelijk aan het bestaande NEXT18/DIAG19-bewijs: **1137 regels voor D1, 1309 voor D2 en 346 voor D3**. De vooraf geselecteerde t/dt-combinatie wordt op de levende host gecontroleerd. Er is geen latere toestand of headprofiel ingevoegd.

Pas op de geselecteerde context wordt de bestaande current-operator/rang-één-kandidaat aangeroepen. Dezelfde driver staat maximaal vier oorspronkelijke headpogingen toe en stopt bij een verzoek om fluxreductie; in alle huidige routes is de eerste poging al geaccepteerd. De echte hostintegratie wordt daarna uitgevoerd en de route stopt na die ene targetcommit.

## Werkelijke uitkomsten en guardaudit

| Context | Kandidaatiteraties | Extra line-searchtrials | Actieve rang-één-iteraties | Maximaal eindresidu | Somresidu |
| --- | ---: | ---: | ---: | ---: | ---: |
| D1 | 12 | 17 | 0 | 4,328019850008413e-7 | −9,311103549625745e-7 |
| D2 | 24 | 49 | 0 | 6,420525826000834e-7 | 8,489064899215716e-7 |
| D3 | 7 | 3 | 3 | 9,378662594455855e-8 | 6,162729378094536e-7 |

Alle drie voldoen aan de oorspronkelijke compartiment- en totale residucriteria en hebben een echte verse V1-controle. De fluxfactor blijft 1. Het feit dat ze eerder onder de oorspronkelijke route weigerden, wordt niet als weigering van de nieuwe kandidaat gerapporteerd. Bij D1/D2 zijn nog veel line-searchtrials nodig, maar ook D2 convergeert binnen het onveranderde maximum van 30 iteraties.

De exacte activeringsvoorwaarden zijn bij iedere Jacobiaanevaluatie getoetst aan de bijbehorende MACRORATE task-2/stage-3-records:

- D1: alle twaalf evaluaties hebben positieve potentiële domein-3-instroom. De vereiste nul-instroomvoorwaarde is dus telkens onwaar.
- D2: dezelfde uitsluiting geldt in alle 24 evaluaties.
- D3: alle zeven evaluaties hebben nul potentiële instroom. Viermaal is de minimumkeuze gelijk aan de volledige aanwezige voorraad, zodat de geselecteerde gedeeltelijke volumetak niet actief is. Driemaal voldoet de gedeeltelijke nul-instroomtak en wordt de rang-één-correctie werkelijk toegepast.

Hieruit volgt een concretere selectiegrens: veel oorspronkelijke line-searchpogingen voorspellen op zichzelf geen actieve weigering van deze kandidaat. De fysieke nul-instroom-/gedeeltelijke-voorraadtak moet afzonderlijk worden aangetoond. De kandidaat uitbreiden tot instroomtakken zou een nieuwe numerieke kandidaat zijn en is hier niet gedaan.

## O0/O2, hostcommit en tijdslimiet

| Route | O0 | O2 |
| --- | ---: | ---: |
| D1 | 6,480 s | 5,532 s |
| D2 | 6,479 s | 4,607 s |
| D3 | 1,655 s | 1,627 s |

Er zijn zes modelroutes uitgevoerd. Alle stoppen normaal, ongecensureerd en onder twintig seconden per route. Er zijn geen mislukte setupuitvoeringen of andere kandidaatvarianten in deze ronde. Alle niet-timingexports, begin-/return-/committoestanden, ledger, prefixbudgetten, node- en Jacobiaantraces zijn per context bytegelijk tussen O0/O2.

De geaccepteerde targetcommits leveren ook een inventaris binnen de oorspronkelijke geïntegreerde totale residugrens:

| Context | Inventarisafwijking, cm | Oorspronkelijke dt × CritDevBalTot, cm |
| --- | ---: | ---: |
| D1 | −2,0691340366074933e-10 | 2,222222222222222e-9 |
| D2 | 2,4010691691996305e-10 | 2,8284271247461902e-9 |
| D3 | 1,7430835011597763e-10 | 2,8284271247461902e-9 |

De inventaris gebruikt aparte begin-/eindvoorraden van matrix, vijf macrodomeinen, pond en canopy tegenover de primitieve geaccepteerde stapintegralen. Zij sluit ook aan op dt maal het geaccepteerde somresidu. Deze controles bevestigen de gemeten acceptaties; ze worden niet opgevoerd als vervanging voor een ontbrekende actieve afwijzingsproef.

## Besluit en open kwalificatie

Status is NO_QUALIFYING_ACTIVE_REFUSAL_IN_FURTHER_THREE_ORIGINAL_CONTEXTS. Er is geen geschikte context gevonden en daarom zijn geen DIRECT-routes gestart. Evenmin is een actieve rollback/directe-retry-PASS toegekend. De eerdere inactieve weigeringen uit REJECT26/ACTIVE27 vullen dit bewijs niet aan.

De uitkomst bewijst niet dat een actieve weigering nergens bestaat. Zij beschrijft alleen deze drie verdere oorspronkelijke contexten. Geen stapduur, iteratiebudget, fysieke voorraadgrens of activeringsvoorwaarde is gewijzigd om zo'n geval alsnog te maken, en de selectie is niet uitgebreid tot een brede campagne. Andere instroomtakken, algemene solvertoelating, native herstart en volledige periodebalans blijven buiten scope. De bekende IEEE_DENORMAL-instrumentatiemelding is in de ruwe uitvoer behouden.

assess_select28.py beoordeelt uitsluitend bestaande bestanden. SELECTION.json, SCOPE_REVISION.json, RESULT.json, oorspronkelijke prefix-/targetexports, guardtraces, builds en de geverifieerde SELECT28_EVIDENCE.zip bewaren de reproduceerbare negatieve selectie. Geen officiële promotie.
