# INITIAL30 — verdere selectie met gedeeltelijke begrenzing vanaf stapbegin

**Twee nieuwe oorspronkelijke contexten voldoen direct bij de eerste evaluatie aan nulinstroom en gedeeltelijke minimumvoorraadbegrenzing. Beide worden door de bestaande kandidaat geaccepteerd, in twee respectievelijk één iteratie.** De rang-één-aanvulling is in alle kandidaatiteraties actief. Een actieve afwijzing is niet gevonden; rollback en directe kleinere retry blijven daardoor ongekwalificeerd.

## Basis en vooraf begrensde selectie

Onderzoeksbasis: ZERO29 `5ec00670ef095d9e11b1ecad77c7b5adae48680c`. De remote onderzoeksbranch is daarmee gelijk. De tijdens deze ronde vastgestelde remote main is `be481cfb40f953e337116ef4a6dc5bc3ef64d4f7`; deze wordt niet gewijzigd of samengevoegd. De kandidaat blijft geïsoleerd onderzoek en wordt niet canoniek toegelaten.

Alle kandidaat-Fortranbronnen, inclusief driver, zijn bytegelijk aan ZERO29. Er is geen wijziging van fysica, actuele residuoperator, rang-één-formule, activeringsvoorwaarden, MAXIT, toleranties, dtgrenzen of fluxreductieregels.

De bestaande eerste-evaluatiebewijzen bevatten voor deze vervolgselectie geen nieuwe geschikte afwijzingscontext. Daarom is vóór uitvoering één observatieroute vastgelegd: de oorspronkelijke native route vanaf daggrens 35797 tot en met oorspronkelijke poging 279. Die ligt geheel binnen de al bekende korte aanloop. Een aparte observerbuild registreert uitsluitend de reeds uitgevoerde eerste MACRORATE-evaluatie van iedere oorspronkelijke poging, zonder extra provideraanroepen. De kandidaat staat hier uit. Alleen de onderzoeksdriver, de begrensde stop en de tracegates verschillen, vastgelegd in `observer_only.patch` en de volledige observerbronnen.

Vooraf vastgelegd maximum: **twee nieuwe kandidaatcontexten**, zonder latere uitbreiding. Selectieregel: alleen nog niet getoetste oorspronkelijke weigeringen met dt groter dan dtmin, ongereduceerde fluxen en de volledige gedeeltelijke-nulinstroomguard. Eerst het grootste oorspronkelijke aantal extra line-searchtrials, bij gelijkstand de vroegste poging; daarna de kleinste geschikte dt bij een andere oorspronkelijke gecommitteerde toestand.

De observatieroute levert 279 eerste-evaluatierecords. Alle 279 headpogingen zijn gelijk aan DIAG19, afgezien van diagnostische stapteller en tijdmeting; alle **141 primitieve geaccepteerde prefixbudgetregels zijn bytegelijk** aan NEXT18. De route duurt 0,632018 seconde. Er worden zeven nieuwe geschikte oorspronkelijke weigeringen vastgesteld: 36, 40, 41, 43, 44, 46 en 48. De vooraf vastgelegde regel kiest uitsluitend 44 en 48. De overige vijf zijn hier niet met de kandidaat getoetst en gelden niet als bewezen kandidaatweigering.

## Direct gedeeltelijk begrensde begincontexten

| Context | Oorspronkelijke poging | Begin t1900 | Oorspronkelijke dt, dag | Prefixcommits |
| --- | ---: | ---: | ---: | ---: |
| F1 | 44 | 35797,071209876558 | 0,000065843621399176946 | 38 |
| F2 | 48 | 35797,071246456348 | 0,000029263831732967531 | 40 |

Beide oorspronkelijke pogingen weigerden na 30 iteraties met grootste residunode 52 en acht extra line-searchtrials. Iedere kandidaatroute gebruikt de oorspronkelijke native aanloop tot de levende geselecteerde t/dt-combinatie; de 38/40 prefixbudgetregels zijn per optimalisatie exact gelijk aan de bestaande oorspronkelijke bewijzen. De oude weigeringen worden niet als weigering van de kandidaat geteld.

| Beginvoorwaarde, domein 3 | F1 | F2 |
| --- | ---: | ---: |
| Potentiële instroom | 0 | 0 |
| Voorraad W, cm | 0,035368481404832383 | 0,035367126456962390 |
| Minimumvoorraad L, cm | 0,035367122437359198 | 0,035366601134685469 |
| Uitstroomfactor | 0,55720542471497958 | 0,48478223390606578 |
| Matrix-GWL, cm | −65,319190726167946 | −65,319307624343267 |

Voor beide geldt meteen `I=0`, `L<W` en `0<factor<1`, met de oorspronkelijke overschrijdingsdrempel en GWL-bracket 50. Alle fysieke velden van de eerste MACRORATE task-1/stage-3-records stemmen exact overeen tussen oorspronkelijke observer en O0/O2-kandidaat. De daaropvolgende Jacobiaanevaluaties hebben dezelfde gedeeltelijke nulinstroomguard en passen de rang-één-aanvulling werkelijk toe.

## Gemeten kandidaatuitkomsten

| Context | Iteraties | Rang-één actief | Extra line-searchtrials | Maximaal eindresidu | Somresidu |
| --- | ---: | ---: | ---: | ---: | ---: |
| F1 | 2 | 2 | 0 | 2,601141524394279e-12 | 1,074335290357894e-11 |
| F2 | 1 | 1 | 0 | 9,521769914200284e-7 | 1,566189591804529e-6 |

Alle vier kandidaatmodelroutes accepteren de eerste kandidaatpoging, met fluxfactor 1 en één verse V1-controle. De oorspronkelijke compartiment- en totale residucriteria zijn gehaald. Daarna volgt één echte hostcommit; geen vervolgstep.

| Context | Inventarisafwijking, cm | Oorspronkelijke dt × CritDevBalTot, cm |
| --- | ---: | ---: |
| F1 | 6,253136029810147e-16 | 6,584362139917696e-10 |
| F2 | 4,583276371817636e-11 | 2,926383173296753e-10 |

De onafhankelijke inventaris omvat matrix, vijf macrodomeinen, pond en canopy tegenover de primitieve geaccepteerde stapintegralen; zij sluit ook aan op dt maal het somresidu. De resultaten blijven binnen de oorspronkelijke grens.

| Kandidaatroute | O0, seconden | O2, seconden |
| --- | ---: | ---: |
| F1 | 0,378066 | 0,823023 |
| F2 | 0,348680 | 0,401002 |

Alle niet-timingtekstexports en attemptvelden zonder tijdmeting zijn tussen O0/O2 bytegelijk. Bronidentiteiten en kandidaatgelijkheid aan ZERO29 zijn gecontroleerd. Alle vijf modelprocessen, inclusief observer, stoppen normaal en ongecensureerd, binnen twintig seconden. Er zijn geen extra modelvarianten, setupmislukkingen of DIRECT-routes. De IEEE_DENORMAL-melding komt in vier ruwe procesuitvoeren voor, niet in O0/F2; volledige IEEE-statusidentiteit is niet gekwalificeerd en wordt niet geclaimd.

## Besluit en open bewijs

Status: `STRICT_INITIAL_PARTIAL_CONTEXTS_CONFIRMED_NO_ACTIVE_REFUSAL`. De gewenste beginvoorwaarde is nu voor twee verdere oorspronkelijke toestanden aangetoond. De ongewijzigde kandidaat convergeert er snel en ongereduceerd. Deze vergelijking is geen geïsoleerde causaliteitsproef voor uitsluitend de rang-één-formule; de actuele residuoperator maakt ook deel uit van de kandidaat.

Omdat geen kandidaatpoging werkelijk afwijst, is geen rollback/directe kleinere retry uitgevoerd of als PASS aangemerkt. Eerdere inactieve weigeringen uit REJECT26/ACTIVE27 sluiten dit bewijs niet. Er wordt niet geconcludeerd dat actieve afwijzingen nergens bestaan. De vooraf begrensde selectie wordt niet uitgebreid en geen weigering wordt afgedwongen.

B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`: lokale ongereduceerde acceptatie en inventaris zijn hier bevestigd; actieve afwijzing/rollback/directe-retry, algemene solvertoelating en volledige periodekwalificatie blijven open. Geen fysieke correctie is gerechtvaardigd door deze uitkomst. Een eventueel volgend onderzoek kan gericht uit de vijf nog niet kandidaatgetoetste, hier reeds fysiek geïdentificeerde oorspronkelijke begincontexten kiezen; die routes zijn deze ronde niet gestart.

`assess_initial30.py` controleert uitsluitend bestaande bestanden en herleidt ook de zeven geschikte contexten en de exacte selectieregel. STATUS, SELECTION, OBSERVER_AUDIT, RESULT, tracevelden, ruwe observer-/kandidaatexports, builds en de geverifieerde INITIAL30_EVIDENCE.zip bewaren het bewijs, inclusief beide gemeten compile/link-closures. B0, B1.12, canonical en de macroporiënvrije releasebasis zijn ongewijzigd.
