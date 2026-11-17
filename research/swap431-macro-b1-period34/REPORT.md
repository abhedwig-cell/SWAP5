# PERIOD34 — volledige volgende balansperiode niet behaald binnen budget

**De vaste periode 35797 → 35798 is niet voltooid en krijgt geen volledige BAL- of periodebalanskwalificatie.** De ongereduceerde kandidaat bereikt dagfractie 0,370783 en vraagt daarna fluxreductie. Een afzonderlijk vastgelegd O0/O2-paar dat de bestaande SWAP-reductieregel laat doorlopen bereikt respectievelijk 0,628003 en 0,677403, waarna de bestaande interne observatiegrens wordt geraakt. Alle vier processen stoppen normaal binnen twintig seconden.

Alle gemeten afwijzingen hebben nul actieve rang-één-aanvullingen op die head. De gezochte actieve afwijzing, rollback en directe kleinere retry blijven daarom ongekwalificeerd. De onvoltooide periode wordt niet alsnog als gesloten balans gerapporteerd.

## Basis en begrensde uitvoering

Baseline is TRAJECTORY33 `6406eacea39de3aa533a39669f59453fc7536ae0`; remote onderzoeksbranch is gelijk. Remote main blijft `be481cfb40f953e337116ef4a6dc5bc3ef64d4f7` en is niet gewijzigd of samengevoegd. Oorsprong is hetzelfde oorspronkelijke NEXT18-native checkpoint op t1900 = 35797, met volledige bestaande ledger en oorspronkelijke case-/kalendercontext.

De huidige kandidaat wordt continu vanaf die daggrens toegepast. Alle rekenformules, actuele residuoperator, rang-één-aanvulling, guards, MAXIT, toleranties, dtkeuze en oorspronkelijke reductieregels blijven gelijk aan TRAJECTORY33. Alle Fortranbestanden behalve de twee onderzoeksbestanden voor uitvoering/observatie zijn bytegelijk. `period_observation_only.patch` bewaart de eerste wijziging: de korte horizon van TRAJECTORY33 wordt de expliciet gevraagde vaste balansperiode, de bestaande interne zestiensecondenstop blijft behouden en de beginledger wordt nu ook ná de natuurlijke hostreset vastgelegd. De eindstop ligt ná de natuurlijke dagelijkse BAL-/CSV-uitvoer. Er is geen fysieke of outputformule gewijzigd.

De eerste twee STRICT-routes stoppen, zoals vooraf vastgelegd, vóór het oorspronkelijke fluxreductieverzoek verder wordt verwerkt. Toen beide hetzelfde verzoek bereikten, is vóór verdere uitvoering één aanvullende fase vastgelegd in SCOPE_REVISION.json en git: exact hetzelfde vaste periodevenster en dezelfde kandidaat, maar de oorspronkelijke host mag zijn eigen rollback en TimeControl(5)-reductie uitvoeren. `original_policy_observation.patch` verandert uitsluitend deze observatiestopgate. Label POLICY schakelt dat gedrag in. Er is geen andere reductiefactor, tolerantie of numerieke variant geprobeerd.

Deze tweede fase bestaat uit exact twee verdere routes. De eerste echte actieve afwijzing zou ook daar stoppen voor de conditionele herstelvergelijking. In totaal zijn vier primaire modelprocessen uitgevoerd; geen andere periode, horizonverruiming, extra herstart of brede campagne. De interne zestiensecondenstop laat marge voor export/afsluiting binnen de harde externe twintigsecondenlimiet.

## Gemeten uitkomsten

| Route | Seconden | Commits | Headpogingen | Afwijzingen, aanvulling inactief | Laatste gecommitteerde t1900 |
| --- | ---: | ---: | ---: | ---: | ---: |
| STRICT O0 | 2,704886 | 294 | 299 | 5 | 35797,370782734390 |
| STRICT O2 | 2,242220 | 294 | 299 | 5 | 35797,370782734390 |
| POLICY O0 | 16,638098 | 4243 | 4876 | 633 | 35797,628002865611 |
| POLICY O2 | 16,727864 | 5613 | 6594 | 981 | 35797,677402694862 |

De STRICT-uitkomsten zijn numeriek exact gelijk tussen O0/O2. Beide POLICY-routes delen **4243 bytegelijke commitbudgetten en 4876 gelijke headpogingen zonder rekentijdvelden**. De gemeenschappelijke inventaris- en Jacobiaantraces zijn eveneens bytegelijk. Hun eindtoestanden verschillen omdat O0/O2 bij dezelfde tijdlimiet verschillende aantallen commits bereiken; dat wordt niet als numerieke trajectafwijking aangemerkt.

De eerste 63 stappen en bijbehorende Jacobiaantraces zijn exact gelijk aan de gekwalificeerde korte TRAJECTORY33-route. De POLICY-aanlopen tot en met de eerste 299 headpogingen en 294 commits zijn bovendien exact gelijk aan de bewaarde STRICT-route. Het toelaten van het oorspronkelijke beleid verandert dus pas het gedrag ná de vastgelegde observatiestop.

In alle vier routes is de aanvulling 222 keer actief op 90 heads. De laatste actieve head is poging 125, beginnend op 35797,24800000005. Op geen van de latere afgewezen heads is de aanvulling actief. Dat lokaliseert het open probleem buiten de op die pogingen werkelijk actieve rang-één-tak; het bewijst nog geen oorzaak of nieuwe fysieke fout.

## Eerste concrete stagnatie in de eigen trajectorie

De eerste afwijzing is **poging 293**, na 292 commits, op t1900 **35797,370324351359**, met dt **0,0006875745394909628 dag**. Zij put de oorspronkelijke 30 iteraties uit; grootste residunode 52, actieve aanvullingen 0. De oorspronkelijke kleinere retry wordt vervolgens geaccepteerd.

Op t1900 35797,370782734390 volgen pogingen 296–299. Zij proberen achtereenvolgens dt 0,00022919151316365426, 0,00007639717105455142, 0,00002546572368485047 en de oorspronkelijke dtmin 0,00001 dag. De eerste drie weigeren na 30 iteraties; de laatste na de oorspronkelijke uitgebreide 60 iteraties en vraagt fluxreductie. Grootste residunodes zijn 51, 54, 55 en 56. Activering is telkens 0.

Met het oorspronkelijke beleid wordt de eerste gereduceerde commit op 35797,370924155744 geaccepteerd, met gebruikte dt 0,0001414213562373095 en factor 0,1. POLICY O0 bevat 143 gereduceerde commits, met minimumfactor 0,1. POLICY O2 bevat 370 gereduceerde commits en bereikt minimumfactor ongeveer 0,01. Deze resultaten mogen niet als volledige ongereduceerde fysische uitwisseling worden gepresenteerd.

INACTIVE_FAILURE_INDEX.json bewaart de exacte eerste afwijzingscontext en het latere eerste reductieverzoek als navigatie voor een eventuele afzonderlijke gerichte diagnose. Zij zijn geen actieve-afwijzingsgetuigen. Er is hier geen aanvullende diagnoseroute gestart.

## Canopybeginvoorraad en gemeten deelbalansen

De natuurlijke beginledger na de hostreset is op alle routes bytegelijk aan het oorspronkelijke NEXT18-bewijs. De canopybeginvoorraad SICINI is **0,0025926018136122326 cm**, exact gelijk aan de fysieke SICACT bij periodebegin. Beginwaarden van de cumulatieven zijn correct gereset; de macrobeginvoorraden stemmen overeen met de fysieke domeinvoorraden. Deze beginvoorraad-/resetcontrole is behaald.

Voor iedere geaccepteerde stap zijn matrix, vijf macrodomeinen, pond en canopy vergeleken met de primitieve geaccepteerde fluxintegralen. Alle stappen voldoen aan gebruikte dt maal het oorspronkelijke totale residucriterium; de hoogste fractie van die grens is 0,883289. De grootste afzonderlijke domeinintegratiefout is 4,367623748563129e-16 cm. De primitieve fluxsommen sluiten ook aan op de echte hostcumulatieven, met maximaal 6,67e-14 cm afrondingsverschil.

| Bereikt deeltraject | Voorraadafwijking, cm | Som dt × oorspronkelijk totaal residucriterium, cm |
| --- | ---: | ---: |
| STRICT O0/O2 | −1,151724794701270e-7 | 3,707827344907199e-6 |
| POLICY O0 | −2,241701433924881e-7 | 6,280028639306223e-6 |
| POLICY O2 | −1,934536796310837e-7 | 6,774026908224415e-6 |

Deze deelinventarissen sluiten binnen afronding aan op de som van de geaccepteerde stapresiduen. Bij STRICT bevat de laatste dump een afgewezen trial: de geaccepteerde voorraad wordt daarom berekend uit de opgeslagen thetm1/pondm1 en onveranderde gecommitteerde macro-/canopyvoorraad, niet uit de afgewezen trial-theta/pond. POLICY stopt na een echte commit en gebruikt de fysieke eindvoorraad rechtstreeks.

Geen route bereikt t1900 = 35798. Alle BAL-bestanden bevatten slechts de header van 195 bytes; er is geen natuurlijke periode-eindrecord met Initial/Final/Change of fluxcomponenten geschreven. Daarom zijn **volledige periodebalans, volledige BAL-uitvoer en de canopycorrectie op het periode-eindpunt niet gekwalificeerd**. De valide beginvoorraad en deelinventaris vervangen dat ontbrekende eindbewijs niet.

## Bewijs, beperkingen en besluit

Status: `INCOMPLETE_BUDGET_LIMITED_NO_FULL_PERIOD_BAL_PASS`. Alle vier processen eindigen normaal, ongecensureerd en binnen twintig seconden; de POLICY-waarnemingen zijn inhoudelijk budgetbegrensd en onvoltooid. De bekende IEEE_DENORMAL-melding is in de vier ruwe uitvoerbestanden bewaard; volledige IEEE-statusidentiteit wordt niet geclaimd.

De bron-/buildidentiteiten en ruwe uitvoer van beide fasen zijn behouden. De oorspronkelijke STRICT-executables zijn bij het bouwen van de POLICY-fase vervangen. Hun exacte bronpostimages zijn teruggelegd in strict_source en gecontroleerd tegen beide oorspronkelijke buildidentiteiten; compile/linklogs, executable-hashes en uitvoer blijven behouden. Het archief bevat de daadwerkelijke definitieve POLICY-binaryclosure. Er wordt geen behoud van de oude STRICT-binaries geclaimd; zie STRICT_SOURCE_IDENTITY.json.

B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`. De korte ongereduceerde voortgang uit TRAJECTORY33 is bevestigd en doorgetrokken tot het reductieverzoek, maar een volledige ongereduceerde periode is niet aangetoond. Zelfs met de oorspronkelijke reductiebenadering is deze volledige periode binnen het bestaande observatiebudget niet voltooid. Er is geen actieve afwijzing gevonden, dus geen conditionele TRIAL/DIRECT-vergelijking gestart en geen actieve rollback-PASS toegekend. De eigen native herstart wordt evenmin als vervolg automatisch gestart zonder voltooide periode.

De eerstvolgende onderscheidende diagnose ligt bij de concrete **inactieve afwijzing 293 in de eigen kandidaattraj­ectie**, niet bij nog meer willekeurig geselecteerde oude weigeringen. Een oorzaak of correctie is deze ronde niet onderzocht of aangenomen. Geen nieuwe campagne, budgetverruiming, gewijzigde fysica of solverregel. B0, B1.12, canonical en macroporiënvrije releasebasis zijn ongewijzigd.

STATUS, RESULT, SCOPE_REVISION, TRACE_FIELDS, INACTIVE_FAILURE_INDEX, bronpatches, exacte begin-/deeltoestanden, raw traces en de geverifieerde PERIOD34_EVIDENCE.zip bewaren de reproduceerbare onderzoeksuitkomst. assess_period34.py leest uitsluitend bestaande bestanden en voert geen modellen uit. Geen officiële promotie.
