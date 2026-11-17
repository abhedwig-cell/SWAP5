# ACTIVE38: echte actieve afwijzing, rollback en directe kleinere retry

**Gericht geslaagd met O0 en O2.** De oorspronkelijke poging 297 wijst werkelijk af met de nieuwe DOMAINS36-correctie actief in alle dertig iteraties. De oorspronkelijke regeling verkleint dt met een factor drie; de kleinere retry accepteert in tien iteraties. Die voortzetting is numeriek bytegelijk aan een directe kleinere route vanuit exact dezelfde oorspronkelijke begincontext. Fysica, invoer, toleranties, MAXIT, tijdstap- en reductieregels zijn behouden.

## Selectie en bronidentiteit

Basis is CORRECTION37 `d8c783e63cacf360acc83622fc44af5a8cb99756`. Vóór bouwen en rekenen is broncheckpoint `6f5f7142d` vastgelegd. Alle Fortran-bronnen zijn bytegelijk aan CORRECTION37 behalve de selectiecontrole in `soilwater_native.f90`. De nieuwe numerieke correctie en provider zijn dus onveranderd; `SELECTION_DRIVER.patch` toont de enige wijziging.

De selectie was vooraf beperkt tot de bestaande ongeschaalde afwijzingen 296, 297 en 298 uit PERIOD34, vóór het eerste oorspronkelijke reductieverzoek 299. Elke route begint bij dezelfde eigen native checkpoint t1900=35797 en herhaalt de bestaande oorspronkelijke kandidaatprefix. De nieuwe correctie wordt pas bij de geselecteerde context ingeschakeld. Dit is geen voortzetting met de correctie op alle eerdere pogingen.

Poging 296 accepteert nu in drie iteraties en levert geen afwijzingsbewijs. Poging 297 levert het eerste gepaarde bewijs; de selectie is daar gestopt. Er is geen zelfstandige selectieroute voor 298 gestart. Nummer 298 komt in TRIAL297 alleen voor als de werkelijk noodzakelijke kleinere retry.

Voor poging 297 zijn de 296 voorafgaande pogingtraces (zonder rekentijd) en 294 gecommitteerde budgetregels exact gelijk aan PERIOD34. Dat omvat de echte eerdere afwijzingen en hun oorspronkelijke herstel. Begincontext, native context en cumulatieve ledger zijn identiek tussen TRIAL en DIRECT. Er zijn geen koppen, dt's of afwijzingsvlaggen kunstmatig aangepast om falen te veroorzaken. DIRECT slaat uitsluitend de geselecteerde grote proef over en vraagt de oorspronkelijke TimeControl(5)-verkleining, waarna dezelfde drain- en staatvoorbereiding volgt als bij een echte afwijzing.

## Afwijzing en kleinere retry

| Grootheid | Afgewezen poging 297 | Geaccepteerde retry |
|---|---:|---:|
| t1900 bij aanvang | 35797,370782734390 | gelijk |
| Gebruikte dt (dag) | 7,639717105455142e-5 | 2,5465723684850474e-5 |
| Iteraties | 30, daarna MAXIT-afwijzing | 10 |
| Correctie actief | 30/30 | 10/10 |
| Grootste residu | 4,6788619160148676e-3 | 1,1124484666780177e-10 |
| Somresidu | 1,9239922355418975e-2 | -1,1254241005643309e-10 |
| Fluxfactor | 1 | 1 |
| Verse V1-certificatie | geen | één |

De afgewezen kop voldoet werkelijk niet aan de bestaande residucriteria. De voorraadcorrectie heeft rang twee in vijftien en rang één in vijftien iteraties; alle dertig toepassings- en actuele-providercontroles slagen. Er is dus geen afwijzing met alleen een eerdere of inactieve correctie. De grootste volledige gecorrigeerde lineaire residufout over afwijzing en retry is 1,268082860939046e-15; de kleinste Woodbury-determinant is 0,9952253891890461. De afwijzing wordt niet veroorzaakt door de singulariteitsbeveiliging.

## Herstel en directe vergelijking

De oorspronkelijke SoilWaterStateVar(2)/MacroStateVar(2) herstellen de fysieke waterinventaris, opgeslagen kop-/vochttoestand en de overige gecontroleerde opgeslagen macrotoestand. De cumulatieve ledger blijft bytegelijk aan de beginledger vóór, na afwijzing, na rollback en vóór de kleinere retry.

Direct na rollback is **niet** elk hulpveld bytegelijk aan de oorspronkelijke dump. De verschillen zijn `macro_exchange`, `macro_rapid`, `matrix_exchange`, `boundary_rates` en `sorptivity`; de native dump verschilt in `SorpDmCp` en `SubsidCp`. De controleflag voor afwijzing verschilt zoals bedoeld. Dezelfde hulpveldverschillen zijn aanwezig tussen de post-rollback kleinere beginstaat en de directe kleinere beginstaat. Dit is daarom geen claim van onmiddellijke volledige snapshotrestauratie of algemeen native-herstartherstel.

Voor deze oorspronkelijke context bewijst de daadwerkelijke voortzetting dat die verschillen de kleinere proef niet veranderen: de geaccepteerde solveruitvoer, alle tien gecorrigeerde Jacobianen (met alleen het pogingnummer als administratief verschil), de volledige gedumpte geaccepteerde en gecommitteerde native context, de ledgers en alle budgetregels zijn exact gelijk tussen TRIAL en DIRECT. De actuele-providerstempels zijn steeds geldig. Hostcommit vindt plaats op t1900=35797,370808200110.

De onafhankelijke voorraadcontrole geeft in beide routes -2,8174026832231483e-15 cm bij een bestaande grens van 2,5465723684850477e-10 cm. De vijf domeinvoorraden en primitieve cumulatieve ledgerincrementen zijn afzonderlijk gecontroleerd. De kleine afwijking tussen deze onafhankelijk gesommeerde fout en de gewone voorraadtrace komt door de somvolgorde en blijft kleiner dan 1e-15 cm ten opzichte van dt maal somresidu.

## O0/O2, budget en grenzen

| Route | O0 (s) | O2 (s) |
|---|---:|---:|
| Selectie 296 | 1,574218 | 1,313541 |
| TRIAL297 met echte afwijzing en retry | 1,941876 | 1,629945 |
| DIRECT297 op kleinere dt | 1,415099 | 1,028714 |

Alle zes routes eindigen normaal, ongecensureerd en onder twintig seconden per route. Alle getoetste numerieke tekstuitvoer is O0/O2-bytegelijk, uitgezonderd de rekentijdvelden. De geselecteerde kalibratietoestand is vóór en na de behouden kalibratie bytegelijk. Er is geen brede campagne gestart en geen extra solver- of fysicawijziging gedaan.

Dit sluit het eerder open bewijs van echte actieve afwijzing met rollback en directe kleinere retry voor **deze** nieuwe correctie en **deze** oorspronkelijke context. Het kwalificeert geen volledig gecorrigeerde aanloop, volledige periodebalans, nieuwe native herstart, alle GWL-geometrieën of algemene afgeleiden bij krimp en omslagpunten. De status blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`; geen canonieke toelating. B0, B1.12, canonieke SWAP5 en de no-macrorelease zijn niet gewijzigd.

`RESULT.json`, `SELECTION.json`, `TRACE_FIELDS.json` en de ruwe uitvoer onder `data/` dragen de controleerbare claims. `assess_active38.py` voert alleen analyse uit. `ACTIVE38_EVIDENCE.zip` bevat bron, uitvoer en werkelijke native buildclosure; `EVIDENCE.json` bindt het checkpoint en de SHA-256. De sealer verifieert ieder opgenomen bestand streamend tegen het manifest.
