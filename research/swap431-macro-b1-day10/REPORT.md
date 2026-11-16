# DAY10 — native eigen herstart over een oorspronkelijke daggrens

**PASS voor herstart vanuit de laatste subdagcheckpoint vóór de daggrens, de grenspassage en de eerste volledige stap van de nieuwe dag, met O0/O2.** Native formaat, herstelcode, fysica, solvercriteria en reductieregels zijn ongewijzigd ten opzichte van NATIVE09. Alleen de kwalificatie-instrumentatie in soilwater is aangepast. Geen officiële promotie.

## Selectie en oorspronkelijke context

Basis is NATIVE09 `7551d92dccf4d1ea0d2be6b492ed7bcf3618b1aa`. Het bestaande eigen B-bestand wordt werkelijk native ingelezen. Vanaf die reeds gekwalificeerde toestand loopt uitsluitend een korte echte voortzetting tot de laatste geaccepteerde subdagtoestand vóór de eerstvolgende oorspronkelijke daggrens. Er is geen koude tweedaagse herhaling of synthetische toestand gebruikt. De oorspronkelijke ACCEPT01-evidence bevat eveneens contexten rond 35796,998–35796,9994; de hier gemeten druk-/geheugenvelden worden daadwerkelijk met de huidige kandidaat voortgezet en niet uit die oude variant overgenomen.

De gekozen checkpoint is t1900=**35796,99991333311**, circa 7,49 seconden vóór de grens. De native schrijver wordt na TimeControl(3) aangeroepen en verandert geen gemeten veld. Een vers proces leest precies dit eigen bestand in. Continu en herstart doorlopen vervolgens de werkelijke dagafsluiting, gewasafhandeling, nieuwe dagstart en eerste nieuwe-dagstap via de oorspronkelijke host.

TSTART en alle fysieke bestanden blijven oorspronkelijk. Alleen TEND wordt voor beide routes van de bestaande begrensde Jan2 naar Jan3 gezet om de derde kalenderdag te laden; stoppen gebeurt direct na de eerste volgende-dagstap. De oorspronkelijke volledige invoerperiode liep tot april1999; deze korte verlenging gebruikt bestaande oorspronkelijke forcing. Vanaf het B-bestand wordt ongeveer 0,049 modeldag uitgevoerd, geen volledige tweedaagse of brede campagne.

Canonical is gereconcilieerd op `f1f8d06024f4e9d11002984978d7b0de22adb054`; de relevante brondelta bevat uitsluitend andere no-macro/solute-drivers, geen oorspronkelijke macrodependency. B0, B1.12, canonical, release en andere branches zijn niet gewijzigd.

## Resultaten

| Stap | Begin t1900 | Werkelijke dt (dag) | Eind t1900 | Gecombineerde inventarisafwijking (cm) |
| --- | ---: | ---: | ---: | ---: |
| Grenspassage | 35796,99991333311 | 0,0000866680992081 | 35797,0 | −1,85×10⁻¹⁵ |
| Eerste nieuwe-dagstap | 35797,0 | 0,000173336198416 | 35797,0001733362 | −1,36×10⁻¹⁴ |

Voor beide optimalisaties zijn de native geïnstalleerde context en de checkpointcontext exact gelijk. Na de grenspassage en na de eerste nieuwe-dagstap zijn alle gemeten fysieke velden, sorptieklokken, macrovoorraad/geometrie, bodemtemperaturen, geleidbaarheden en gewas-/forcingcontext bytegelijk tussen continu en herstart. Ook de begincontext van de nieuwe dag is exact. Alle tekstuele meetvectors zijn bytegelijk tussen O0 en O2.

Bij de solverreturn van de grensstap verschilt alleen het oude verticale matrixfluxprofiel: dit wordt door de daaropvolgende echte SoilWater(3)/fluxes opnieuw opgebouwd. Alle overige gemeten solverreturnvelden zijn exact. Na commit is ook dat profiel exact gelijk. Er wordt dus geen volledige gelijkheid van voorafgaande, herberekenbare trialdebieten geclaimd.

De onafhankelijke waterinventaris reconstrueert matrixverandering uit theta, laagdikte en matrixfractie, macroverandering per domein uit primitieve in-/uitdebieten en het gecombineerde saldo uit externe bronnen, sinks en oppervlaktevoorraad. Alle vijf domeinen sluiten op afrondniveau; de maximale gepaarde uitwisselingsafwijking is 2,78×10⁻¹⁷ cm/d. De gemeten headreturn heeft geen afwijzings-/reductieflag. Dit werk voegt geen aparte verse residu-oracle toe; de oorspronkelijke headacceptatiecriteria zijn behouden.

Er zijn precies vier modelroutes: continu en verse herstart voor O0 en O2. Langste route 0,855 seconde; geen censuur, iedere route onder twintig seconden. Een eerste invoervoorbereiding miste het aanmaken van casussubmappen; dit trad vóór enig modelproces op en is hersteld. De modelruns zijn niet herhaald. `assess_day10.py` beoordeelt de vastgelegde uitkomsten zonder modellen.

## Expliciete geldigheidsgrens

Dit kwalificeert **een subdagcheckpoint waarvan de voortzetting de daggrens passeert**. Een bestand schrijven/lezen precies op de daggrens of tussen dagafsluiting en gewasafhandeling is hiermee niet gekwalificeerd: de bestaande native subdagguard blijft ongewijzigd. Ook exacte cumulatieve uitvoer-/PEARL-ledgers, andere modi, gereduceerde toestand en droge/h=0-overgangen blijven uitgesloten. Status blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS.

Herstelpad: STATUS.json, RESULT.json, assess_day10.py, daginstrumentatie en bewijsarchive. Een volgend onderzoek vereist een concreet onderscheid in een bestaande context; dit PASS selecteert geen brede vervolgcampagne.
