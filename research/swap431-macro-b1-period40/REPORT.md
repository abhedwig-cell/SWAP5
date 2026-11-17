# PERIOD40: volledige oorspronkelijke periode binnen vaste budgetten getoetst

**De volledige periodebalans is nog niet gekwalificeerd.** Het eigen gecorrigeerde traject vanaf dezelfde oorspronkelijke checkpoint bereikt de eindgrens t1900=35798 niet binnen de behouden budgetten. De ongeschaalde proef stopt bij een reductieverzoek op 35797,487567908756. De aanvullende proef met de oorspronkelijke reductieregeling toegestaan stopt normaal op de interne zestiensecondenlimiet, op 35797,679026896942 (O0) en 35797,690567740035 (O2). Geen route bereikt de natuurlijke BAL-uitvoer; alle BAL-bestanden bevatten alleen de kop van 195 bytes.

De complete eerder gekwalificeerde korte aanloop, de gemeenschappelijke O0/O2-voortzetting en de onafhankelijke deelbalansen zijn wel behouden en gecontroleerd. Fysica, invoer, correctievoorwaarden, toleranties, MAXIT, tijdstap- en reductieregels zijn niet gewijzigd.

## Vastgelegde scope en bewijsidentiteit

Basis is TRAJECTORY39 `b7bfd2715188757bac81cfdba1043fc7ebfd0743`. Dezelfde native checkpoint op t1900=35797 heeft SHA-256 `21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16`. De gevraagde oorspronkelijke periode blijft 35797→35798; de nieuwe correctie staat vanaf de eerste kopberekening beschikbaar onder haar bestaande voorwaarden.

De eerste bronvastlegging vóór builds en modelruns is `805177a05`: alleen de korte observatiegrens en de 512-commitcap van TRAJECTORY39 zijn verwijderd. De zestiensecondenstop en harde twintigsecondenlimiet zijn behouden. De bestaande daggrenscontrole zou pas na de oorspronkelijke BAL-/CSV-uitvoer eindigen.

Na het identieke eerste reductieverzoek zijn beide ongeschaalde bronnen, identiteiten, modeluitvoer en werkelijke buildclosures bewaard. In `ad015824e` is vóór de aanvullende builds vastgelegd dat twee routes dezelfde vaste periode met de oorspronkelijke reductieregeling mogen doorlopen, zoals de eerdere PERIOD34-proef. Alleen de observatiestop op een reductieverzoek is daarvoor conditioneel uitgezet. Het oorspronkelijke hostherstel en TimeControl(5) bepalen de reductie; er zijn geen factoren toegevoegd of veranderd. Totaal vier routes, geen andere context, numerieke variant, extra periode of herstart. De strikte binaries zijn daadwerkelijk bewaard onder `native/STRICT/O0` en `native/STRICT/O2`, met `strict_source/` en `STRICT_*_IDENTITY.json`.

Alle Fortran-bronnen buiten de onderzoeksdriver `soilwater_native.f90` zijn bytegelijk aan TRAJECTORY39. `OBSERVATION_CHANGES.patch` en `ORIGINAL_POLICY_OBSERVATION.patch` leggen de kleine observatiewijzigingen vast.

## Uitkomsten

| Route | Commits | Pogingen | Laatste gecommitteerde t1900 | Procesduur (s) |
|---|---:|---:|---:|---:|
| O0 ongeschaald | 360 | 366 | 35797,487567908756 | 1,870809 |
| O2 ongeschaald | 360 | 366 | 35797,487567908756 | 1,313486 |
| O0 oorspronkelijke reductieregeling | 4499 | 4964 | 35797,679026896942 | 16,567307 |
| O2 oorspronkelijke reductieregeling | 4686 | 5317 | 35797,690567740035 | 16,360450 |

Alle processen eindigen normaal, zonder externe censurering en onder twintig seconden per route. De beleidsroutes eindigen na de interne observatiestop op een echte geaccepteerde hostcommit. Hun verschillende eindpunten horen bij een tijdgestuurde stop en zijn geen numerieke O0/O2-afwijking: de eerste 4499 commits en 4964 pogingregels zijn exact gelijk, met uitzondering van rekentijdvelden. Ook de gemeenschappelijke Jacobiaan- en voorraadtraces zijn exact gelijk.

De eerste 287 commits van alle vier routes zijn exact gelijk aan het volledige gekwalificeerde TRAJECTORY39-segment. De beleidsroutes herhalen vervolgens de eerste 366 pogingregels en 360 budgetregels van de ongeschaalde routes exact, inclusief het eerste reductieverzoek. De oorspronkelijke post-reset begincontext en canopyvoorraad zijn ongewijzigd.

Tot poging 324 vinden 252 nieuwe gecorrigeerde Jacobiaaniteraties plaats, naast de 222 eerdere actieve rang-één-iteraties; de activiteitsteller telt iedere Jacobiaan éénmaal, dus samen 474. De latere afwijzingen vallen alle buiten beide actieve aanvullingen. De nieuwe correctie wordt bij fluxreductie door haar bestaande uitvoeringsvoorwaarden uitgesloten; de bestaande terugvaltak blijft verantwoordelijk. Er wordt geen algemene inzetbaarheid in die uitgesloten toestand geclaimd.

## Eerste nieuwe begrenzing van het traject

De eerste echte ongeschaalde afwijzing van dit eigen traject is poging 357, vanaf t1900=35797,487000006880 en dt=0,001000001146167051 dag. Het grootste residu is 0,02571625908888784 op node 47. De nieuwe correctie is daar niet actief. Na verdere oorspronkelijke kleinere retries vraagt poging 366 op 35797,487567908756 reductie aan. Dit is een nieuwe eigen kandidaatcontext, geen hernummering van de oude PERIOD34-poging 293 en geen geforceerde afwijzing.

De ongeschaalde route telt zes afwijzingen. In de beleidsroutes zijn er 465 (O0) en 631 (O2); 135 respectievelijk 176 commits gebruiken fluxreductie, met minimale factor 0,1. Het tijdsbudget wordt dus niet in een voltooid oorspronkelijk ongeschaald traject omgezet. Deze ronde voert geen extra diagnose of correctie van node 47 uit. `NEXT_CONTEXT_INDEX.json` bewaart alleen de exacte coördinaten voor eventueel later gericht werk.

## Deelbalansen en cumulatieve uitvoer

Alle daadwerkelijk geaccepteerde stappen hebben een verse V1-certificatie en voldoen aan de bestaande lokale en totale residucriteria. De onafhankelijke voorraadtoetsen blijven binnen dt maal de oorspronkelijke totale residugrens. De grootste fout/grens-verhouding is 0,760670 in de ongeschaalde routes, 0,865533 in O0 met reductie en 0,977499 in O2 met reductie. Dit zijn deeltrajectkwalificaties, geen bewijs van volledige periodeafronding.

| Segment | Onafhankelijke sluitfout (cm) | Som bestaande stapgrenzen (cm) |
|---|---:|---:|
| Ongeschaald, beide optimalisaties | -1,2667296461765787e-7 | 4,8756790884255495e-6 |
| O0 met oorspronkelijke reductie | -1,588410979413979e-7 | 6,790268950809978e-6 |
| O2 met oorspronkelijke reductie | -1,286139413858578e-7 | 6,905677384202463e-6 |

Canopy is meegenomen, met beginvoorraad SICACT=0,0025926018136122326 cm. Matrixfracties en laagdikten zijn aan begin en eind gelijk. In de strikte routes wordt de fysieke voorraad na rollback van het laatste reductieverzoek gebruikt, niet de afgewezen proefkop; theta en h komen overeen met de opgeslagen thetm1 en hm1. Er is geen claim van volledige onmiddellijke bytegelijkheid van alle hulpvelden.

De vijf domeinbalansen sluiten afzonderlijk. De gecontroleerde primitieve ledgerincrementen gebruiken de werkelijke **post-reset** basis `ledger_begin` en komen overeen met de integralen van alle gecommitteerde budgetregels; de grootste afwijking is circa 1,28e-13 cm, binnen de bestaande verificatiegrens 1e-12 cm. De ledger vóór de oorspronkelijke dagstartreset wordt niet als huidige periode-integraal gebruikt.

De analysecontrole van anders geordende sommen hanteert een ULP-grens voor de rekenkundige reconstructie (gemeten maximaal 3,47e-18 cm). Dit verandert geen fysische acceptatiegrens. Een vroege uitvoeringsuitsluiting met code -1 keert vóór de providerstempelcontrole terug; een stempelwaarde nul op die uitgesloten tak wordt niet als een toegepaste correctie met verouderde gegevens geïnterpreteerd. De daadwerkelijk gebruikte nieuwe correcties hebben geldige actuele stempels.

## Status en bewaring

De uitkomst is `INCOMPLETE_BUDGET_LIMITED_NO_FULL_PERIOD_BAL_PASS`. Er is geen volledige oorspronkelijke periodebalans, natuurlijke BAL-inhoud of nieuwe native-herstartkwalificatie. Er zijn geen verdere routes gestart en geen budgetten verruimd. Eerdere lokale correctie-, rollback- en korte trajectbewijzen blijven beperkt tot hun gekwalificeerde contexten. B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`; geen canonieke toelating. B0, B1.12, canonieke SWAP5 en de no-macrorelease zijn niet gewijzigd.

`assess_period40.py` analyseert uitsluitend opgeslagen uitvoer. `RESULT.json`, `CONTRACT.json`, `TRACE_FIELDS.json` en de ruwe O0/O2-uitvoer dragen de controleerbare claims. `PERIOD40_EVIDENCE.zip` bevat bron, ruwe uitvoer en beide werkelijke buildclosures, inclusief de strikte binaries; `EVIDENCE.json` bindt checkpoint en SHA-256. Ieder opgenomen bestand wordt streamend tegen het manifest geverifieerd.
