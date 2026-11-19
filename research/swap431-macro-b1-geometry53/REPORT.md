# GEOMETRY53 - geometrieherstelcontract afgebakend

VlMpDyCp en SubsidCp moeten bij D2-rollback exact uit de geaccepteerde oorsprong worden hersteld. De minimale ontbrekende aanvulling bestaat uit twee tijdelijke eendimensionale originsnapshots op de bestaande MacroStateVar-grens. De huidige implementatie voldoet daar niet aan. Deze unit verandert alleen waarnemingen; zij implementeert geen geometriecorrectie.

## Eigendom en leesvolgorde

MPVOLUME(1) kiest de krimp-/bevochtigingsvertakking mede op basis van bestaande VlMpDyCp-waarden van de huidige en naburige cellen. Dit gebeurt voordat de array wordt overschreven. Bij theta>thetaM1-1e-8 en positieve scheurselectie wordt CritThet=theta_s; anders ThetCrMp. De loop loopt van boven naar beneden en leest voor de vorige cel de reeds bijgewerkte waarde. De waarnemingen bevestigen deze in-place volgorde; een simultane reconstructie uit een bevroren vector zou een ander algoritme zijn.

VlMpDyCp draagt dus geometrisch geheugen over. Zeer kleine positieve waarden tellen in de bestaande >0-test mee. De geaccepteerde MPVOLUME(2)-eindtoestand kan zulke waarden bevatten na de bestaande geordende domeinoptelling en statische-volumeaftrek. Hier wordt niet vastgesteld of die positieve-waardegrens fysisch gewijzigd zou moeten worden. Afkappen of een tolerantie toevoegen is geen rollbackreparatie binnen deze opdracht.

SubsidCp wordt tijdens de D2-MPVOLUME(1)-berekening opnieuw bepaald voordat het in de dynamische oppervlakterm wordt gebruikt; de oude SubsidCp is in deze berekening geen eigen vertakkingsinvoer. Het veld hoort wel bij de opgeslagen/native geometrie en heeft ook uitvoerrepresentatie. Het moet bij het teruggeven van de geaccepteerde toestand bij hetzelfde oorspronkelijke scheurvolume passen. Daarom omvat het contract beide arrays. Een nieuwe MPVOLUME-aanroep als rollback is geen exacte restauratie van de oorspronkelijke eindtoestand en kan opnieuw de geschiedenisafhankelijke tak uitvoeren.

## Dezelfde oorspronkelijke D2, O0/O2

Baseline RESTORE52 7eb323c228533b77d0ef8ba55d6589726b8adf58; prebuild observerbron799f5c1a1. Vier vooraf vastgelegde routes: O0/O2TRIAL-D2 en DIRECT-D2, na elkaar. Alleen de eerste bestaande provider van elke geselecteerde poging/retry is geobserveerd; geen extra fysieke evaluatie, proefstaat of contextselectie. De bronobserver wordt door de assessor teruggedraaid waarna alle Fortran-bronnen exact met RESTORE52 worden vergeleken.

De gehele oude niet-timingtekstuitvoer, oorspronkelijke1309commitprefix, origin, solverpogingen, sorptiehistorie, CONTACT47-cache, gecommitte nativecontext, cumulatieven en waterinventaris blijven exact gelijk aan RESTORE52. O0/O2 geven ook identieke nieuwe geometriegegevens. Bestaande residu-/inventaris-/retrycriteria zijn daarmee behouden; de reeds gekwalificeerde RESTORE52-sorptierestauratie blijft intact.

Na iedere van de drie echte TRIAL-afwijzingen verschillen nog48 VlMpDyCp-cellen en44 SubsidCp-cellen van de oorspronkelijke nativecontext. Het grootste scheurvolumeverschil is7.37257477290143e-18cm. De maximale SubsidCp-afwijking is per rollback1.0365630721875796e-5,3.86551825082293e-6 en1.2246465885823454e-6cm. Die waarden zijn exact beoordeeld, zonder nieuwe numerieke toleranties. De ledger blijft tot acceptatie gelijk en de positieve CONTACT47-proefbijdragen worden correct gewist.

## Andere interne geometrie ondanks gelijk solververvolg

Er zijn200 TRIAL- en150 DIRECT-receipts per optimalisatie: steeds50cellen voor de eerste provider van respectievelijk4 en3pogingen. De pre-loop VlMpDyCp/SubsidCp zijn exact terug te vinden in de bijbehorende context_begin. De actualiteit en de in-place buurleesvolgorde zijn gecontroleerd.

De eerste kleinere retry (TRIAL2) en de directe eerste kleinere poging (DIRECT1) hebben dezelfde theta, thetaM1, bodemparameters, tijd en dt, maar andere geometriehistorie. TRIAL2 kiest in44 krimpgeschikte cellen de ThetCrMp-tak. DIRECT1 kiest in43 daarvan de theta_s-tak. Het verschil in de berekende SubsidCp na de eerste A-loop bedraagt maximaal5.189705183289844e-4cm. Dit is een werkelijk geobserveerd verschil tussen beide routes, geen synthetische gevoeligheidsrun.

Een voorbeeld is cel1. De directe route leest voor zichzelf en zijn buur een positief VlMpDyCp van1.7347234759768071e-18cm; de postrollbackretry leest0. Bij gelijke theta=thetaM1=.39253963020037019, theta_s=.405 en ThetCrMp=.385 bepaalt dat de andere tak. SubsidCp na deze A-loop is respectievelijk.01261423980371902 en.012460369799629833cm.

Alle geobserveerde dynamische volumes na deze eerste A-loop zijn0. De volgende twee gepaarde retryframes zijn ook geometrisch gelijk. Het gehele bewaarde solver-/providervervolg, de uiteindelijke acceptatie in3iteraties en gecommitte toestand zijn gelijk gebleven. Dat toont functionele continuiteit in D2, maar sluit het eerdere vertakkingsverschil niet uit en bewijst geen algemene herberekenbaarheid of onschadelijkheid van kleine positieve waarden. Er is hier geen ontbrekend water aangetoond.

## Minimale toekomstige aanvulling

ROLLBACK_CONTRACT.md eist exact herstel van VlMpDyCp(1:NumNod) en SubsidCp(1:NumNod) uit twee tijdelijke oorsprongsbuffers, naast de bestaande water-/domeingeometrie en RESTORE52-historiebuffers. Gebruik dezelfde geaccepteerde save/restoregrens en tijd/dimensie/readycontrole. Geen cel-, positief-/nulmasker of proefafhankelijke uitzonderingen. Herstel voordat de volgende retry-snapshot of nieuwe provider wordt toegelaten.

De native serializer bevat beide velden al; geen nieuw native veld of formaat nodig. Geen wijziging van SHRINK, GeomFac, ThetCrMp, positieve-waardegrens, iteratievolgorde, CONTACT47, klok, solver of budgetregels. Alleen het bewaren en terugzetten van de bestaande oorsprongswaarden zou een minimale correctie zijn. Die correctie is hier nog niet uitgevoerd of gekwalificeerd.

## Rekentijd en grenzen

| Route | O0 seconden | O2 seconden |
|---|---:|---:|
| TRIAL-D2 |15.014638|7.696053|
| DIRECT-D2 |11.765068|8.582270|

Alle vier routes normaal en ongecensureerd onder hard20s per route, inclusief dezelfde oorspronkelijke prefix; terminale interne tijd blijft onder16s. De interne stoplogica,512owncommit-/4retrygrenzen en oorspronkelijke dt-/reductieregels zijn behouden. Geen herhaling voor gunstiger runtime of algemene snelheidsgarantie. Geen brede campagne.

Status: contract en eigendom afgebakend, huidige exacte geometrierestauratie FAIL. Volledige native toestand/overige afgeleide velden zijn hiermee niet automatisch geclassificeerd of hersteld. Geen nieuwe eigen herstart, volledige periode/BAL, ander krimp-/contactregime of canonieke promotie. B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS; B0/B1.12/canoniek/no-macrorelease onaangeraakt.

RESULT.json, TRACE_FIELDS.json en assess_geometry53.py bevatten de herhaalbare onderbouwing. EVIDENCE.json verzegelt bron, builds, identiteiten en alle onbewerkte receipts/contexten. Veilige vervolgstap is een afzonderlijk geautoriseerde minimale twee-arraygeometrierestauratie met dezelfde D2-toets.
