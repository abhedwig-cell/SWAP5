# TRAJECTORY39: kort eigen gecorrigeerd traject voorbij de oorspronkelijke context 297

**Geslaagd met O0 en O2.** Eén eigen continu traject vanaf de oorspronkelijke native checkpoint t1900=35797 bereikt t1900=35797,372198904130, voorbij de oorspronkelijke context van poging 297 op 35797,370782734390. Beide optimalisaties leveren 287 commits, zonder afwijzing of fluxreductie, met bytegelijke numerieke uitvoer buiten de rekentijdvelden. Alle verse acceptatiecriteria, stapvoorraden, de totale waterinventaris en gecontroleerde cumulatieve incrementen voldoen aan de bestaande grenzen.

## Contract en bronidentiteit

Basis is ACTIVE38 `12aa44d1527b0c99fedccda149b926c25a931edb`. Bron en observatiecontract zijn vóór beide builds en modelroutes vastgelegd in `80fca3ece`. De gebruikte native checkpoint heeft SHA-256 `21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16`.

De correctie staat vóór de eerste kopberekening aan en blijft onderweg beschikbaar. De ongewijzigde toepassingsvoorwaarden kiezen tussen de nieuwe band-/voorraadcorrectie en de bestaande rang-één-/tridiagonale tak. Er wordt geen oude aanloop aan een nieuw gekozen eindcontext geplakt. De enige gewijzigde Fortran-bron ten opzichte van ACTIVE38 is de onderzoeksdriver in `soilwater_native.f90`; numerieke coëfficiënten, provider, fysica, invoer, toleranties, MAXIT, tijdstap- en fluxreductieregels zijn ongewijzigd. Zie `DRIVER_CHANGES.patch` en `CONTRACT.json`.

Vooraf vastgelegde stop: de eerste volledige commit op of na 35797,372, met daarnaast de bestaande interne zestiensecondenstop, maximaal 512 commits en een harde subprocesslimiet van twintig seconden per route. Een gewone ongeschaalde afwijzing zou het oorspronkelijke hostherstel en TimeControl(5) volgen; bij een reductieverzoek stopt de observatie. Er is geen tijdstap afgekapt om precies op de observatiegrens te landen.

## Het eigen traject

| Grootheid | O0 | O2 |
|---|---:|---:|
| Rekentijd route (s) | 1,287862 | 0,965428 |
| Kopberekeningen / commits | 287 / 287 | gelijk |
| Afwijzingen / fluxreducties | 0 / 0 | gelijk |
| Newton-iteraties totaal | 1929 | gelijk |
| Iteraties per geaccepteerde stap | 2–19 | gelijk |
| Nieuwe gecorrigeerde iteraties / koppen | 112 / 28 | gelijk |
| Bestaande actieve rang-één-iteraties | 222 | gelijk |
| Grootste eindresidu | 9,978354991464072e-7 | gelijk |
| Grootste absolute somresidu | 7,6067016763681604e-6 | gelijk |

De nieuwe correctie wordt voor het eerst daadwerkelijk toegepast bij poging 259, iteratie 2, vanaf t1900=35797,34694681705. De eerste 258 pogingen en budgetregels zijn exact gelijk aan de bestaande kandidaatprefix. Vanaf poging 259 divergeert de numerieke voortzetting; dit is het beoogde eigen traject. De 112 nieuwe correcties hebben zestigmaal rang één en tweeënvijftigmaal rang twee. Alle providerstempels zijn geldig. De overige 1817 Jacobiaanberekeningen gebruiken de bestaande terugvaltak; de toepassingsuitsluitingen zijn zichtbaar als codes -3 en -6.

De activiteitsteller telt iedere gecorrigeerde Jacobiaan éénmaal, dus 334=222 bestaande +112 nieuwe, niet de som van de voorraadrangen. Het grootste residu van een nieuw gecorrigeerd lineair stelsel is 2,7755575615628914e-17; de kleinste Woodbury-determinant is 0,9952221218381703.

De voorlaatste commit ligt op 35797,370198904129; de laatste volledige stap gebruikt dt=0,002 dag en eindigt op 35797,372198904130. Ook de volgende dt blijft 0,002 volgens de bestaande regeling. Daardoor is de context van oorspronkelijke poging 297 in **tijd** gepasseerd. Het eigen traject heeft slechts 287 pogingen en hoeft de oude pogingnummers of dezelfde tussenstaat niet te reproduceren.

## Waterinventaris en cumulatieven

Elke stap is onafhankelijk gecontroleerd tegen zijn gebruikte dt en oorspronkelijke criterium; de grootste absolute stapfout is 1,3453177825331793e-8 cm. De grootste verhouding fout/grens is 0,7606701783493846 en blijft dus onder één. De maximale afzonderlijke domeinfout per stap is 2,1098574276567916e-16 cm. De waterinventarisfouten sluiten aan op dt maal het geaccepteerde somresidu; alle 287 acceptaties hebben een verse V1-certificatie en fluxfactor één.

Over het hele korte segment bedraagt de onafhankelijk berekende voorraadverandering -0,15288255655669833 cm en de externe integraal -0,152882438218024 cm. De sluitfout is -1,1833867433197476e-7 cm, binnen de som van de bestaande stapgrenzen van 3,721989042274467e-6 cm. De integrale fouten voor de vijf domeinen blijven kleiner dan 1,44e-16 cm. Matrixfracties en laagdikten zijn aan begin en eind gelijk; canopy is meegenomen met niet-nul beginvoorraad SICACT=0,0025926018136122326 cm.

De oorspronkelijke dagstart reset de periodecumulatieven tussen `ledger_initial` en `ledger_begin`. De fysieke voorraden zijn op die beide punten gelijk. De cumulatieve incrementcontrole gebruikt daarom de werkelijke basis **ledger_begin → ledger_final**. De gecontroleerde primitieve fluxincrementen stemmen overeen met de som van de oorspronkelijke gebruikte-dt-budgetregels, met een maximale absolute afwijking van 4,45e-16 cm. Er wordt geen volledige oorspronkelijke periodehistorie uit een geresette ledger afgeleid.

## Grenzen en bewijsbewaring

Er zijn precies twee modelroutes uitgevoerd, beide normaal en ongecensureerd onder twintig seconden. Dit is één kort eigen traject; er is geen brede campagne, volledige balansperiode of nieuwe native-herstartkwalificatie uitgevoerd. Een bevroren DOMAINS36-meetpunt wordt in dit traject niet ingelezen en de kalibratieroutine wordt niet aangeroepen. De correctie gebruikt uitsluitend actuele providergegevens.

Er treedt hier geen afwijzing op. Het eerdere echte actieve afwijzings-/rollback-/directe-retrybewijs uit ACTIVE38 blijft geldig binnen zijn oorspronkelijke context, maar wordt door deze ronde niet opnieuw getoetst of uitgebreid. De status blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`; geen algemene Jacobiaan-, krimp-, GWL-geometrie-, herstart- of canonieke toelating. B0, B1.12, canonieke SWAP5 en de no-macrorelease zijn niet gewijzigd.

`assess_trajectory39.py` analyseert uitsluitend opgeslagen uitvoer. `RESULT.json`, `CONTRACT.json`, `TRACE_FIELDS.json` en de ruwe O0/O2-uitvoer vormen de onderbouwing. `TRAJECTORY39_EVIDENCE.zip` bevat bron, ruwe uitvoer en de werkelijk gebouwde native closure; `EVIDENCE.json` koppelt checkpoint en SHA-256. Ieder opgenomen bestand wordt door de sealer streamend tegen het manifest geverifieerd.
