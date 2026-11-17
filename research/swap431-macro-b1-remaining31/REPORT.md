# REMAINING31 — vijf resterende oorspronkelijke begincontexten

**Alle vijf resterende oorspronkelijke nulinstroomcontexten met direct gedeeltelijke minimumvoorraadbegrenzing zijn met O0/O2 getoetst. De ongewijzigde kandidaat accepteert ze alle vijf in twee iteraties, met de rang-één-aanvulling in beide iteraties actief.** Er is geen echte actieve afwijzing. Rollback en directe kleinere retry blijven ongekwalificeerd.

Daarmee is de eindige verzameling uit INITIAL30 afgewerkt: de zeven daar als nieuw geschikt geïdentificeerde oorspronkelijke contexten zijn nu allemaal met de kandidaat onderzocht; geen ervan levert de gezochte actieve weigering. Dit is geen uitspraak over alle oorspronkelijke contexten buiten die verzameling.

## Onderzoeksbasis en begrenzing

Basis: INITIAL30 `825ca77494b73e3fce34f9e2034d81c395b15552`. De remote onderzoeksbranch en HEAD zijn daarmee gelijk. Remote main is ongewijzigd `be481cfb40f953e337116ef4a6dc5bc3ef64d4f7`; geen canonical merge of promotie.

Alle kandidaat-Fortranbronnen, inclusief driver, zijn bytegelijk aan INITIAL30. Alleen werkpaden en geselecteerde oorspronkelijke t/dt-combinaties verschillen. Fysica, actuele residuoperator, analytische rang-één-formule, guards, MAXIT, toleranties, dtgrenzen en reductieregels zijn behouden. De oorspronkelijke B0-code, officiële B1.12, canonical en macroporiënvrije releasebasis zijn niet gewijzigd.

Vooraf is uitsluitend de eindige resterende verzameling 36, 40, 41, 43, 46 vastgelegd, in oorspronkelijke volgorde, maximaal vijf contexten en maximaal vier oorspronkelijke headpogingen per targetroute. Geen extra observer, broncampagne, nieuwe context of parameterzoektocht. De selectielijst en bronpostimage zijn vóór bouwen en uitvoeren in git vastgelegd. Alle modelprocessen hebben dezelfde harde twintigsecondenlimiet en stoppen na de eerste targethostcommit of bij een gereduceerd-fluxverzoek.

De oorspronkelijke eerste-evaluatiebewijzen worden geërfd uit het geverifieerde INITIAL30-archief SHA-256 `69e8e0512bcf544a3d830acaba8642289cae74fe4b6edc4d5d1a12b6d18c861c`; de observerroute is niet herhaald.

## Geselecteerde oorspronkelijke contexten

| Context | Oorspronkelijke poging | Begin t1900 | Oorspronkelijke dt, dag | Prefixcommits | Beginuitstroomfactor |
| --- | ---: | ---: | ---: | ---: | ---: |
| G1 | 36 | 35797.07000000001426 | 0.002 | 35 | 0.4514580654416016 |
| G2 | 40 | 35797.07111111112317 | 0.0008888888888888888 | 37 | 0.1042981343509576 |
| G3 | 41 | 35797.07111111112317 | 0.0002962962962962963 | 37 | 0.3128944030531811 |
| G4 | 43 | 35797.07120987655799 | 0.0001975308641975309 | 38 | 0.1857351415714166 |
| G5 | 46 | 35797.07123182443320 | 4.38957475994513e-05 | 39 | 0.5603083691168553 |

Alle vijf oorspronkelijke pogingen weigerden werkelijk na 30 iteraties met grootste residunode 52. Dat historische feit telt niet als afwijzing van de huidige kandidaat. G2/G3 delen dezelfde oorspronkelijke gecommitteerde toestand en verschillen in oorspronkelijke dt; beide zijn zelfstandige kandidaatproeven. Hun acceptaties vormen geen afwijzing-plus-retry-proef.

Iedere route begint in een nieuw native proces vanaf dezelfde oorspronkelijke afgesloten daggrens 35797. Tot de geselecteerde levende t/dt-combinatie wordt de oorspronkelijke route gebruikt. De prefixbudgetten van 35/37/37/38/39 regels zijn per optimalisatie bytegelijk aan de oorspronkelijke NEXT18-bewijzen. Er zijn geen latere headprofielen ingevoegd.

De fysieke velden van iedere eerste MACRORATE task-1/stage-3-evaluatie zijn exact gelijk aan de bijbehorende oorspronkelijke INITIAL30-observerrecord, zowel bij O0 als O2. Direct geldt potentiële instroom 0, minimumvoorraad kleiner dan aanwezige voorraad en uitstroomfactor strikt tussen 0 en 1, met de oorspronkelijke overschrijdingsdrempel en GWL-bracket 50. Die gedeeltelijke nulinstroomtak blijft bij alle tien Jacobiaanevaluaties per optimalisatie actief. De rang-één-aanvulling wordt telkens werkelijk toegepast.

## Acceptaties en waterinventaris

Alle vijf kandidaatpogingen convergeren in **twee iteraties**, zonder extra line-searchtrials, zonder fluxreductie en met één verse V1-controle. De eerste headpoging wordt geaccepteerd; daarna volgt één echte hostcommit. De oorspronkelijke compartiment- en totale residucriteria zijn gehaald.

| Context | Maximaal eindresidu | Somresidu | Inventarisafwijking, cm | Oorspronkelijke dt × CritDevBalTot, cm |
| --- | ---: | ---: | ---: | ---: |
| G1 | 3.938158410488e-10 | -1.859657668971e-10 | -3.717921153237e-13 | 2.000000000000e-08 |
| G2 | 7.316583727768e-10 | 5.399493738115e-11 | 4.807265696627e-14 | 8.888888888889e-09 |
| G3 | 3.781532031955e-11 | 3.183722919524e-11 | 9.354523449259e-15 | 2.962962962963e-09 |
| G4 | 3.329787834350e-11 | 3.602812207307e-11 | 7.030956220878e-15 | 1.975308641975e-09 |
| G5 | 3.476996468521e-12 | -6.056442237255e-12 | -1.395232670717e-16 | 4.389574759945e-10 |

De onafhankelijke waterinventaris gebruikt aparte begin-/eindvoorraden van matrix, vijf macrodomeinen, pond en canopy tegenover de primitieve geaccepteerde stapintegralen. Zij blijft binnen de oorspronkelijke geïntegreerde totale residugrens en sluit ook aan op dt maal het somresidu. Daarnaast zijn de vijf afzonderlijke domeinintegralen en de hostcumulatieven gecontroleerd; de maximale absolute domeinafwijking is 1.382230714977e-16 cm. Dit is een stapkwalificatie, geen volledige periodebalans.

## O0/O2 en twintigsecondenlimiet

| Context | O0, seconden | O2, seconden |
| --- | ---: | ---: |
| G1 | 1.070424 | 0.586287 |
| G2 | 0.478266 | 0.545388 |
| G3 | 0.493958 | 0.514858 |
| G4 | 0.512183 | 0.457469 |
| G5 | 0.475428 | 0.511513 |

Alle tien routes stoppen normaal en ongecensureerd. Maximum is 1.070424 seconde, ruim binnen de bestaande twintigsecondenlimiet. Alle niet-timingtekstexports en attemptvelden zonder rekentijd zijn bytegelijk tussen O0/O2. Bronidentiteiten en kandidaatgelijkheid aan INITIAL30 zijn gecontroleerd. Geen extra modelvarianten of mislukte setupuitvoeringen.

De ruwe IEEE_DENORMAL-melding staat in acht van de tien procesuitvoeren; O0/G1 en O0/G5 hebben haar niet. Er wordt geen volledige IEEE-statusidentiteit geclaimd.

## Besluit en open kwalificatie

Status: `FINITE_INITIAL30_POOL_EXHAUSTED_NO_ACTIVE_REFUSAL`. Binnen deze afgebakende verzameling van zeven nieuwe oorspronkelijke begincontexten is de kandidaat met actieve rang-één-aanvulling steeds geaccepteerd: INITIAL30 toetste 44 en 48, deze ronde de vijf overblijvers. Er resteert geen ongetoetste context uit die lijst.

Daarom zijn geen DIRECT-routes gestart en is geen actieve rollback/directe-retry-PASS toegekend. Eerdere inactieve kandidaatweigeringen uit REJECT26/ACTIVE27 vervangen dat bewijs niet. Ook historische oorspronkelijke weigeringen en het delen van een begincontext bewijzen geen afwijzing van de nieuwe kandidaat.

B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`. Lokale ongereduceerde acceptatie, hostinventaris en O0/O2-gelijkheid zijn voor deze vijf bevestigd. Actieve afwijzing met herstel en directe kleinere retry, algemene solvertoelating, eigen herstart en volledige periodekwalificatie worden hiermee niet toegelaten. Dit onderzoek is evenmin een geïsoleerde causaliteitsproef voor alleen de Jacobiaanwijziging: de actuele residuoperator is ook onderdeel van de kandidaat.

Deze eindige contextverzameling kan de nog ontbrekende afwijzingsgetuige niet leveren. Zij opnieuw selecteren heeft voor die vraag geen onderscheidende waarde. Een eventuele volgende selectie vereist ander oorspronkelijk toestandbewijs en een nieuwe concrete afbakening. Die uitbreiding is hier niet gestart; er is geen weigering afgedwongen, fysieke correctie ingevoerd of brede campagne uitgevoerd.

`assess_remaining31.py` controleert uitsluitend bestaande bestanden, inclusief de exacte resterende verzameling, geërfd bewijs, beginbegrenzing, werkelijke activering, hostinventaris en O0/O2-vergelijking. STATUS, SELECTION, RESULT, TRACE_FIELDS, ruwe exports, builds en de geverifieerde REMAINING31_EVIDENCE.zip bewaren de reproduceerbare bron-/compile-/link-/uitvoerclosure. Geen officiële promotie.
