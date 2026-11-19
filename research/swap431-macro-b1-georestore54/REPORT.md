# GEORESTORE54 - exact geometrieherstel en directe kleinere retry

De minimale GEOMETRY53-implementatie slaagt in dezelfde oorspronkelijke D2-context met O0/O2. VlMpDyCp en SubsidCp herstellen na iedere echte afwijzing exact naar hun oorsprong. Het kleinere vervolg heeft nu ook dezelfde interne geometrievertakkingen als de directe kleinere route: de43 verschillen uit GEOMETRY53 zijn verdwenen.

## Minimale wijziging

Alleen MacroStateVar is gewijzigd tegen GEOMETRY53. Twee lokale saved vectors, dynamic_origin54 en subsidence_origin54, bewaren VlMpDyCp(1:NumNod) en SubsidCp(1:NumNod) bij de bestaande MacroStateVar(1)-grens, naast de RESTORE52-sorptie-/watergeometrie. MacroStateVar(2) zet beide exact terug binnen dezelfde bestaande kandidaatgate en tijd/dimensie/readycontrole. De save gebeurt ook voor kandidaatactivatie, zodat de eerste oorspronkelijke D2-poging al een geldige snapshot heeft. Met repair43false houdt de originele prefix zijn eerdere rollbackgedrag.

Er is geen speciale node, domein, poging, teken-/nulmasker of afkapgrens. De positieve oorsprongwaarden, inclusief1.7347234759768071e-18cm in cel1, blijven exact behouden. Er komt geen extra MPVOLUME-aanroep of reconstructie uit actuele theta. SHRINK, GeomFac, ThetCrMp, de >0-geheugentest, de oplopende in-place volgorde en de MPVOLUME(2)-eindbewerking zijn ongewijzigd. Het nieuwe geheugen is tijdelijke transactiescratch; beide fysieke velden bestaan al in het native formaat. Geen nieuw persistent veld of native formaat.

RESTORE52-sorptieherstel en de CONTACT47-cache-invalidering zijn behouden. Klok, fysieke flux-/geometriewetten en derivatieven, solver, guards, toleranties, MAXIT, dt-/reductie-/budgetregels zijn niet gewijzigd. IMPLEMENTATION.patch toont de gehele bronwijziging; de assessor keert die terug en vergelijkt alle bronnen exact met GEOMETRY53.

## Dezelfde oorspronkelijke D2

Baseline GEOMETRY53 7c4e746cb53b65213f4ab1586009c7ce6973bae3; prebuild broncheckpoint1a44f9e97. De oorspronkelijke SELECT28-D2 (oude3066), t35797.290420649493,dt2.8284271247461902e-4, is gebruikt. De volledige1309commitprefix, origin, nativecontext en ledger zijn bytegelijk aan de ouder. Native35797 SHA256 21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16. Geen nieuwe contextselectie, forcing of bevroren proefstaat.

TRIAL wijst drie keer werkelijk af bij MAXIT30, zonder reductie, met119/68/52 positieve CONTACT47-providerbijdragen. Na alle drie rollbacks en de twee DIRECT-rollbacks zijn beide volledige geometriearrays en de volledige referentie-/beginsorptiviteits-/klokarrays exact gelijk aan de oorsprong. AwlCorFac blijft gelijk. De volgende retry begint opnieuw met die exacte oorsprongswaarden, zodat geen afgewezen geometrie opnieuw als geldige snapshot wordt opgeslagen. CONTACT47 ready/mask/increment zijn na rollback ongeldig en nul; geen afgewezen increment of ledgerbijdrage wordt gecommit.

In de eerste TRIAL-rollback is de volledige gemeten native contextdump nu ook bytegelijk aan context_origin. In latere rollbacks verschilt daarvan alleen dt, door de oorspronkelijke TimeControl5-verkleining. Dit is een concrete veld-/contextdumpkwalificatie in D2; geen algemene claim over alle niet-geserialiseerde werkvelden of een complete native bestands-/herstartoperatie.

## Directe kleinere route en geometrie

De eerste kleinere dt is9.4280904158206339e-5. DIRECT begint vanuit dezelfde oorspronkelijke toestand met precies die oorspronkelijke TimeControl5-verkleining. TRIAL-pogingen2..4 en DIRECT1..3 zijn gelijk in alle solvertraces en providerreceipts, na normalisatie van alleen de pogingindex.

Ook de200 TRIAL- en150 DIRECT-geometriereceipts van de eerste bestaande provider per poging zijn nu gelijk over het volledige kleinere suffix. Alle beginarrays stemmen overeen met hun oorsprong; de actuele vorige-cellezing stemt overeen met de reeds bijgewerkte vorige rij. In ieder eerste-providerframe kiezen43 cellen de bestaande theta_s-bevochtigingstak. De eerste kleinere retry heeft0 vertakkingsverschillen en0 Subsidence-uitvoerverschil tegenover DIRECT, waar GEOMETRY53 nog43 verschillen en maximaal5.189705183289844e-4cm liet zien. De geometriewet is hiervoor niet aangepast; de juiste invoerhistorie is hersteld.

De vierde TRIAL-/derdeDIRECT-poging accepteert vers in3iteraties bij dt1.0475656017578482e-5, maxres1.5796352162943117e-7. CONTACT47 is op die laatste kleine poging niet actief. De toets kwalificeert het veilig verwerpen van positieve eerdere proefbijdragen en het correcte daaropvolgende herstel en verloop.

## Waterinventaris en O0/O2

Geaccepteerde en gecommitte nativecontext, inventaris, ledger en step_budget zijn bytegelijk tussen TRIAL en DIRECT en gelijk aan de bewaarde ouderuitkomst. Beide eindigen op35797.290431125148. De onafhankelijke inventarisfout is1.154971428410961e-11cm binnen de bestaande1.0475656017578482e-10cm-grens. Per-domeinbalansen en primitieve cumulatieve incrementen voldoen; maximale ledgerincrementafwijking6.31e-17cm. Er is geen nieuwe waterbron of voorraadcorrectie toegepast.

O0/O2 geven dezelfde niet-timingtekstuitvoer, inclusief herstelcontexten, geometrieframes en alle huidige diagnosevelden. Runtime/IEEE-stderr is geen basis voor fysieke identiteit.

| Route | O0 seconden | O2 seconden |
|---|---:|---:|
| TRIAL-D2 |15.089708|11.500231|
| DIRECT-D2 |14.981830|9.363489|

Vier routes, allemaal normaal en ongecensureerd onder hard20s per route, inclusief oorspronkelijke prefix. Ook de terminale interne tijd blijft onder16s. Bestaande interne stoplogica/terminale acceptatieprioriteit,512owncommit-/4retrygrenzen zijn behouden. Routes na elkaar, geen timingherhaling, extra provider, nieuwe context of brede campagne. Geen algemene snelheidsgarantie.

## Kwalificatiegrens

Het afgebakende GEOMETRY53-contract is geimplementeerd en gesloten voor dezelfde oorspronkelijke D2-transactie. De eerdere beperkingen op exacte sorptie- en deze twee geometrievelden zijn hiervoor opgelost. De overige flux-/boundary-/eventwerkgegevens kunnen na rollback nog verschillen en worden onder het bestaande verse-providercontract herberekend. Er is geen nieuwe eigen nativeherstart, volledige-periode/BAL, ander krimp-/contactregime of algemene solver-/snapshottoelating getest.

B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS, geen promotie. B0/B1.12/canoniek/no-macrorelease onaangeraakt. RESULT.json, TRACE_FIELDS.json en assess_georestore54.py bevatten de herhaalbare onderbouwing; EVIDENCE.json bindt het verzegelde bron-/build-/uitvoerarchief aan de resultaatcheckpoint.
