# NATIVE55 - eigen native overdracht exact, geaccepteerde vervolgstep nog open

De eigen native subdagoverdracht van GEORESTORE54 is onderbouwd met O0/O2: schrijven/lezen, geïnstalleerde fysieke/native/cumulatieve toestand, opnieuw opgebouwde oorsprongsbuffers en de volgende solverpogingen zijn exact gelijk aan het ononderbroken traject. De volledige gevraagde geaccepteerde vervolgstep is niet gekwalificeerd. Zowel continu als herstart vraagt de oorspronkelijke controller op dtmin om fluxreductie; die valt buiten de bestaande B1-grenzen en wordt niet doorgelaten.

## Eigen checkpoint en begrensde fasevariant

Baseline GEORESTORE54 1b6e02b9fc8101ebcb06e2ed360dcd8e56ca446c. Prebuild broncheckpoint9d05ab908. CONT herstelt dezelfde oorspronkelijke D2 (oude3066) met1309commitprefix en dezelfde drie echte ongereduceerde afwijzingen/korte acceptatie als GEORESTORE54. De eerste vier pogingregels, oorspronkelijke prefix, checkpointvoorraad/nativecontext en ledger zijn exact gelijk aan die ouder. Het checkpoint ligt na echte SoilWater3, Integral3, warmteberekening en TimeControl3: t35797.290431125148, volgende dt2.0951312035156963e-5. Geen handmatige stateinjectie of aangepaste tijdstap.

De bestaande V5-schrijver is uitsluitend voor een voltooide dag met volledige prefixdekking. Deze D2 is subdag; de herstelprefix is niet een volledig kandidaattraject vanaf het balansbegin. Er is daarom een afzonderlijke V6/phase1-variant toegevoegd. Zij schrijft dezelfde bestaande fysieke/nativevelden en ledger, zonder de V5-claim van een volledig kandidaatbalansprefix. Er zijn geen nieuwe persistente fysieke velden of algemene statearchitectuur. De V5-dagfase- en coveragecontroles blijven strikt behouden; V6 accepteert alleen phase1/subdag. Bestaande mode-, identiteit-, dimensie-, eindigheids-, crop- en inventariscontroles blijven aanwezig.

Het bestand candidate.end is door de echte native inoutend-schrijver gemaakt:139128bytes, V6,phase1,numnod112,NumDm5. Alle Fortran-recordmarkers, de unieke versieheader/signature en de eindmarker zijn onafhankelijk gecontroleerd. O0/O2 schrijven bytegelijke bestanden. De RESTART-inputhash is exact de hash van het eigen producerbestand. Het oorspronkelijke TSTART/TEND-laadvenster blijft behouden; de werkelijke subdagtijd, volgende dt en dag-/forcingfase komen uit native.

Voor/na de writer-I/O zijn inventaris, nativecontext en ledger bytegelijk. De onafhankelijke inventarisfout van de checkpointstep blijft1.154971428410961e-11cm binnen1.0475656017578482e-10cm, zoals GEORESTORE54. Er is geen voorraad- of klokcorrectie uitgevoerd.

## Vers proces en opnieuw opgebouwde transactieoorsprong

RESTART wordt als nieuw proces uit het eigen candidate.end gestart, zonder koude prefixreplay. De native installatie, eerste geïnitialiseerde nativecontext en ledger zijn bytegelijk aan het producercheckpoint. Hydraulische caches, temperatuur, cropconstanten, canopyvoorraad, macro-/matrixvoorraad, geometrie, sorptiehistorie en tijd/dt worden door de bestaande getypeerde installatie gelijk gemaakt; deze vergelijking bevat alle velden van de bestaande nativecontextdump.

De tijdelijke RESTORE52/GEORESTORE54-origins en CONTACT47-providerscratch worden niet geserialiseerd. De normale SoilWater2-aanroep bouwt vóór headcalc de saved-state-oorsprong opnieuw op. Een read-only originreceipt bevestigt voor beide vervolgpogingen de actuele tijd,112/5-dimensies,ready1 en volledige gelijkheid van de opgeslagen referentie-, beginsorptiviteit-, scheurvolume- en subsidence-arrays met hun actuele oorsprong. Die receipts zijn continu/herstart bytegelijk. De CONTACT47-cache is vóór elke head ongeldig en leeg; actuele provider- en geometriegegevens zijn na pogingindexnormalisatie exact gelijk.

Voor de eerste rate zijn enkele outputwerkvelden verschillend: macro_in_vert, macro_exchange, macro_rapid, matrix_exchange, matrix_vertical, event en boundary_rates. Bij boundary_rates verschillen uitsluitend de oude qtop en reva; actuele forcingcomponenten zijn gelijk. Na de echte solverberekening blijft alleen matrix_vertical verschillend. Die outputflux wordt normaal bij de niet-bereikte geaccepteerde SoilWater3-stap bijgewerkt; er is hier geen hostintegratie op geweigerde pogingen. Dit zijn expliciet beoordeelde werkverschillen, geen extra persistente velden die in deze native variant zijn toegevoegd.

## Waarom de volledige vervolgstep geen PASS is

Het ononderbroken traject zelf weigert de eerste vervolgpoging bij dt2.0951312035156963e-5: oorspronkelijke MAXIT30, maxres0.0021218091917013238,som0.0086375433434778843,node52. De oorspronkelijke TimeControl5 kiest daarna dtmin1e-5. De daaropvolgende floor-poging doorloopt de bestaande60-iteratievloerpolicy en vraagt IDecMpRat1/FlDecMpRattrue: maxres2.1613728871255899e-4,som0.0015179109854425075,node57. De geregistreerde FrReduQ is nog1; het is een reductieverzoek, geen geaccepteerde gereduceerde stap.

De verse native herstart doorloopt precies dezelfde twee solverpogingen en -traces. Native begin-/returncontexten, ledgergegevens, oorsprongsbuffers en alle bestaande provider-/geometriereceipts zijn continu/herstart exact gelijk na alleen pogingindexnormalisatie. De eerste gewone afwijzing wordt door de ongewijzigde host teruggerold. Het uitgesloten schaalverzoek wordt eveneens teruggerold en de route stopt met NATIVE55_FOLLOW_SCALED_REQUEST_EXCLUDED.

Er is geen tijdvooruitgang, nieuwe ledgerintegratie of vervolgcommit. De finale nativecontext is continu/herstart bytegelijk en verschilt van het oorspronkelijke checkpoint alleen in dt/dtold door de echte retrycontroller. Er ontstaat geen follow.end. CONT heeft alleen de ene eerder gekwalificeerde D2-checkpointcommit; RESTART heeft nul geaccepteerde commits. Een volledige nieuwe follow-waterbalans, warmte-integratie of geaccepteerde native vervolgstap kan daarom niet als PASS worden gerapporteerd.

Deze uitkomst geeft in de getoetste pogingsequentie geen aanwijzing voor ontbrekende native fysieke toestand: ook de ononderbroken berekening faalt identiek. Zij bewijst geen algemene herstartcorrectheid buiten deze eigen checkpoint en dezelfde gevalideerde pogingen.

## O0/O2, kosten en grenzen

| Route | O0 seconden | O2 seconden |
|---|---:|---:|
| CONT-D2, checkpoint + vervolgpogingen |12.378568|8.138826|
| RESTART-D2, vers proces |1.397336|1.158342|

Alle vier routes normaal, ongecensureerd en onder hard20s per route. Bestaande interne16-stopbeleid,512owncommit-/4retrygrenzen, solver-, tolerantie-, MAXIT-, dt- en reductieregels zijn niet verruimd. De vloerpolicy en schaalafwijzing zijn oorspronkelijke regels. Geen extra provider, nieuw scenario, herhaling met gewijzigde dt, brede campagne of doorgelaten reductie. Het door de oude runner gekopieerde calibration_base.bin wordt niet als proef-/replaystaat gebruikt.

O0/O2 zijn identiek in alle niet-timingtekstuitvoer per route, inclusief eigen bestandsbytes en nieuwe oorsprongsreceipts. IEEE-stderr-identiteit is geen criterium. NATIVE_HARNESS.patch bindt de fase-/harness-/read-only-observerdelta aan de onveranderde GEORESTORE54-fysica. De nieuwe V6 is een begrensde positieve eigen-filetest; geen volledige nieuwe matrix van corruptie-/cross-ABI-/invoerdrifttests.

## Status

PARTIAL: eigen subdagbestand, verse installatie, originrebuild en identieke geweigerde vervolgpogingen zijn gekwalificeerd. Een volledige geaccepteerde gelijktijdige vervolgstep blijft OPEN door hetzelfde dtmin-schaalverzoek in continu en herstart. Geen dagovergang, volledigeperiode/BAL-/PEARL-, ander regime of algemene nativeherstarttoelating. De lokale ledgeroverdracht verleent geen claim van een volledig kandidaatbalansprefix. B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS; B0/B1.12/canoniek/no-macrorelease onaangeraakt.

Veilige vervolgstap is een afzonderlijk gerichte diagnose van de gekoppelde weigering in deze exacte eerstvolgende oorspronkelijke toestand, met het eigen candidate.end en de bewaarde continue/restarttraces. Er is geen grond om native velden of grenzen uit te breiden om een geaccepteerde stap te fabriceren. RESULT.json, assess_native55.py, TRACE_FIELDS.json en EVIDENCE.json bevatten de herhaalbare bron-/bestand-/context-/solveronderbouwing en verzegeling.
