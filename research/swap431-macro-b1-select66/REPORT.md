# SWAP431-MACRO-B1-SELECT66

## Uitkomst

Geen echte stapafwijzing met actieve V-aanvulling gevonden in de acht vooraf begrensde nieuwe voorstellen binnen het resterende D2-interval van SELECT65. Vier voorstellen accepteren met actieve V; vier wijzen werkelijk af, maar gebruiken uitsluitend W. De V-rollback/directe-kleinere-retry-gate blijft open. Geen promotie van de B1-kandidaat.

| O0-voorstel | dt (dag) | eerste poging | iteraties | geldig W / V |
|---|---:|---|---:|---:|
| SELECT1 | 2.0905859812354799e-05 | acceptatie | 13 | 9 / 2 |
| SELECT2 | 2.0907196642437215e-05 | afwijzing | 30 | 25 / 0 |
| SELECT3 | 2.0906528227396007e-05 | afwijzing | 30 | 25 / 0 |
| SELECT4 | 2.0906194019875401e-05 | acceptatie | 13 | 9 / 2 |
| SELECT5 | 2.0906361123635704e-05 | afwijzing | 30 | 25 / 0 |
| SELECT6 | 2.0906277571755551e-05 | acceptatie | 13 | 9 / 2 |
| SELECT7 | 2.0906319347695626e-05 | acceptatie | 13 | 9 / 2 |
| SELECT8 | 2.0906340235665663e-05 | afwijzing | 30 | 25 / 0 |

Alle vier afwijzingen bereiken de bestaande grens van 30 iteraties met 25 geldige W-aanvullingen en vijf bewaakte terugvallen. Geen V-aanvulling in de afgewezen poging. Hun automatische kleinere retry op dtmin=1e-5 accepteert met drie iteraties W/V/V, een verse residucheck en één hostcommit. V in die latere retry maakt de eerste poging geen V-afwijzing.

## O0/O2, herstel en inventaris

SELECT8 is met O2 herhaald. Alle fysieke teksttraces, ledgers, oorsprongbuffers en het native vervolgpacket zijn bytegelijk aan O0; de pogingstrace is exact gelijk na uitsluitend weglating van de verstreken rekentijd. Beide optimalisaties wijzen de eerste poging af en accepteren de kleinere retry.

Bij alle onderzochte echte W-afwijzingen herstelt de volledige vastgelegde fysieke context vóór retry exact, met alleen de bedoelde controllerwijzigingen dt en fldtmin. De ledger herstelt bytegelijk. Dit herstelbewijs geldt voor W-afwijzing. Er is geen onafhankelijke directe kleinere retry gestart: een echte V-afwijzing als vereist vertrekpunt ontbreekt. Daarmee is de gevraagde V-kwalificatie niet bereikt.

Elke geaccepteerde hoststap voldoet aan de bestaande lokale en totale residucriteria, met FrReduQ=1 en IDecMpRat=0. De waterinventaris is onafhankelijk herberekend uit matrixvocht, macrocompartimenten, pond, canopy en externe stapfluxen; alle negen routes voldoen aan de bestaande dt maal totaalcriterium-grens. Domeinvoorraden sluiten binnen 1e-14 cm. RESULT.json bevat de afzonderlijke foutmaten.

## Grenzen en betekenis

Negen normale, ongecensureerde modelroutes: acht O0-selecties en één O2-bevestiging; maximaal 1.455 seconden per route. De externe limiet blijft twintig seconden, de bestaande interne limiet zestien seconden en alle overige budgetregels blijven behouden. Exact dezelfde oorspronkelijke NATIVE55 D2-checkpoint, forcing, klok en historie; dezelfde verzegelde REJECT64-binaries. Geen nieuwe compilatie, numerieke patch of wijziging van fysica, solvercriteria, MAXIT, bewaking of dtmin. De runner is bytegelijk aan SELECT65.

Het resterende ononderzochte interval is [2.0906319347695626e-5, 2.0906340235665663e-5] dag, 256 maal smaller dan bij aanvang van SELECT66. Dat is een empirisch bracket voor de onderzochte voorstellen, geen bewezen monotone of unieke grens. Deze negatieve selectie bewijst niet dat een V-afwijzing nergens in het interval kan optreden. Geen verdere selectie binnen deze werkunit; geen brede campagne.

## Bewijs en herstel

CONTRACT.md is vóór modeluitvoering vastgelegd. SELECTION_PROGRESS.json en afzonderlijke Git-checkpoints bewaren elk voorstel en de daaropvolgende selectie. `python -B research/swap431-macro-b1-select66/assess_select66.py` controleert opgeslagen ruwe bewijzen zonder modellen te starten, inclusief exacte middelpunten en bron-/binaryidentiteit. SELECTION_AUDIT.csv bevat alle oorspronkelijke en retry-pogingen.

SELECT66_EVIDENCE.zip bewaart alle volledige casekopieën, invoer, ruwe uitvoer en gebruikte buildsluiting; ieder lid is gecontroleerd met SHA-256. EVIDENCE.json registreert archiefidentiteit en de geërfde SELECT65-identiteit. Na controle tegen het centrale Git-object en push mogen de reproduceerbare casekopieën volgens het opslagbeleid verdwijnen. RESOURCE_PATHS.json blijft provenance, geen garantie dat tijdelijke paden blijven bestaan.
