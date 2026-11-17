# CORRECTION37: minimale correctie op dezelfde grote poging 293

**Lokaal geslaagd met O0 en O2.** De oorspronkelijke grote poging 293 wordt met de DOMAINS36-correctie in vier iteraties geaccepteerd. De numerieke uitvoer is tussen beide optimalisaties bytegelijk, met uitzondering van de geregistreerde rekentijden. De oude kandidaat wees dezelfde grote stap na dertig iteraties af. Dit is een geïsoleerde onderzoekskandidaat, zonder canonieke toelating.

## Vastgezette context en wijziging

Basis is DOMAINS36 `861d0bc866479918393443991ce05ac91a8604bf`; de implementatie is vóór bouwen en rekenen vastgelegd in `6651a445b`. De twee routes gebruiken dezelfde oorspronkelijke native checkpoint op t1900=35797 en dezelfde bestaande kandidaatprefix. De 292 voorafgaande commits, budgetregistraties en de geselecteerde begincontext zijn onveranderd; de 222 eerdere actieve rang-één-iteraties blijven behouden. Alleen op de geselecteerde poging en eventuele echte retries wordt de nieuwe behandeling ingeschakeld.

`Jnieuw = (Jtri + B51) + U2 V2ᵀ + U3 V3ᵀ`: twee voorraadbijdragen voor domeinen 2 en 3 plus de ontbrekende lokale en GWL-afgeleiden van de instroom op cel 51. De bestaande TRIDAG lost de aangepaste tridiagonale systemen op; een 2×2-Woodbury-stap verwerkt de onafhankelijke voorraadbijdragen. De oude rang-één-aanvulling wordt op deze tak niet dubbel toegevoegd. De bestaande tak blijft de fallback buiten de expliciete bewakingsvoorwaarden.

De coëfficiënten komen uit de actuele provider, de actuele potentialen en geometrie. Een afzonderlijke numerieke scratch controleert taak, tijd, dt, poging, iteratie en de volledige actuele kopvector. De solver leest geen DOMAINS36-observatiecache of meetbestand. De oorspronkelijke fysische fluxen, input, toleranties, MAXIT, tijdstap- en reductieregels zijn behouden. De bronwijzigingen zijn reviewbaar in `SOURCE_CHANGES.patch`.

Bij V<W wordt de volumeafgeleide gebruikt; bij V>=W de afgeleide nul van de voorraadcap. Exact V=W kiest expliciet die cap-tak. Onbegrensde uitstroom krijgt geen voorraadaanvulling. De eerste gecorrigeerde iteratie ontmoet de exacte gelijkheid in domein 3 en convergeert vervolgens; dit kwalificeert deze poging, geen algemene afgeleide op elk niet-glad omslagpunt. De vaste GWL-/instroomgeometrie wordt bewaakt, waaronder kopinterpolatie 50/51 en native verzadigingscel 51.

## Gerichte kwalificatie

| Grootheid | O0 | O2 |
|---|---:|---:|
| Rekentijd route (s) | 1,200263 | 0,867253 |
| Ongewijzigde gebruikte dt (dag) | 0,0006875745394909628 | idem |
| Iteraties | 4 | 4 |
| Extra lijnzoekproeven | 1 | 1 |
| Verse V1-certificatie | 1 | 1 |
| Grootste residu (node 52) | 7,26698773254042e-7 | idem |
| Somresidu | -1,3043458948482393e-7 | idem |
| Fluxfactor | 1 | 1 |

Beide routes eindigen normaal, ruim binnen twintig seconden per route. Er zijn precies twee modelroutes uitgevoerd; geen aanvullende contexten of campagne. De vier Jacobianen voldoen aan alle toepassings- en versheidsvoorwaarden. De aantallen onafhankelijke voorraadbijdragen zijn 2, 1, 2, 2; de kleinste Woodbury-determinant is 0,9953675904888976 en het grootste residu van het volledige gecorrigeerde lineaire stelsel 2,5153490401663703e-17.

De afzonderlijke kalibratie gebruikt dezelfde behouden DOMAINS36-punttoestand. De werkelijk geïmplementeerde U/V-vectoren en beide bandcoëfficiënten zijn exact gelijk aan het analytische contract op dit punt. De geselecteerde SENSE23-procestoestand van 20.347.880 bytes is vóór en na kalibratie bytegelijk; de IEEE-status wordt opgeslagen en teruggezet en de nieuwe scratch wordt geïnvalideerd. De onveranderde begincontext en voortzetting bevestigen herstel binnen deze geselecteerde scope. Er worden hier geen nieuwe eindige-differentieproeven gedaan en geen algemene volledige-programmaherstartclaims gemaakt.

De host committeert t1900=35797,371011925898. De volgende dt is volgens de oorspronkelijke regeling 0,0013751490789819256 dag; de voorraadtoets gebruikt de werkelijk gebruikte dt. De onafhankelijke waterinventarisfout is -8,968350582029376e-11 cm bij een bestaande grens van 6,875745394909629e-9 cm. De vijf afzonderlijke domeinvoorraden en de primitieve cumulatieve ledgerincrementen sluiten aan. Zie `RESULT.json` en de ruwe `data/O0/TRIAL`- en `data/O2/TRIAL`-bestanden.

## Grenzen en bewijsbewaring

De grote stap wordt meteen geaccepteerd. Daardoor ontstaat geen echte afwijzing met actieve correctie en is rollback plus directe kleinere retry voor deze nieuwe correctie **niet** gekwalificeerd. De oude kleinere retry eindigt op een ander tijdstip en is geen gelijkheidstoets voor deze geaccepteerde grote stap. Er is geen afwijzing geforceerd en er is geen overbodige DIRECT-route gestart.

Dit bewijst geen algemene 112×112-Jacobiaan, andere GWL-geometrieën, dynamische krimpafgeleiden in overige kolommen, volledige periodebalans, nieuwe native-herstartcontinuïteit of een volledige gecorrigeerde trajectkwalificatie. De B1-status blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`. B0, B1.12, canonieke SWAP5 en de no-macrorelease zijn niet gewijzigd. Remote main blijft de vastgelegde `be481cfb40f953e337116ef4a6dc5bc3ef64d4f7`.

`assess_correction37.py` controleert resultaten zonder modelruns. `CORRECTION37_EVIDENCE.zip` bevat bron, ruwe uitvoer en de gebouwde native closure; `EVIDENCE.json` bindt de SHA-256 en het bron/resultaatcheckpoint. De sealer verifieert ieder opgenomen bestand streamend tegen het manifest.
