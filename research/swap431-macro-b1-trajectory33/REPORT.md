# TRAJECTORY33 — één korte doorlopende kandidaattraj­ectie

**De kandidaat bereikt vanaf dezelfde oorspronkelijke native daggrens de vastgelegde tijdgrens in 63 geaccepteerde stappen, zonder afwijzing of fluxreductie.** De rang-één-aanvulling is 81 keer actief, verdeeld over 28 stappen. O0 en O2 geven exact dezelfde numerieke exports. Alle stapinventarissen en de onafhankelijke voorraadbalans over dit korte traject voldoen aan de uit de oorspronkelijke residucriteria afgeleide grenzen.

Er is geen echte actieve afwijzing gevonden. De conditionele rollback/directe-kleinere-retryvergelijking is daarom niet uitgevoerd en blijft expliciet ongekwalificeerd. Geen weigering is afgedwongen.

## Basis en vooraf vastgelegde route

Baseline is OUTSIDE32 `ac673db870237c576299ab9e0c7efaa3f1cf934b`. Remote onderzoeksbranch is daarmee gelijk; remote main blijft `be481cfb40f953e337116ef4a6dc5bc3ef64d4f7` en is niet gewijzigd of samengevoegd. Dit blijft geïsoleerd onderzoek, geen toelating van een nieuwe officiële B1-referentie.

Beide routes beginnen in een vers proces vanuit het bestaande oorspronkelijke NEXT18-native checkpoint op **t1900 = 35797**. Het gebruikte bestand is bytegelijk aan de geërfde oorspronkelijke daggrens; SHA-256 `21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16`. De volledige bestaande native ledger wordt vereist. Oorspronkelijke casebestanden en kalender-/uitvoercontext zijn behouden.

Het verschil met de vorige selectierondes is expliciet: **de huidige kandidaat is vanaf de eerste headpoging continu actief**, ook voordat een rang-één-guard waar wordt. Dit is de eigen trajectorie van de kandidaat, geen oorspronkelijke V1-aanloop met één vervangen stap.

Vóór builds en uitvoering zijn vier observatiestops vastgelegd: eerste echte actieve afwijzing, eerste gereduceerd-fluxverzoek, of na commit maximaal 512 geaccepteerde stappen / 16 seconden interne observatietijd / t1900 minstens 35797,125. Iedere modelroute heeft bovendien dezelfde harde externe twintigsecondenlimiet. Er is geen stap verkort om de tijdgrens exact te raken. In beide routes wordt uitsluitend de fysieke tijdgrens geraakt: de oorspronkelijke gebruikte dt van 0,002 dag brengt de laatste commit op **35797,126000000026**. Geen verdere horizon is geprobeerd.

## Wat de implementatie verandert

De rekenformules, actuele residuoperator, rang-één-aanvulling, activeringsguards, MAXIT, toleranties, dtkeuze en fluxreductieregels zijn ongewijzigd. Het rekenkundige verschil ten opzichte van de eerdere proefopzet is uitsluitend dat dezelfde kandidaat nu op alle heads wordt toegepast.

Vijf onderzoeksbestanden veranderen voor uitvoering en registratie:

- `soilwater_native.f90`: de bestaande doorlopende hoststappen gebruiken de kandidaat; compacte beginvoorraden worden per poging gekopieerd en na echte hostcommit met de primitieve fluxintegralen vergeleken; observatiestops en conditionele eventreplay zijn toegevoegd.
- `diag_state.f90`: scheidt kandidaatinschakeling van omvangrijke detailuitvoer, telt werkelijke activering en bewaart de observatiegrenzen.
- `head_diag.f90` en `macrorate_node.f90`: omvangrijke diagnostische exports worden afzonderlijk geschakeld. De actuele provider en de voor de Jacobiaan vereiste limitergegevens blijven berekend.
- `jac_update.f90`: integer activeringstellers en gebufferde trace-uitvoer; de analytische termen en Sherman–Morrison-berekening zijn exact behouden.

De broncontrole herleidt die wijzigingen exact. Alle overige Fortranbestanden zijn bytegelijk aan OUTSIDE32. De oorspronkelijke hosthoofdlus, SoilWater-kern, statevarfuncties, fysieke providers en native formaten zijn behouden. `diagnostic_driver.patch` en `prepare_trajectory33.py` bewaren de reproduceerbare bronwijziging. B0, B1.12, canonical en de macroporiënvrije releasebasis zijn ongewijzigd.

Bij een eerste echte afwijzing met activering zou de route de afgewezen en fysiek teruggezette toestand bewaren, met de oorspronkelijke native oorsprong, volledige primitieve kandidaataanloop en exacte poging/t/dt-coördinaten. Een conditionele TRIAL-replay reconstrueert de volledige toestand vóór de mislukte head; DIRECT herhaalt dezelfde kandidaataanloop en gaat via de oorspronkelijke TimeControl(5) rechtstreeks naar de kleinere retry. Dit pad is geïmplementeerd en gepersisteerd, maar **niet uitgevoerd of gekwalificeerd**: er trad geen afwijzing op. Er is dus ook geen nieuw zelfstandig native checkpoint vóór een afwijzing geclaimd.

## Gemeten gekoppelde convergentie

| Grootheid | O0 | O2 |
| --- | ---: | ---: |
| Normale procestijd, seconden | 0,678613 | 0,633659 |
| Geaccepteerde stappen / headpogingen | 63 / 63 | 63 / 63 |
| Echte headweigeringen | 0 | 0 |
| Stappen met actieve rang-één-aanvulling | 28 | 28 |
| Actieve rang-één-iteraties | 81 | 81 |
| Totale Newtoniteraties | 269 | 269 |
| Newtoniteraties per head | 2–8 | 2–8 |
| Extra line-searchtrials | 64 | 64 |
| Gereduceerde-fluxcommits | 0 | 0 |

Alle 63 headacceptaties hebben één verse V1-controle en voldoen aan de oorspronkelijke compartiment- en totale residucriteria. Het grootste eindresidu is 8,690116583259105e-7; de grootste absolute somresiduwaarde is 5,695392949032952e-6. Iedere gebruikte dt is 0,002 dag en iedere fluxfactor is 1.

De eerste 35 primitieve commitbudgetregels zijn bytegelijk aan het bestaande oorspronkelijke bewijs. De eerste actieve kandidaathead is poging 36, beginnend op 35797,070000000014. Haar volledige Jacobiaantrace zonder pogingnummer en commitbudget zijn exact gelijk aan de eerder afzonderlijk gekwalificeerde oorspronkelijke G1-context uit REMAINING31. Vanaf deze stap volgt de doorlopende kandidaat zijn eigen verdere toestand.

De grootste geregistreerde lineaire residuafwijking is 8,326672684688674e-17. De kleinste absolute actieve Sherman–Morrison-noemer is 4,233935980315302. Er is geen singuliere-updatefout of uitgeputte headpoging gemeld.

## Onafhankelijke waterinventaris

Iedere geaccepteerde stap vergelijkt matrix, vijf macrodomeinen, pond en canopy met de primitieve geaccepteerde uitwendige fluxintegralen. Elke fout ligt onder gebruikte dt maal het oorspronkelijke totale residucriterium. De grootste absolute stapfout is **1,139078606091082e-8 cm**, 56,954% van de bijbehorende grens van 2e-8 cm. De grootste afzonderlijke domeinintegratiefout is 2,080583968999683e-16 cm.

Een tweede controle gebruikt onafhankelijk de volledige begin-/eindvoorraden tegenover de opgetelde primitieve stapintegralen over **0,126 dag**:

| Grootheid | Waarde, cm |
| --- | ---: |
| Totale voorraadverandering | −0,06112571502914517 |
| Geïntegreerde uitwendige toevoer minus afvoer | −0,06112576086027827 |
| Inventarisafwijking | 4,583113310391296e-8 |
| Som van dt × oorspronkelijk totaal residucriterium | 1,26e-6 |

De totale afwijking stemt binnen afronding overeen met de som van de stapfouten en de geïntegreerde geaccepteerde somresiduen. Dit is een inventariskwalificatie van het gemeten korte traject. Het is geen volledige balansperiode of dagelijkse BAL-uitvoerkwalificatie. De initiële ledgerdump ligt vóór de eerste hostreset en wordt hier niet als lokale nulbasis afgetrokken; de trajectbalans gebruikt de fysieke begin-/eindvoorraden en primitieve fluxen.

## Praktische voortgang tegenover bestaand oorspronkelijk bewijs

Voor de vooraf vastgelegde stopdrempel 35797,125 kan de reeds beschikbare oorspronkelijke route worden gelezen zonder nieuwe uitvoering:

| Tot eerste commit over dezelfde drempel | Oorspronkelijk bewijs | Kandidaat |
| --- | ---: | ---: |
| Geaccepteerde commits | 383 | 63 |
| Headpogingen | 816 | 63 |
| Headweigeringen | 433 | 0 |
| Gereduceerde-fluxcommits | 78 | 0 |
| Werkelijke eerste commit over drempel | 35797,1252379984 | 35797,126000000026 |

Dit ondersteunt concrete voortgang voor dit korte interval. Eindtijdstippen en fysieke trajecten verschillen: de oorspronkelijke route bevat fluxreductie, de kandidaat niet. De tabel bewijst geen fysische gelijkheid, volledige periodekwaliteit, runtimeversnellingsfactor of draagbare performancegarantie. Beide routes volgen hun eigen oorspronkelijke dtregels; geen tijdstap is voor vergelijking aangepast.

## Besluit en resterende uitsluitingen

Status: `PASS_BOUNDED_OWN_CANDIDATE_TRAJECTORY_WITH_ACTIVE_REFUSAL_EXCLUSION`. De eigen korte kandidaattraj­ectie is daadwerkelijk uitgevoerd en voorraadgekwalificeerd met O0/O2. Alle niet-timingtekstexports en attemptvelden zonder rekentijd zijn bytegelijk. Beide processen eindigen normaal, ongecensureerd en binnen twintig seconden. De bekende IEEE_DENORMAL-melding is in beide ruwe uitvoerbestanden behouden; volledige IEEE-statusidentiteit is niet geclaimd.

Er is geen afwijzing opgetreden. Daarom zijn geen aanvullende TRIAL/DIRECT-routes gestart en is geen actieve rollback/directe-retry-PASS toegekend. Dit ontbrekende bewijs blijft een uitsluiting, geen aangetoonde rollbackfout. Er wordt niet beweerd dat actieve weigeringen nergens bestaan.

B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`. Een volledige periode, native herstart van deze eigen trajectorie en algemene solvertoelating blijven buiten deze ronde. De vastgelegde observatiegrens is niet uitgebreid omdat de route snel eindigde. Geen brede campagne of geforceerde weigering.

RESULT, STATUS, TRACE_FIELDS, ruwe exports, bron-/buildidentiteiten en de geverifieerde TRAJECTORY33_EVIDENCE.zip bewaren de volledige reproduceerbare closure. `assess_trajectory33.py` beoordeelt uitsluitend bestaande bestanden; er worden daarbij geen modellen uitgevoerd. Geen officiële promotie.
