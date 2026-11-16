# ZERO29 — nulinstroom en gedeeltelijke minimumvoorraadgrens

**De bedoelde fysische context is aangetoond, ook direct bij het begin van een oorspronkelijke stap. Een echte afwijzing met actieve rang-één-aanvulling is opnieuw niet gevonden.** De drie kandidaatpogingen convergeren in 5, 9 en 1 iteraties. Daarmee blijft de gevraagde kwalificatie van actieve afwijzing, rollback en directe kleinere retry open.

## Selectie en grenzen

Baseline is SELECT28 `74b2482f9af8488e64f1800683d28b4f8c1cc320`. Alle Fortranbronnen, inclusief onderzoeksdriver, zijn bytegelijk aan die baseline. De actuele residuoperator en analytische rang-één-aanvulling zijn behouden; fysica, activeringsvoorwaarden, tolerantie, MAXIT, dt en reductieregels zijn ongewijzigd. Alleen oorspronkelijke contexten en werkpaden verschillen.

E1/E2 zijn vooraf gekozen oorspronkelijke node-52-afwijzingen binnen de reeds bekende nulinstroomfase. Beide blijken pas tijdens de kandidaatiteratie gedeeltelijk begrensd. Daarom is vóór uitvoering één laatste context E3 toegevoegd: oorspronkelijke poging 50, waarvan het bestaande LIMIT21-bewijs al bij de eerste evaluatie nulinstroom en gedeeltelijke begrenzing toont. De uitbreiding van maximaal twee naar maximaal drie contexten is vóór E3 in SCOPE_REVISION.json en git vastgelegd. Er zijn geen verdere selecties of parametervarianten uitgevoerd.

| Context | Oorspronkelijke poging | Begin t1900 | Oorspronkelijke dt, dag | Prefixcommits |
| --- | ---: | ---: | ---: | ---: |
| E1 | 54 | 35797,071680720415 | 0,000282842712474619 | 43 |
| E2 | 279 | 35797,086412990247 | 0,000020951312035156963 | 141 |
| E3 | 50 | 35797,071256456351 | 0,000020000000000000000 | 41 |

Alle drie zijn onder de oorspronkelijke route werkelijk na 30 iteraties afgewezen, met grootste residunode 52. Dat historische feit geldt niet als afwijzing van de huidige kandidaat.

Iedere route begint in een nieuw native proces op dezelfde oorspronkelijke afgesloten daggrens 35797. De oorspronkelijke route wordt tot de geselecteerde levende t/dt-combinatie gebruikt. De 43/141/41 prefixbudgetregels zijn per optimalisatie bytegelijk aan NEXT18/DIAG19. Er zijn geen latere headprofielen ingevoegd. Op de geselecteerde stap wordt de bestaande kandidaat geactiveerd; na de eerste echte hostcommit stopt de route. De driver laat maximaal vier oorspronkelijke pogingen toe en stopt bij een fluxreductieverzoek.

## Nulinstroom en werkelijke activering

De audit vergelijkt iedere Jacobiaanevaluatie met de bijbehorende MACRORATE task-2/stage-3-records. Alle evaluaties hebben exact nul potentiële domein-3-instroom. Gedeeltelijke activering vereist tevens `L < W`, `0 < factor < 1`, de oorspronkelijke overschrijdingsdrempel en het bestaande GWL-bracket.

| Context | Direct gedeeltelijk begrensd | Kandidaatiteraties | Actieve rang-één-iteraties | Extra line-searchtrials |
| --- | --- | ---: | ---: | ---: |
| E1 | Nee | 5 | 2 | 1 |
| E2 | Nee | 9 | 3 | 9 |
| E3 | Ja | 1 | 1 | 0 |

E1 heeft eerst tweemaal minimumvoorraad gelijk aan de volledige voorraad en eenmaal geen actieve uitstroombegenzing; daarna is de gedeeltelijke tak tweemaal actief. E2 heeft vijf volledig begrensde evaluaties, eenmaal geen actieve begrenzing en driemaal de gedeeltelijke tak. E3 voldoet meteen aan de bedoelde gedeeltelijke nulinstroomtak.

De eerste E3-evaluatie is bovendien numeriek exact vergeleken met de bestaande eerste LIMIT21-evaluatie van oorspronkelijke poging 50: instroom 0, aanwezige domeinvoorraad **0,035366756154482683 cm**, minimumvoorraad **0,035366508152967047 cm**, uitstroombegenzingsfactor **0,33490280233057534**. Ook dt, GWL, potentiële uitstroom en overschrijding stemmen exact overeen. De rang-één-aanvulling is actief; de kandidaat convergeert in één iteratie. Dit is een kwalificatie van de geselecteerde fysieke tak, geen geïsoleerde causaliteitsproef voor alleen de Jacobiaanwijziging.

## Acceptatie, inventaris en O0/O2

| Context | Maximaal eindresidu | Somresidu | Inventarisafwijking, cm | Oorspronkelijke dt × CritDevBalTot, cm |
| --- | ---: | ---: | ---: | ---: |
| E1 | 2,372910895553915e-12 | 8,019698066496397e-12 | 2,264383342290288e-15 | 2,828427124746190e-9 |
| E2 | 3,952243118766213e-7 | 2,586862038273208e-6 | 5,419812877811012e-11 | 2,095131203515697e-10 |
| E3 | 7,263872463664223e-7 | 8,990110694422397e-7 | 1,798014588236772e-11 | 2,000000000000000e-10 |

Alle drie voldoen aan de oorspronkelijke compartiment- en totale residucriteria, met één verse V1-controle en fluxfactor 1. De onafhankelijke waterinventaris gebruikt matrix, vijf macrodomeinen, pond en canopy tegenover de primitieve geaccepteerde stapintegralen; zij sluit ook aan op dt maal het somresidu. Dit bevestigt de gemeten acceptaties.

| Route | O0, seconden | O2, seconden |
| --- | ---: | ---: |
| E1 | 0,892006 | 0,907388 |
| E2 | 1,262987 | 1,070220 |
| E3 | 0,593244 | 0,744350 |

Alle zes modelroutes stoppen normaal en ongecensureerd binnen de harde twintigsecondenlimiet. Alle niet-timingtekstexports en de attemptvelden zonder rekentijd zijn bytegelijk tussen O0/O2. De bronidentiteiten zijn gecontroleerd. De bekende IEEE_DENORMAL-melding is in de ruwe uitvoer behouden; deze ronde kwalificeert niet de volledige IEEE-status van het programma.

## Besluit

Status: `ZERO_INFLOW_PARTIAL_CONTEXTS_CONFIRMED_BUT_NO_GENUINE_REFUSAL`. De selectie voldoet aan de gevraagde fysieke nulinstroom-/gedeeltelijke-minimumvoorraadvoorwaarde, voor E3 al vanaf het begin. De kandidaat accepteert echter alle drie contexten bij de eerste poging. Daarom zijn geen DIRECT-routes gestart en is geen actieve rollback/directe-retry-PASS toegekend. De eerdere inactieve afwijzingsproeven vervangen dit ontbrekende bewijs niet.

Dit bewijst niet dat een actieve afwijzing nergens bestaat. Er is geen weigering afgedwongen en geen brede campagne gestart. Algemene solvertoelating, eigen herstart, vervolgstep en volledige periodebalans worden hiermee niet gepromoveerd.

`assess_zero29.py` controleert uitsluitend bestaande bewijzen. SELECTION, SCOPE_REVISION, STATUS, RESULT, ruwe traces, builds en de geverifieerde ZERO29_EVIDENCE.zip bewaren selectie, scopewijziging en uitkomst. Geen officiële promotie.
