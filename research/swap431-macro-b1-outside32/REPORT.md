# OUTSIDE32 — gerichte oorspronkelijke contexten buiten INITIAL30

**Twee nieuwe oorspronkelijke contexten buiten INITIAL30 zijn met O0/O2 getoetst. De rang-één-aanvulling wordt tijdens de gekoppelde iteratie werkelijk actief, maar beide kandidaten accepteren de eerste poging.** Oorspronkelijke poging 620 convergeert in zes iteraties, met drie actieve aanvullingen; poging 610 convergeert in twee iteraties, met één actieve aanvulling. Er is geen actieve afwijzing gevonden. Rollback en directe kleinere retry blijven ongekwalificeerd.

De nieuwe contexten beginnen met nulinstroom en minimumvoorraad gelijk aan de aanwezige voorraad. Een direct gedeeltelijk begrensde start is in dit venster niet gevonden en wordt niet als gekwalificeerd gerapporteerd.

## Basis, observatie en expliciete selectiewijziging

Baseline is REMAINING31 `550d6ef1ce5be3cf0d9188ad976795ccdbfe5078`; remote onderzoeksbranch is gelijk. Remote main blijft `be481cfb40f953e337116ef4a6dc5bc3ef64d4f7` en is niet samengevoegd of gewijzigd.

Alle kandidaat-Fortranbronnen, inclusief onderzoeksdriver, zijn bytegelijk aan REMAINING31. Fysica, actuele residuoperator, analytische rang-één-formule, activeringsvoorwaarden, MAXIT, toleranties, dtgrenzen en reductieregels zijn behouden. De B0-bronnen, officiële B1.12, canonical en macroporiënvrije releasebasis blijven beschermd.

Vooraf is één korte oorspronkelijke observerroute vastgelegd met een exact observatievenster: oorspronkelijke pogingen **580–660**, rond de eerder bewezen latere activering bij poging 624. Alleen de 81 eerste MACRORATE-evaluaties in dat venster worden geregistreerd. Tot het venster wordt uitsluitend de vereiste oorspronkelijke aanloop uitgevoerd. Een afzonderlijke observerbuild gebruikt de oorspronkelijke headroute, met kandidaat uit, geen extra provideraanroepen, alleen diagnostische scratchregistratie en een begrensde stop. De volledige observerbronnen en `observer_only.patch` bewaren de verschillen.

De observer reproduceert **660 oorspronkelijke pogingen**, gelijk aan DIAG19 afgezien van diagnostische stapteller en rekentijd, en **312 geaccepteerde primitieve budgetregels**, bytegelijk aan NEXT18. Rekentijd: 1,231826 seconde. Van de 81 geobserveerde begincontexten zijn 37 nog niet kandidaatgetoetste oorspronkelijke afwijzingen met dt groter dan dtmin en ongereduceerde fluxen. Alle 37 hebben nul potentiële instroom en `L=W`. Geen daarvan voldoet aan de aanvankelijk vooraf vastgelegde strikte beginvoorwaarde `L<W`.

Die negatieve selectie is intact opgeslagen in OBSERVER_AUDIT.json. Vóór kandidaatuitvoering is vervolgens een expliciete selectiewijziging vastgelegd in SCOPE_REVISION.json en git. De actuele opdracht richt zich op echte actieve afwijzing; een volledig begrensde start sluit latere activering niet uit, zoals al bij ACTIVE27/poging 624 was aangetoond. Daarom worden binnen **hetzelfde venster en hetzelfde maximum van twee nieuwe contexten** twee oorspronkelijke nulinstroomafwijzingen op latere werkelijke activering getoetst. Dit wijzigt de contextselectie, niet de fysische of numerieke activeringsguard. Er wordt geen beginvoorwaarde versoepeld binnen de kandidaat en er wordt geen direct-gedeeltelijke-start-PASS toegekend.

De eerste keuze is de nieuwe oorspronkelijke afwijzing met de meeste extra line-searchtrials: poging 620, met veertien. De tweede keuze is de nog niet getoetste afwijzing met een andere grootste residunode, bij een andere gecommitteerde toestand: poging 610, node 57. De criteria en keuzes zijn vóór de vier O0/O2-kandidaatroutes vastgelegd. Het venster of maximum is daarna niet uitgebreid.

## Oorspronkelijke contexten werkelijk bereikt

| Context | Oorspronkelijke poging | Begin t1900 | Oorspronkelijke dt, dag | Prefixcommits | Oude grootste residunode | Oude extra line-searchtrials |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| H1 | 620 | 35797,111599169977 | 0,000010475656017578482 | 294 | 52 | 14 |
| H2 | 610 | 35797,110882063200 | 0,000010475656017578482 | 290 | 57 | 0 |

Beide oorspronkelijke pogingen weigerden daadwerkelijk na 30 iteraties. Dat historische feit telt niet als afwijzing van de kandidaat. Iedere route begint in een vers native proces vanaf dezelfde oorspronkelijke afgesloten daggrens 35797 en gebruikt de oorspronkelijke route tot de levende geselecteerde t/dt-combinatie. De 294/290 prefixbudgetregels zijn per optimalisatie bytegelijk aan de bestaande oorspronkelijke bewijzen. Er is geen later headprofiel ingevoegd.

De fysieke velden van de eerste MACRORATE task-1/stage-3-evaluaties zijn exact gelijk tussen oorspronkelijke observer en O0/O2-kandidaat. Beide hebben instroom 0 en `L=W`: H1 0,03540518255578187 cm, H2 0,035404494902740946 cm. Hun uitstroomfactoren van ongeveer 7,49e-12 en 3,66e-12 ontstaan door voorraadsubtractie en worden niet ten onrechte als gedeeltelijk actieve volumetak geclassificeerd.

## Werkelijke activering en acceptatie

| Context | Kandidaatiteraties | Rang-één-actieve iteraties | Extra line-searchtrials | Maximaal eindresidu | Somresidu |
| --- | ---: | ---: | ---: | ---: | ---: |
| H1 | 6 | 3 | 0 | 5,077354220221764e-7 | 3,332741449983268e-6 |
| H2 | 2 | 1 | 0 | 7,639036420196976e-7 | 5,008359645791377e-6 |

H1 heeft eerst een volledig begrensde evaluatie, daarna een onbegrensde en opnieuw een volledig begrensde. Iteraties 4–6 voldoen aan de gedeeltelijke nulinstroomtak: uitstroomfactoren 0,8888724028357443, 0,02485272840019226 en 0,026495385829451767. De rang-één-aanvulling is daar actief. H2 begint volledig begrensd en activeert de aanvulling op iteratie 2 met factor 0,05339808399303991. De guardaudit gebruikt de werkelijke bijbehorende MACRORATE task-2/stage-3-records, niet alleen een historisch afwijzingslabel.

Alle vier kandidaatroutes accepteren de eerste headpoging met fluxfactor 1, één verse V1-controle en de oorspronkelijke compartiment- en totale residucriteria. Daarna volgt één echte hostcommit; geen vervolgstep.

| Context | Onafhankelijke inventarisafwijking, cm | Oorspronkelijke dt × CritDevBalTot, cm |
| --- | ---: | ---: |
| H1 | 3,491254221163568e-11 | 1,047565601757848e-10 |
| H2 | 5,246588358670578e-11 | 1,047565601757848e-10 |

De inventaris omvat matrix, vijf macrodomeinen, pond en canopy tegenover de primitieve geaccepteerde stapintegralen. Zij ligt binnen de oorspronkelijke grens en sluit aan op dt maal het somresidu. Afzonderlijke domeinintegralen en hostcumulatieven zijn eveneens gecontroleerd. Geen volledige periodebalansclaim.

## O0/O2 en begrensde rekentijd

| Kandidaatroute | O0, seconden | O2, seconden |
| --- | ---: | ---: |
| H1 | 1,576433 | 1,192740 |
| H2 | 1,450904 | 1,283712 |

Alle vijf modelroutes inclusief observer stoppen normaal en ongecensureerd, maximaal 1,576433 seconde binnen de twintigsecondenlimiet. Alle niet-timingtekstexports en attemptvelden zonder rekentijd zijn bytegelijk tussen O0/O2. Bronidentiteiten en kandidaatgelijkheid zijn gecontroleerd. Er zijn geen extra modelvarianten, setupmislukkingen of DIRECT-routes. IEEE_DENORMAL is in alle vijf ruwe procesuitvoeren behouden; volledige IEEE-statusidentiteit wordt niet gekwalificeerd.

## Besluit en open bewijs

Status: `LATER_ACTIVATION_CONFIRMED_IN_TWO_NEW_CONTEXTS_NO_ACTIVE_REFUSAL`. De selectie buiten INITIAL30 toont twee verdere contexten met daadwerkelijke latere activering. Beide convergeren ongereduceerd; een echte actieve afwijzing ontbreekt. Daarom is geen actieve rollback/directe-retry-PASS toegekend en zijn geen DIRECT-routes uitgevoerd. Eerdere inactieve kandidaatweigeringen vullen dat bewijs niet aan.

B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`. De gemeten lokale acceptatie, inventaris en O0/O2-gelijkheid zijn bevestigd. De strikte gedeeltelijke beginvoorwaarde is hier niet gekwalificeerd. Actieve afwijzing met herstel en directe kleinere retry, algemene solvertoelating, eigen herstart en volledige periodekwalificatie blijven open. Dit is ook geen geïsoleerde causaliteitsproef voor uitsluitend de Jacobiaanformule; de actuele operator is onderdeel van de kandidaat.

De uitkomst bewijst niet dat actieve weigeringen nergens bestaan en kwalificeert niet alle 37 oorspronkelijke afwijzingen in het venster als kandidaatacceptatie. Slechts de twee geselecteerde kandidaatcontexten zijn getest. Verdere contexten, andere vensters, instellingen of fysische correcties zijn niet geprobeerd. Geen brede campagne of geforceerde weigering.

`assess_outside32.py` controleert uitsluitend bestaande bewijzen en herleidt observeridentiteit, selectiewijziging, exacte contextkeuze, daadwerkelijke activering, inventaris en O0/O2-vergelijking. STATUS, SELECTION, SCOPE_REVISION, OBSERVER_AUDIT, RESULT, tracevelden, bronnen, builds en de geverifieerde OUTSIDE32_EVIDENCE.zip bewaren beide compile/link-closures en alle ruwe routes. Geen officiële promotie.
