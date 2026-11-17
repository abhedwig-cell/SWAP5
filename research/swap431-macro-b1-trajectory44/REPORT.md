# TRAJECTORY44: kort eigen contacthersteld traject voorbij oorspronkelijke poging 357

**Het korte eigen traject slaagt numeriek met O0 en O2, met een expliciet begrensde geschiedenisclaim.** Vanaf dezelfde oorspronkelijke native checkpoint worden360 stappen geaccepteerd, zonder afwijzing of fluxreductie, tot t1900=35797,491000009170. Daarmee is het tijdstip van oorspronkelijke poging357 (35797,487000006880) gepasseerd. Alle verse V1-acceptatiecriteria, onafhankelijke stap- en segmentinventarissen, domeinbalansen en gecontroleerde cumulatieve incrementen voldoen aan de bestaande grenzen.

De native geschiedenisbijwerking volgt exact de behouden REPAIR43-regels. Bij90 voortgezette events is het contact in de **eindgeometrie** nul: de bestaande eventvlag laat de klok doorlopen en de gewogen referentie-increment wordt nul. Die feitelijke toepassing is gecontroleerd; de zelfstandige fysische duiding van eventvoortzetting bij wegvallend eindcontact is niet in deze trajectproef gekwalificeerd. Er is geen nieuwe geschiedenisregel geïntroduceerd.

## Basis, activering en observatiegrens

Basis is REPAIR43 `0eabf94e13e25c7ab5ddefc12332e0df6d3ebd6f`. Bron en contract zijn vóór builds en modelroutes vastgelegd in `d336ecfc0`. De gebruikte oorspronkelijke checkpoint op t1900=35797 heeft SHA-256 `21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16`.

Het contactherstel staat vóór de eerste kopberekening aan. Ook de bestaande Jacobiaan-aanvullingen blijven met hun onveranderde voorwaarden beschikbaar. De werkelijke nieuwe aanloop wijkt al bij poging1 af van REPAIR43, waar de fysische patch pas bij357 werd ingeschakeld. Er wordt dus geen oude aanloop aan een gekozen nieuwe context gekoppeld. Begininventaris, native begincontext en oorspronkelijke dagstart zijn exact dezelfde.

De vooraf vastgelegde eindgrens is de eerste volledige commit op of na35797,490, met daarnaast maximaal512 commits, de bestaande interne zestiensecondenstop, een stop bij een reductieverzoek en de harde twintigsecondenlimiet per route. Gewone ongeschaalde afwijzingen zouden het oorspronkelijke hostherstel en TimeControl(5) volgen. Er zijn geen afwijzingen opgetreden en er is geen dt afgekapt voor de observatiegrens.

De fysische rate-, afgeleiden- en geschiedenisformules zijn bytegelijk aan REPAIR43 na het verwijderen van uitsluitend de toegevoegde observatiecode. Alleen de onderzoeksdriver en de compacte geschiedenisregistratie verschillen. `OBSERVATION_CHANGES.patch` en `assess_trajectory44.py` leggen deze vergelijking vast. Er worden geen bevroren punten geladen, kalibraties uitgevoerd of extra providers aangeroepen.

## Eigen traject en O0/O2

| Grootheid | O0 | O2 |
|---|---:|---:|
| Procesduur (s) | 1,479212 | 1,127018 |
| Pogingen / commits | 360 / 360 | gelijk |
| Afwijzingen / gereduceerde commits | 0 / 0 | gelijk |
| Newton-iteraties totaal | 2262 | gelijk |
| Iteraties per geaccepteerde stap | 2–17 | gelijk |
| Grootste eindresidu | 9,969562226250228e-7 | gelijk |
| Grootste absolute somresidu | 7,6017694099366695e-6 | gelijk |

Alle360 acceptaties hebben een verse V1-certificatie en fluxfactor één. De261 door de bestaande nieuwe geometriecorrectie behandelde Jacobianen en226 actieve oudere rang-één-Jacobianen geven487 gezamenlijke correctie-iteraties; de teller telt iedere Jacobiaan éénmaal. Alle actuele providerstempels zijn geldig. Er is geen extra contact-GWL-Jacobiaan toegevoegd of voorwaarde verruimd.

De voorlaatste commit ligt op35797,489000009170. De laatste volledige stap gebruikt0,002 dag en eindigt op35797,491000009170; ook de volgende dt blijft0,002 volgens de bestaande regeling. Het oude pogingnummer357 hoeft op het nieuwe traject niet dezelfde toestand of tijd te vertegenwoordigen. De gevraagde oude context is in tijd gepasseerd.

Beide routes eindigen normaal, ongecensureerd en ruim binnen twintig seconden. Alle getoetste numerieke tekstuitvoer is O0/O2-bytegelijk, met uitzondering van de rekentijdvelden. Verschillende IEEE-meldingen in stderr zijn bewaard; er wordt geen volledige procesbrede IEEE-vlaggelijkheid geclaimd.

## Onafhankelijke waterinventaris en cumulatieven

De grootste absolute stapfout is1,3439759191180914e-8 cm. De grootste verhouding fout/bestaande dt-grens is0,7601769158274385 en blijft onder één. De vijf domeinbalansen sluiten per stap tot maximaal2,11e-16 cm.

Over het hele segment is de onafhankelijke voorraadverandering0,31597218457377463 cm en de externe integraal0,3159722815985797 cm. De sluitfout van-9,70248050791156e-8 cm blijft binnen de opgetelde bestaande stapgrenzen van4,9100000924941145e-6 cm. De integraal van de geaccepteerde somresiduen en de som van de afzonderlijke inventarisfouten stemmen hiermee overeen binnen afronding.

Canopy is meegenomen. De matrixfracties en laagdikten zijn aan begin en eind gelijk. De vijf integrale domeinfouten blijven kleiner dan8,05e-16 cm. Primitieve cumulatieve ledgerincrementen zijn vanaf de werkelijke post-dagresetbasis `ledger_begin` gecontroleerd tegen de oorspronkelijke gebruikte-dt-budgetregels; de grootste afwijking is1,61e-15 cm. Er wordt geen oorspronkelijke periodehistorie uit een geresette ledger afgeleid.

## Geschiedenisbijwerking en expliciete beperking

De gebufferde `history44_trace.txt` bevat154 records bij137 gecommitteerde kopberekeningen, verdeeld over native GWL-cellen50,49,48 en47. Er zijn137 voortgezette en17 beëindigde events. De contactfactor is onafhankelijk uit celranden, GWL en native macroporiewaterstand gereconstrueerd. Beëindigde events resetten tijd, referentie en sorptiviteit; voortgezette events behouden sorptiviteit en tellen precies één gebruikte dt bij de klok op.

Alle theoretische referentie-incrementen stemmen met de behouden gewogen native formule overeen, met maximaal2,70e-17 verschil. Dit controleert de uitvoering van het bestaande procesgeheugen zonder de fysieke of numerieke regels te veranderen.

Een aparte observatie blijft afgebakend:90 voortgezette domein3-events in native cel50 hebben nul contact in de bijgewerkte eindgeometrie. Het eerste is eigen poging36, t1900=35797,070000000014, dt=0,002. De native eindwaterstand is daar gelijk aan de matrix-GWL; de klok gaat van0,07000000000000005 naar0,07200000000000005 dag en de referentie blijft gelijk. De bestaande eventvlag wordt in ABSORPTION bepaald door de potentiële sorptieterm tijdens de proef, terwijl de referentie-increment de eindgeometrie gebruikt. Een voortgezette vlag is daarom geen zelfstandig bewijs van positief eindcontact of werkelijke ongeclipte sorptie op dat eindtijdstip.

Deze ronde bevestigt dat de aldus behouden regel consequent is uitgevoerd. Zij bepaalt niet onafhankelijk of voor een fysisch event met wegvallend eindcontact een andere stop-/resetregel vereist is. `HISTORY_POLICY_INDEX.json` bewaart deze concrete observatie voor eventueel later gericht werk. Er zijn geen aanvullende diagnosevarianten of reparaties aan de eventklok uitgevoerd. De korte numerieke en waterbalanskwalificatie wordt niet tot een algemene fysische geschiedenisclaim uitgebreid.

## Status en bewaring

Uitkomst: `PASS_SHORT_OWN_REPAIRED_TRAJECTORY_BEYOND_ORIGINAL357_WITH_HISTORY_POLICY_LIMIT_O0_O2`. B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`. De volledige oorspronkelijke balansperiode, natuurlijke BAL-inhoud, nieuwe native herstart, echte afwijzing/rollback/directe retry van deze fysische patch en algemene GWL-/perched-/krimp- of geschiedenissemantiek zijn niet gekwalificeerd.

B0, B1.12, canonieke SWAP5 en de no-macrorelease zijn niet gewijzigd. Er zijn precies twee modelroutes en geen brede campagne uitgevoerd. `RESULT.json`, `CONTRACT.json`, `TRACE_FIELDS.json` en de ruwe uitvoer dragen de claims. `assess_trajectory44.py` analyseert uitsluitend opgeslagen uitvoer. `TRAJECTORY44_EVIDENCE.zip` bewaart bron, ruwe data en de daadwerkelijk gebouwde native closure; `EVIDENCE.json` bindt checkpoint en SHA-256. Alle opgenomen bestanden worden streamend tegen hun manifest geverifieerd.
