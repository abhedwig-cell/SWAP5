# SWAP431-MACRO-B1-ACCEPT01

Onderzoeksbasis: auditcommit `798c0bff798e6906c46b0cbfb8c8850fed3a037e`, canonical `f2377211d2be58d03d96e50fb0a6bc35ced3c90f`. Dit is een afzonderlijk B0-afgeleid experiment. B0, canonical, bestaande ontwikkelbranches en de B1.12-patchreeks zijn niet gewijzigd.

## Besluit

**De gerichte acceptatiecorrectie werkt binnen de tweedaagse proef. V1 is de voorkeurskandidaat, maar wordt nog geen gekwalificeerde B1-referentie.** Er zijn precies twee numerieke varianten onderzocht. Beide voltooien de oorspronkelijke korte Andelst-berekening op O0 en O2, zonder voortzetting na mislukte convergentie. Hun geobserveerde actuele gekoppelde residuen voldoen aan de oorspronkelijke criteria. Dat is concrete vooruitgang ten opzichte van de audit, die overschrijdingen in de ongewijzigde B0 aantoonde.

Twee grenzen verhinderen een bredere referentieclaim. Ten eerste herstelt de oorspronkelijke afwijzingsroute niet alle sorptiereferenties en eventflags onmiddellijk. De gemeten kleinere herhaalstap is wel exact gelijk aan een kleinere stap uit onaangeroerde begincontext. Een schadelijk resultaat van die geheugensporen is hier dus niet bewezen. Ten tweede activeert de strengere oplossing de reeds bestaande reductie van macro-uitwisseling bij minimumtijdstappen. De reductiewet is niet veranderd, maar de gecorrigeerde berekening maakt er vaker gebruik van. Een klein actueel residu bewijst daarmee nog geen oplossing van het ongereduceerde fysische probleem.

Er is geen grond om nu een volledige herschrijving of een nieuwe Jacobiaan te maken. Wel is er reden om V1 te behouden als experimentele corrector en de resterende geheugen- en reductievraag afzonderlijk af te bakenen. Er is geen derde numerieke variant gestart en geen langere modelperiode geselecteerd.

## De twee wijzigingen

**V1, afsluitende gekoppelde controle.** Bij voorlopige convergentie wordt de bevriezing opgeheven en roept de solver de oorspronkelijke `vector_F(1,hgrad)` aan. De bestaande lokale residu-, hoofd-, maaiveld- en totale criteria worden opnieuw toegepast. Bij falen volgt een volgende oorspronkelijke Newton-iteratie of de oorspronkelijke afwijzingsroute. De laatst berekende actuele uitwisseling blijft de gepaarde flux voor matrix en macrovoorraad. Er wordt dus niet alleen een nieuwe flux ingevuld en alsnog zonder controle geaccepteerd.

**V2, geen macrobevriezing.** Alleen de oorspronkelijke versnelling die `flunsatok(3)` activeert wordt uitgeschakeld. De bestaande macroafgeleide blijft gedurende Newton actief. Deze variant is een controle van het bevriezingsmechanisme; V1 heeft de voorkeur omdat zij het afsluitende gekoppelde acceptatiecontract expliciet maakt.

De wijzigingen staan als afzonderlijke `V1/fix.patch` en `V2/fix.patch`, met hun volledige gegenereerde bronkopieën. Deze patches zijn tegen de Linux-platformgeselecteerde bouwkopie opgesteld; tekstregels zijn in de experimentele kopie naar LF genormaliseerd. Zij vervangen geen ruwe B0-archiefleden en zijn niet in de officiële B1-patchreeks opgenomen.

Fysische wetten, `SWMBF=1`, `SWKIMPL=0`, `DTMIN=1e-5 d`, `CritDevBalCp=1e-6`, `CritDevBalTot=1e-5`, oorspronkelijke iteratielimieten, backtracking en reductiewet zijn behouden. Alleen `TEND` en uitvoerinstellingen zijn zoals in de audit op twee dagen begrensd. De oorspronkelijke koude initialisatie en forcing zijn gebruikt.

## Uitgevoerde proeven en resultaten

Alle waarden hieronder gelden voor dezelfde oorspronkelijke twee dagen. O0 en O2 geven exact dezelfde geregistreerde dagbestanden, eindtoestand en pogingjournalen.

| Grootheid | B0 | V1 | V2 |
| --- | ---: | ---: | ---: |
| Geaccepteerde stappen | 1022 | 1538 | 1233 |
| Afwijzingen met kleinere tijdstap | 0 | 52 | 70 |
| Verzoeken om macrofluxreductie | 0 | 11 | 16 |
| Voortzettingen zonder convergentie | 0 | 0 | 0 |
| Geaccepteerde stappen met actief reductieniveau 1 | 0 | 11 | 16 |
| Geaccepteerde iteraties, som | 2766 | 6194 | 3869 |
| Geprint GWL einde dag 2, cm | -65.77381 | -65.71347 | -65.71217 |
| Grootste absolute dagelijkse BALDEV, cm | 5.96535e-7 | 5.49177e-7 | 6.21654e-7 |

De oorspronkelijke B0 heeft in deze twee dagen geen afwijzingen, maar accepteert volgens de voorafgaande audit bevroren toestanden die na een verse evaluatie niet aan de gekoppelde criteria voldoen. Het lagere aantal iteraties is daarom geen bewijs van een betere oplossing. De mislukte pogingen tonen soms `numbit=MaxIt+1` na uitputting van de Fortran-DO-lus; dat is een tellerstand, niet een extra uitgevoerde iteratie.

De niet-geïnstrumenteerde V1/V2-executables voltooien in circa 0.88/0.79 s bij O2 en 1.54/1.64 s bij O0. Dit zijn korte lokale modelwandtijden, geen portable performancekwalificatie. De volledige O0-bronsluiting is opnieuw gebouwd in 37.85 s, inclusief TTUTIL. De O2-sluiting hergebruikt de vooraf hash-gecontroleerde oorspronkelijke objecten, behalve de werkelijk opnieuw gebouwde gewijzigde routines.

Een observer die elke geaccepteerde stap in een afzonderlijk proces herberekent bereikte de vaste grens van twintig seconden. De eerste 756 V1- en 886 V2-waarnemingen voldeden allemaal aan de oorspronkelijke residucriteria; de resterende periode is in die profielen niet gekwalificeerd. Beide afgebroken proeven zijn als CENSORED bewaard.

Daarna is uitsluitend de observatieselectie verkleind: twintig vroege stappen, twintig geaccepteerde stappen rond de eerste echte afwijzing en de eindstap. Geen derde fysische of numerieke kandidaat is gemaakt. Deze observers voltooien op O0 en O2 binnen circa 2.1 tot 2.9 s. Alle 41 geselecteerde verse residuen per kandidaat en optimalisatie voldoen. De grootste lokale residuen zijn 9.7538231e-7 voor V1 en 8.0903902e-7 voor V2. V1 berekent daarnaast volgens haar implementatie bij iedere gewone acceptatie het gekoppelde eindresidu opnieuw; alle 1538 geregistreerde acceptatiecertificaten voldoen. De onafhankelijke observaties blijven een geselecteerde steekproef.

In totaal zijn zestien korte modeluitvoeringen gedaan, waarvan twee bewust op de observatietijdslimiet gestopt. De som van de modelwandtijden is 61.30 s. Er zijn geen 481-daagse uitvoeringen gedaan.

## Werkelijke afwijzing en herstel

De eerste echte gewone afwijzing van beide varianten ligt bij `t1900=35796.919999999991`, `dt=0.002 d`, tijdens de oorspronkelijke tweede dag. De waarneming gebruikt twee forks van precies dezelfde levende Fortran-begintoestand, direct na de oorspronkelijke toestandopslag:

1. De eerste fork voert de werkelijk mislukte grote `headcalc`-poging uit, daarna de oorspronkelijke `SoilWaterStateVar(2)`, `MacroStateVar(2)` en `TimeControl(5)`, en vervolgens de kleinere poging met de oorspronkelijke herberekening van drainage.
2. De tweede fork slaat de mislukte poging over en neemt dezelfde kleinere stap uit de onaangeroerde context, met dezelfde numerieke retry-instellingen.

De stap wordt verkleind tot ongeveer 0.000666666667 d. Beide kleinere pogingen slagen. Waterstocks, macrovolumes, matrix-h/theta, cumulatieve sorptieklokken en de overige geregistreerde voorraadvelden zijn na herstel gelijk. Alle negentien geëxporteerde veldgroepen van de teruggegeven kleinere poging, inclusief uitwisseling, eventflags, sorptiereferenties en controles, zijn bytegelijk tussen beide routes. Dit is een echte afgewezen tijdstap, geen twee identieke evaluaties of externe dag-discard.

**Onmiddellijk na rollback is de moduletoestand echter niet volledig gelijk.** Negen sorptiereferentiecellen en zes eventflags behouden sporen van de mislukte poging. De grootste verschillen zijn 0.444 in referentie-theta en circa 0.28424 in sorptiviteit; de actuele uitwisselingswerkarray verschilt maximaal circa 0.09286 cm/d. De cumulatieve klok op de gewijzigde referentiecellen is nul, wat past bij opnieuw berekende eventstartgrootheden. Sommige gewijzigde eventflags behoren echter bij een reeds positieve klok van 0.002 d. Die flags mogen dus niet zonder verdere analyse als onbelangrijk tijdelijk rekenwerk worden afgedaan.

De bronroute is concreet: `macrorate.f90` rond 1711-1724 actualiseert sorptiereferenties en rond 1802-1805 `FlEndSrpEvt`; `MacroStateVar` rond 1672-1681 herstelt alleen domeinbodems, volumes en onverzadigde compartimentvoorraden. `MACROSTATE` rond 1423-1440 gebruikt de eventflag om een sorptieklok te beëindigen of voort te zetten. Het onmiddellijke volledige geheugenherstel faalt dus, terwijl de effectieve kleinere retry in de onderzochte natte overgang exact reproduceert. Een schadelijke latere klok- of drukhoogteafwijking is daarmee niet bewezen en ook niet uitgesloten.

## Afgeleiden, waterbehoud en observatie-invloed

Op de eerste geselecteerde geaccepteerde toestand na de afwijzing zijn vier oorspronkelijke macrodiagonaalafgeleiden getoetst, op knopen 1/34/56/81, met centrale verschillen van 1e-4 en 5e-5 cm. De grootste absolute afwijking is ongeveer 1.68e-12. De oorspronkelijke rate- en rate/Jacobiaantaken geven exact dezelfde uitwisseling. Na terugkeer naar de oorspronkelijke hydraulische invoer is ook de uitwisselingsvector exact terug. Dit ondersteunt deze geselecteerde afgeleiden, niet een volledige Jacobiaankwalificatie bij alle overgangen.

De donor-/ontvangerkoppeling is ongewijzigd: `QExcMtxDmCp` wordt tot `QExcMpMtx` gesommeerd, met tegengesteld teken in matrixresidu en macrovoorraadintegratie. De eerdere bronaudit blijft daarvoor de grondslag. De geprinte dagelijkse macrobalansen zijn nul op hun uitvoerprecisie; de totale dagelijkse afwijkingen staan in de tabel. Er is geen onafhankelijke volledige substepinventaris van iedere donor en ontvanger toegevoegd. Deze resultaten bewijzen geen exacte nulbalans of wetenschappelijk correcte drukhoogtontwikkeling.

Voor B0 reproduceren de metricsexecutable en de eerdere ongewijzigde controle de geselecteerde fysieke bestanden exact. Voor V1 en V2 zijn de vier dag/geometrie/eindbestanden gelijk tussen de kale patch, de metricsuitvoering en de forkobserver, op O0 én O2. De pogingjournalen van metrics en observer zijn eveneens exact. Alleen kinderen wijzigen de diagnostische modeltoestand. De forkouders behouden hun oorspronkelijke toestand; kinderen verlaten zonder normale Fortran-afsluiting. Dit kwalificeert observatie-invloed binnen deze uitvoergrens, niet de serialisatie van ieder intern SAVE-veld.

## Waarom nog geen B1-promotie

V1 sluit het aangetoonde acceptatiegat in de korte proef. Het maximale terminale nodale drukhoogteverschil met B0 is 0.08443082 cm, zonder dat dichter bij SWAP5 komen een criterium is. V2 verschilt maximaal 0.08377079 cm. Kleine verschillen zijn op zichzelf geen validatie.

De oorspronkelijke reductieroute gebruikt `FrReduQ=0.1**IDecMpRat`. De V1-proef accepteert elf stappen bij niveau 1, samen ongeveer 126.26 s modeltijd; V2 zestien stappen, samen ongeveer 187.35 s. Het oorspronkelijke B0 gebruikt die reductie in deze korte periode niet. De referentie zou dus niet alleen een eindcontrole toevoegen, maar op sommige stappen ook de reeds bestaande numerieke reductie activeren. De bijdrage daarvan aan de gewijzigde hydraulische uitkomst is niet afzonderlijk geïsoleerd. Geen reductiewet, dtmin of tolerantie is aangepast om dit te verbergen.

De uitkomst is daarom: **lokale acceptatiereparatie ondersteund; generieke verbeterde migratiereferentie nog niet gekwalificeerd.** Volledige procesgeheugenrollback, betrouwbaarheid van de ongereduceerde koppeling, eigen herstart en verdere relevante overgangen blijven afzonderlijke vragen. De stopregel is gevolgd. De vervolgvraag en kleinste eventuele herstelroute staan in `CODEX_FOLLOWUP.md`.

## Bewijs en herstelpunt

`PREREGISTRATION.json` is vóór de numerieke proeven vastgelegd in commit `dc635977ede7a67cbade23fbd83546daed173964`. De oorspronkelijke observatieselectie en O2-resultaten staan in `2ae1c03ab2b4af7cd6d1b00e5c67877eb25f39fc`. De twee censored profielen en de vooraf verkleinde observatieselectie zijn vastgelegd in `b45cbe6a29202365d13ddf2873ac6cd8fe4a76e3`.

`RESULT.json` bevat de beoordeling, alle vergelijkingen en uitvoeringsidentiteiten. `assess_b1_accept01.py` voert alleen gegevenscontrole uit. De bronkopieën, patches, compiler-/linkcommando's, objectidentiteiten, werkelijk gebruikte executables, fysieke invoer, pogingjournalen, volledige forkvelden en censored data zijn behouden. De bounded observers zijn na herstel van een logbestandsnaamconflict opnieuw gebouwd; hun executablehashes zijn exact gelijk aan de reeds geteste postimages. Er zijn daarvoor geen modelruns herhaald. Het bewijsarchief en de hash ervan staan in `EVIDENCE.json`.

Beoordeling na uitpakken, zonder nieuwe modellen of compilatie:

```sh
python phase/assess_b1_accept01.py --root phase --b0-case AUDIT_CAPSULE/run-control-output
```

`AUDIT_CAPSULE` is de uitgepakte, overgeërfde B0-auditcapsule. Het nieuwe archief bewaart de fase onder `phase/` en de hergebruikte O2-objecten onder `O2-provider/`. De opgeslagen buildlogs en scriptargumenten leggen de daadwerkelijke lokale compiler-/inputcontext vast.
