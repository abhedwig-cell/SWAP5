# COST15 — rekentijd en iteratiegedrag van de vaste kandidaatprefix

**De dominante gemeten kosten zitten in de diagnostische stapbudget-I/O, niet in headcalc.** De directe O0-meting schrijft96,2% van de gemeten voortzettingstijd toe aan het openen, aanvullen en sluiten van `step_budget.txt`. Binnen het gemeten bereik zijn geen afwijzingen, fluxreducties of iteratiestagnatie gevonden. Een optimalisatie of volledige periodekwalificatie is hiermee nog niet uitgevoerd.

## Selectie en behoud van de kandidaat

Basis is PREFIX14 `f02ef53846a33032e7e0185c3a0489274b9b8585`. Canonical blijft `f1883e6fae59658112f6b5750c395a1b54543ed2`; geen nieuwe remote delta. Dezelfde oorspronkelijke koude invoer, vaste V1+CONTRACT06-patch vanaf het eerste head en uitvoerinstellingen zijn gebruikt. Native formaat, provider/fysica, tolerantie, dtgrenzen en reductieregels zijn ongewijzigd. Alleen tellers en CPU-/wandklokmetingen zijn toegevoegd; `head_instrumentation.patch` toont de toevoegingen aan de bestaande V1-headcode.

Er zijn precies twee diagnostische modelroutes geselecteerd: O2 en O0. De oorspronkelijke harde deadline van20seconden blijft actief. Voor deze diagnose is eerder stoppen op een geaccepteerde hostcommit geselecteerd:700stappen of16seconden, wat het eerst komt. Beide processen stoppen normaal via dit meetcriterium, na16,35 respectievelijk16,61seconden totale procesaanroep. Geen censuur, herstart/chunking, ruimere timeout, andere solvervariant of brede campagne.

De eerdere PREFIX14-prefixen leveren de onafhankelijke numerieke vergelijking. Alle budgetregels tot de respectieve diagnostische stop en alle beginexports zijn bytegelijk aan PREFIX14. Ook de694 gemeenschappelijke tellerrecords zijn exact, afgezien van de timingkolommen. Dit onderbouwt behoud van de gemeten route; er wordt geen nieuw volledig-toestands- of periodebalans-PASS uit afgeleid.

## Metingen

| Grootheid | O2 | O0 |
| --- | ---: | ---: |
| Gecommitteerde stappen | 694 | 699 |
| Laatste modeltijd | 35796,34300000081 | 35796,348000001119 |
| Gemeten voortzettingsspannen, totaal | 15,971s | 15,970s |
| Headcalc, totaal wandtijd | 0,302s | 0,393s |
| Headcalc-aandeel | 1,89% | 2,46% |
| Stapbudget open/write/close, direct gemeten | Niet afzonderlijk gemeten | **15,363s / 96,2%** |
| Afgewezen headpogingen binnen meetbereik | 0 | 0 |
| Maximale iteratieteller per stap | 6 | 6 |

O2 was de eerste route. Omdat die aantoonde dat vrijwel alle tijd buiten headcalc lag, is binnen de reeds geselecteerde O0-route een extra wandklokmeting rond precies de bestaande budgetschrijfgroep geplaatst. De O0-bronnen `cost_state_log.f90` en `soilwater_log.f90` bevatten alleen die extra meetkolom; de O2-bronnen blijven bewaard. De buildrecords binden iedere optimalisatie aan de daadwerkelijk gebruikte bronpostimage.

De budgetschrijfgroep omvat de bestaande Fortran OPEN met `position='append'`, geformatteerde WRITE en CLOSE. Er wordt nog steeds per stap opnieuw geopend en gesloten. De diagnostische kostentrace zelf gebruikt één open bestand; de gemeten voortzettingsspannen sluiten de kostentrace-WRITE/FLUSH en het opzetten van de volgende meting uit. Startup, resterende profiler-I/O en beëindiging verklaren dus mede het verschil met de totale procesaanroep. De directe budgettijd bevat de formatteringskosten van de oorspronkelijke primitieve budgetregel en de systeem-/bestandssysteemtijd van deze drie handelingen samen.

In O0 bedraagt de gemiddelde budgetschrijftijd circa14,48ms in de eerste100stappen en19,36ms in de laatste100. De overeenkomstige headtijden zijn circa0,788ms en0,583ms. Dit ondersteunt een meetpad dat veel meer tijd vraagt dan de solver. Het bewijst niet welke afzonderlijke OPEN/WRITE/CLOSE- of OS-functie de vertraging veroorzaakt. Disk, antivirus, synchronisatie of bestandsgroei als specifieke oorzaak zijn niet afzonderlijk gemeten.

Het eerdere Python-I/O-microbenchmark uit PREFIX14 was onvoldoende om deze Fortran-schrijfroute als dominant aan te wijzen. De huidige conclusie berust op directe tijdmeting binnen de echte modelroute; niet op extrapolatie van dat microbenchmark.

## Iteratiegedrag

Iedere gemeten commit bevat precies één headpoging en FrReduQ=1. In O0 zijn229stappen met teller1,215met2,139met3,12met4,85met5 en19met6 gevonden. O2 doorloopt dezelfde gemeenschappelijke reeks en stopt vijf stappen eerder op zijn eigen16s-meetgrens. Er is in dit bereik geen groei naar de oorspronkelijke iteratielimiet of retrycyclus.

De gekoppelde verse V1-certificering wordt éénmaal gebruikt in598stappen en tweemaal in101O0-stappen (96inO2). Een tweede certificering leidt hier dus tot beperkte extra iteraties, niet tot stagnatie. Vector-, Jacobiaan-, macro-rate- en afgeleide-aanroepen zijn per headpoging geteld en staan in RESULT.json.

De oorspronkelijke variabele iBackTr telt ook de eerste line-searchpoging van iedere iteratie. Zij mag niet als aantal mislukte backtracks worden gelezen. Hier is het aantal getelde pogingen gelijk aan het aantal Jacobiaanstappen: **geen extra line-searchpogingen boven de eerste per iteratie**. De code verandert de line-searchvoorwaarden niet.

CPU_TIME levert in deze Windows-closure grof gekwantiseerde waarden. Veel afzonderlijke korte calls hebben daardoor0als gemeten CPU-duur. Dat betekent niet dat zij geen CPU gebruiken. Macro-CPU-sommen zijn als ruwe diagnostiek bewaard, maar ondersteunen geen betrouwbare fijnmazige rangschikking van sorptie, Darcy, Jacobiaan enzovoort. De hoge-resolutie SYSTEM_CLOCK-wandtijden zijn de basis van de bovengenoemde kostentoerekening.

## Geldigheidsgrens en minimale vervolgstap

De diagnose geldt tot de gemeten stop rond35796,348; zij sluit een latere solvermoeilijkheid vóór35797 niet uit. PREFIX14's latere ontbrekende eindpunt is niet alsnog bereikt. De huidige data onderbouwen wél dat de gemeten vaste prefix niet hoofdzakelijk door Newton-/macrorekentijd wordt begrensd. Een algemene claim dat de gehele kandidaat altijd snel convergeert is niet gerechtvaardigd.

De kleinste passende vervolgstap is **alleen de diagnostische budgetregistratie aanpassen**: één open, gebufferde stroom of tijdelijk in-memory records met gecontroleerde export. Behoud exact dezelfde primitieve waarden, volgorde en identiteit; bewijs gelijkheid met de bestaande prefixregels. Selecteer daarna afzonderlijk de oorspronkelijke prefix-capture onder dezelfde20s-limiet. Er is geen aanleiding om Newtoncriteria, fysica, dt of de timeout te wijzigen. De theoretisch wegvallende I/O-tijd is geen reeds bewezen versnelling of voltooiing.

Alle huidige rapportage is uitsluitend diagnose. Volledige periodebalans, V4-readback en officiële promotie blijven ongekwalificeerd. De eerder geërfde lokale PASS'en worden niet verbreed. Herbeoordeling zonder modellen: `python research/swap431-macro-b1-cost15/assess_cost15.py`. STATUS.json, RESULT.json, ruwe kostentraces, buildidentiteiten, patch en bewijscapsule vormen het herstelpad.
