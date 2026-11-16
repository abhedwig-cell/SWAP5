# REJECT26 — echte weigering, rollback en directe kleinere retry

**De kandidaat slaagt voor echte afwijzing, herstel en gelijkheid met een directe kleinere berekening in oorspronkelijke context B, met O0/O2.** De grote stap weigert werkelijk na 30 iteraties; de kleinere retry accepteert in zes iteraties. Vanaf de geaccepteerde solverreturn zijn toestand, ledger, hostcommit en primitieve budgetregel bytegelijk aan de directe kleinere route.

**Beperking: de rang-één-aanvulling is in deze context niet actief.** Er is dus geen afwijzing mét actieve rang-één-correctie gekwalificeerd. Deze uitsluiting wordt niet opgeheven door de eerdere actieve acceptatie-PASS uit JAC24/COMMIT25.

## Oorspronkelijke context en één afgebakende selectie

Baseline is COMMIT25 870ffbb3f78ddb51b0128be8779169dc8a4da318. De oorspronkelijke node-52-poging uit JAC24/COMMIT25 convergeert met de kandidaat en kan geen echte afwijzing meer leveren. Daarom is uitsluitend de reeds eerder vastgelegde oorspronkelijke RETRY07-context B geselecteerd: **t1900=35796,9513533331; dt=2e-5 dag; IDecMpRat=0**. Er is geen nieuwe contextzoektocht, grotere kunstmatige dt of verscherpt criterium gebruikt om een weigering af te dwingen.

De koude aanloop gebruikt de oorspronkelijke geselecteerde casus en oorspronkelijke Darcy-gate. Pas bij B worden dezelfde bestaande Darcycorrectie, actuele macro-evaluatie en ongewijzigde analytische rang-één-kandidaat ingeschakeld. De volledige gemeten oorsprong-inventaris is per optimalisatie bytegelijk aan RETRY07/B_TRIAL/origin.txt. TRIAL en DIRECT hebben bovendien bytegelijke oorsprong, uitgebreide context en ledger. Er is geen toestand uit een andere route tussengevoegd.

De activeringsselectie van de onderzoeksdriver is verplaatst van een attemptnummer naar deze oorspronkelijke B-context, inclusief haar retries. De echte rang-één-formule, actuele residuevaluatie, fysieke provider, criteria, dtgrenzen, reductiepolicy en hostintegratie zijn behouden. De eerder uitgevoerde kalibratiereplay wordt hier niet opnieuw aangeroepen; zij is geen onderdeel van de solveraanvulling.

Vier routes zijn uitgevoerd: TRIAL en DIRECT voor O0/O2. Iedere route heeft de harde twintigsecondenlimiet. De scope staat maximaal vier oorspronkelijke headpogingen toe en stopt eerder bij een verzoek om fluxreductie; in de werkelijke TRIAL-route zijn slechts twee pogingen nodig. Na de eerste geaccepteerde hostcommit stopt het proces, zonder vervolgstep of eigen herstart.

## Echte afwijzing en oorspronkelijke kleinere retry

| Grootheid | Grote proef | Kleinere retry |
| --- | ---: | ---: |
| Gebruikte dt, dag | 2e-5 | 1e-5 |
| Uitgevoerde iteraties | 30 | 6 |
| Uitkomst | Afwijzing | Acceptatie |
| Grootste absolute residu | 0,0203849084469365 | 1,54122867496165e-7 |
| Somresidu | −0,00646757273034400 | −1,54060554986537e-7 |
| Gebruikte fluxfactor | 1 | 1 |

De grote proef eindigt met fldecdt=true, FlDecMpRat=false en IDecMpRat=0. De loopindex 31 volgt uit uitputting van de oorspronkelijke 30 iteraties; het is geen gewijzigde iteratielimiet. Er is geen kunstmatige weigering of reductieflag gezet om dit resultaat te krijgen.

De oorspronkelijke SoilWaterStateVar(2), MacroStateVar(2) en TimeControl(5) worden uitgevoerd. Met de bestaande factor-/minimumstapregel wordt dt=1e-5. Drainage wordt zoals in de oorspronkelijke retry-loop opnieuw berekend; de nieuwe beginstaat wordt op dezelfde manier opgeslagen. De retry voldoet aan de oorspronkelijke compartiment- en totale criteria zonder fluxreductie en passeert de verse V1-controle.

DIRECT doorloopt dezelfde oorspronkelijke aanloop en slaat alleen de grote proef over. Zij gebruikt dezelfde TimeControl(5)-verkleining en dezelfde voorbereidende aanroepen om rechtstreeks dt=1e-5 te berekenen. Dit is de kleinere vergelijkingsroute, geen als afwijzing voorgestelde geforceerde vlag.

## Rollback: wat is direct hersteld?

Na de originele rollback zijn h/hm1, theta/thetm1, pondvoorraad, matrixvoorraad, macro-totaal- en domeinvoorraden, compartimentvoorraden, geometrie, sorptieklok en wet-wallvelden exact gelijk aan de oorsprong. De controlvector verschilt uitsluitend in de echte dt-verkleiningsaanvraag.

De volledige werktoestand is op dat moment niet bytegelijk. Er blijven verschillen in macro-uitwisseling, rapid-drainagewerkdebieten, matrix-uitwisseling, enkele randdebieten, eventflags, sorptiereferenties en sorptiviteit. Diezelfde zeven veldgroepen verschillen ook tussen het begin van de kleinere retry en het begin van DIRECT. Volledige onmiddellijke geheugengelijkheid wordt daarom niet geclaimd.

De daadwerkelijke herberekening maakt hun effect in deze geselecteerde context ongedaan: accepted_return, de volledige pre-herstel solverexport, uitgebreide context, ledger en committed-toestand zijn bytegelijk tussen TRIAL en DIRECT. Ook de geaccepteerde primitieve budgetregel is exact gelijk. Dit kwalificeert de geobserveerde herberekenbaarheid hier; het bewijst niet dat deze velden op andere droge/eventovergangen onschadelijk zijn.

Alle cumulatieve ledgerexports van oorsprong, grote return, rollback en kleinere return blijven bytegelijk vóór de echte hostintegratie. De afgewezen proef is dus niet als waterstap geboekt. Alleen de geaccepteerde kleinere stap gaat door de echte SoilWater(3), macrostate/integratie, integral(3), warmte en TimeControl(3).

## Hostcommit, waterinventaris en directe gelijkheid

Beide routes committeren op **35796,951363333101**, met gebruikte en volgende dt=1e-5. De onafhankelijke matrix-/macro-/pond-/canopycontrole gebruikt de echte kleinere beginstaat en de geaccepteerde primitive rates:

| Grootheid | TRIAL en DIRECT, O0/O2, cm |
| --- | ---: |
| Matrixvoorraadverandering | 2,682210662090192e-5 |
| Macrovoorraadverandering | −3,1829146833958766e-5 |
| Pondvoorraadverandering | 0 |
| Canopyvoorraadverandering | −3,921116395119717e-9 |
| Netto externe integraal inclusief canopy | −5,0109597888206294e-6 |
| Gecombineerde inventarisafwijking | **−1,5406313343937963e-12** |
| Oorspronkelijke dt × CritDevBalTot | **1,0000000000000002e-10** |

De inventarisafwijking sluit binnen afronding aan bij dt maal het toegelaten gekoppelde somresidu. De vijf macrovoorraden sluiten afzonderlijk, met maximale afwijking circa 2,33e-17 cm. De cumulatieve scalarboekingen sluiten op de gebruikte primitieve integralen. Er wordt geen afgeronde BAL-regel of gereconstrueerde cumulatieve voorgeschiedenis gebruikt.

## O0/O2 en geldigheidsgrens van de rang-één-tak

| Route | O0 | O2 |
| --- | ---: | ---: |
| Echte grote proef, rollback en kleinere retry | 1,702 s | 1,273 s |
| Direct kleinere berekening | 1,038 s | 0,811 s |

Alle processen stoppen normaal en ongecensureerd. Alle gemeten niet-timingvectors zijn per route bytegelijk tussen O0/O2. Er zijn geen mislukte opstartroutes of extra inhoudelijke varianten in deze ronde.

In B is de domein-3-minimumvoorraad geen bindende uitstroomgrens: alle gemeten uitstroomfactoren zijn 1 en het uitstroomoverschot is nul. De aanwezige voorraad ligt boven het behouden minimum. De rang-één-getter levert daarom volgens zijn oorspronkelijke activeringsvoorwaarden nul aanvulling in alle 30 grote en zes kleinere Jacobiaanstappen. De volledige kandidaat is daadwerkelijk aangeroepen, maar haar nieuwe niet-lokale correctie komt in dit afwijzingsbewijs niet in werking.

Status is daarom PASS_ORIGINAL_B_REFUSAL_ROLLBACK_DIRECT_RETRY_WITH_ACTIVE_UPDATE_EXCLUSION. Een weigering nadat de rang-één-tak daadwerkelijk actief is geweest blijft open. Er is geen grond om die uitsluiting te vervangen door een geforceerde iteratielimiet, aangepaste dt of gewijzigde fysieke minimumvoorraad. Er is ook geen brede zoektocht naar zo'n geval gestart.

De huidige ronde omvat geen vervolgstep, native herstart, volledige periodebalans of algemene solverpromotie. De bekende IEEE_DENORMAL-eindmelding van de instrumentatie blijft in de ruwe O2-uitvoer bewaard; er wordt geen algemene floating-pointstatusidentiteit met een niet-geïnstrumenteerde executable geclaimd.

assess_reject26.py controleert uitsluitend bestaande bestanden. RESULT.json, scope_and_driver.patch, oorspronkelijke B-exports, voor-/na-rollbackvelden, geaccepteerde solver/commit/ledger, builds en het geverifieerde REJECT26_EVIDENCE.zip bewaren het herstelpad.
