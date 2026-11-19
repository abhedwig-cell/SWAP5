# REJECT64 — gerichte selectie voor afwijzing met actieve V-tak

Er is binnen de vooraf begrensde selectie geen echte stapafwijzing met actieve V-aanvulling verkregen. De drie oorspronkelijke D2-voorstellen worden alle geaccepteerd met actieve V; O2 bevestigt het laatste voorstel exact. Daardoor zijn de gevraagde V-rollback en vergelijking met een directe kleinere retry in deze unit NIET gekwalificeerd. Een afgewezen lijnproef of de oudere W-stapafwijzing wordt niet als V-stapafwijzing gepresenteerd.

## Afgebakende selectie

Baseline COMBINED63 caabd53a52a6e919fbcaf213d6af1c0a2ac4a3a5; preregistratie03b300da0, uitvoer-/resourcecheckpoint9bbe40637. De oorspronkelijke grote stap2,0951312035156963e-5 faalt in COMBINED63, maar gebruikt op die poging uitsluitend W. De normale dtmin-retry1e-5 convergeert met W/V/V.

Om binnen dezelfde fysieke beginstaat een echte V-afwijzing te zoeken, zijn maximaal drie rekenkundige middenvoorstellen tussen deze bekende eindpunten toegestaan. Acceptatie verplaatst alleen het onderste selectie-eindpunt; de oorspronkelijke echte TimeControl-, afwijzings-, iteratie-, guard- en reductieregels blijven intact. De keuze van de eerste voorgestelde dt is een expliciete harnessinput, geen nieuwe controller. Geen veranderingen van heads, sorptiehistorie, fysica, tolerantie, MAXIT, dtmin, backtracking, numerieke fluxreductie of budget.

Alle routes starten vers uit exact dezelfde originele eigen NATIVE55-checkpoint, SHA59988fe0728bc51006085bbc957afc16ddf50b23a5cbb644228716dff743748e. Alle initiële native-contextvelden behalve de voorgestelde dt zijn byte/numeriek gelijk aan COMBINED63; ledger en fysieke historie zijn gelijk. Alleen de startvoorstel-wrapper is gewijzigd. Alle overige Fortran-bronnen, inclusief de gehele COMBINED63-Jacobiaanaanvulling/payload/guards en de echte retry/hostcommitfuncties, zijn byte-identiek. Alleen soilwater.o opnieuw gebouwd op de geverifieerde COMBINED63-closure.

## Werkelijke resultaten

| Route | Voorgestelde dt [dag] | Iteraties | Actieve V-aanvullingen | Eind-Fmax [cm/dag] | Modeltijd |
|---|---:|---:|---:|---:|---:|
|O0 SELECT1|1,547565601757848e-5|16|1|9,583209338945992e-7|0,837 s|
|O0 SELECT2|1,8213484026367723e-5|12|2|5,736887506192778e-8|0,592 s|
|O0 SELECT3|1,9582398030762345e-5|17|2|4,4268208328202e-8|0,891 s|
|O2 SELECT3|1,9582398030762345e-5|17|2|4,4268208328202e-8|0,948 s|

Alle vier routes zijn normaal en ongecensureerd, returncode0, onder20 s per route. Oorspronkelijke interne16s/512commit/4retrygrenzen behouden. De bestaande IEEE_DENORMAL-melding is bewaard. Geen providerperturbaties of verdere voorstellen uitgevoerd.

Iedere route heeft precies één poging, een geslaagde fresh residualcontrole en één hostcommit. FrReduQ1/IDec0; de lokale1e-6 en totale1e-5-residucriteria zijn werkelijk gehaald. Er is geen afwijzingsvlag, geen tweede poging, geen herstelde gefaalde V-proefstaat en geen automatische kleinere retry.

SELECT3 is onderling O0/O2 byte-identiek in alle niet-timing-tekstuitvoer en follow.end; pogingregistraties zijn gelijk na uitsluitend weglaten van rekentijd. Dit is de O0/O2-bevestiging van het laatste geselecteerde geval, geen impliciete O2-kwalificatie van de twee eerdere O0-selecties.

De bestaande hostinventarisfouten zijn1,0183533070558487e-10,7,171011545766719e-12 en5,949373282635915e-12 cm; zij voldoen ieder aan de oorspronkelijke dt*CritDevBalTot-grens. Ook het eerste geval met een relatief groter residu is volgens de bestaande criteria werkelijk geaccepteerd. Er is geen extra criterium toegevoegd om het alsnog af te wijzen. Deze controle is behoud van de bestaande hostreceipts, geen nieuwe onafhankelijke rollback-/retrybalanskwalificatie.

## Betekenis van de negatieve bevinding

De noodzakelijke uitgangsvoorwaarde voor de gevraagde proef ontbreekt: een volledige stap moet werkelijk worden afgewezen nadat een geldige V-aanvulling is gebruikt. Actieve V tijdens een geaccepteerde stap voldoet daar niet aan. Daarom is de conditioneel geplande directe kleinere-retryvergelijking niet uitgevoerd en wordt zij niet PASS genoemd. De oudere grotere W-afwijzing uit COMBINED63 is eveneens onvoldoende voor die V-claim.

Het selectieplafond van drie voorstellen is gehandhaafd. Tussen1,9582398030762345e-5 (hier geaccepteerd met V) en2,0951312035156963e-5 (eerder geweigerd met uitsluitend W) ligt nog een niet onderzocht interval. De huidige uitkomst bewijst niet dat daarin geen V-afwijzing bestaat. Iteratiegedrag wordt niet als monotone dt-functie aangenomen en geen drempelgrens is bewezen. Een eventuele volgende selectie moet expliciet tot dit resterende oorspronkelijke interval worden begrensd en de bestaande criteria behouden. Geen brede campagne gestart.

B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS. Geen uitbreiding van fysieke/numerieke toelating, canonieke productie/Status-A, herstart-, rollback-, directe-retry- of periodebalansclaim.

## Opslag en herstel

Het gedeelde opslagbeleid is gelezen; de huidige chat is gestart en de eigen werkcheckout en gebruikte oorspronkelijke invoer zijn beschermd. De preview heeft geen actieve andere task vrijgegeven. Nieuwe build- en casekopieën zijn via tools/storage/cleanup.py gealloceerd onder de toegewezen buiten-OneDrive-werkmap; provenance staat in RESOURCE_PATHS.json. PYTHONDONTWRITEBYTECODE is gebruikt.

Alle unieke bronnen, negatieve selectie-uitkomsten, raw routes, input- en buildclosure worden vóór vrijgave in het versiegebonden wetenschappelijke archief behouden. Het archief bevat ook de volledige werkelijk gebruikte casekopieën, zodat opruiming niet op regeneratie van unieke ruwe resultaten berust. Na centrale Git-SHA-verificatie worden alleen de eigen gereproduceerde resources volgens de gedeelde tool vrijgegeven/opgeruimd; rapport/herstelref blijven in de toolregistry. Geen onbekende oude mappen of andere chats vrijgegeven.

Herstel via STATUS/RESULT.json, CONTRACT.md, SELECTION_PROGRESS.json, SELECTION_AUDIT.csv, HARNESS.patch, RESOURCE_PATHS.json en CODEX_FOLLOWUP.md. assess_reject64.py start0modellen. EVIDENCE.json bevat streaming-SHA/membercontrole en dependency naar COMBINED63.
