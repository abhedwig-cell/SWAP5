# DIAG19 — rekentijd en fluxreductie op 3 januari

**In dit gemeten bereik domineert headcalc de rekentijd.** Herhaalde afgewezen Newtonpogingen en duizenden kleine geaccepteerde stappen verklaren het trage modelverloop. De oorspronkelijke minimumstap-/fluxreductieprocedure treedt werkelijk op. Deze diagnose toont geen fout aan die nu een fysische of solvercorrectie rechtvaardigt; de volledige tweede BAL-periode blijft ongekwalificeerd.

## Grenzen en bewijsbasis

Basis is NEXT18 1822cfd9e706379c4c62b2d802ea168e42e8a5ef. De vier bestaande O0/O2-budgetstromen blijven de numerieke referentie. Alleen twee extra diagnostische routes zijn uitgevoerd: O0 en O2, elk in een vers proces vanaf het bestaande eigen V5-bestand op t1900=35797. Geen latere toestand gereconstrueerd, geen route in stukken tot voltooiing doorgerekend. Alle oorspronkelijke invoer, fysica, V1-certificering, Darcycorrectie, BAL-code, native codec, criteria, dtgrenzen en reductieregels blijven behouden.

De toevoegingen zijn tellers, SYSTEM_CLOCK-metingen en twee gebufferde meetstromen. De bewaarde patches tonen de toevoegingen aan head en driver. Vooraf geselecteerde stop: 7000 commits of 16 gemeten seconden, met onveranderde harde subprocess-timeout van 20 seconden. O0 stopt normaal op 6664 commits/16,000553 gemeten seconden; O2 op 7000 commits/9,620210 seconden. Totale procesaanroepen duren 16,819 en 10,339 seconden, beide zonder censuur. Er was één herstelde linkfout tijdens opbouw van de instrumentatie, vóór enige modelrun; geen foutieve modelroute uitgevoerd.

Alle geaccepteerde primitieve budgetregels zijn exact gelijk aan de overeenkomstige NEXT18-native prefix. Beginexports, geïnstalleerde native toestand en ledger zijn eveneens bytegelijk. De gemeenschappelijke **6664 commits en 9006 headpogingen** zijn tussen O0/O2 exact gelijk in alle niet-timingkolommen, inclusief residuen, locaties, counters en policyvlaggen. Geen volledige fysieke eindinventarisvergelijking of periode-PASS afgeleid uit alleen budgetgelijkheid.

## Direct gemeten kosten

Voor een eerlijke vergelijking geldt deze tabel voor dezelfde eerste 6664 commits en 9006 pogingen:

| Meting | O0 | O2 |
| --- | ---: | ---: |
| Voortzettingsspannen | 15,875 s | 9,103 s |
| Headcalc wandtijd | 14,058 s | 7,739 s |
| Headcalc aandeel | 88,55% | 85,02% |
| Budget-WRITE en periodieke FLUSH | 0,340 s | 0,329 s |
| Budgetaandeel | 2,14% | 3,61% |
| Wandtijd in afgewezen headpogingen | 7,870 s | 4,051 s |
| Afgewezen headpogingen | 2342 | 2342 |

De headmeting omvat de echte headcalc-call inclusief diens bestaande diagnostische checks. De budgetmeting omvat dezelfde 32 kolommen en iedere 128 stappen een FLUSH, zonder per-stap OPEN/CLOSE. De voortzettingsspan loopt van na de vorige kostentrace tot vóór de volgende; schrijven van de nieuwe kostentrace en opzetten van de volgende span vallen erbuiten. Attempttrace-formattering valt buiten de headtimer maar binnen de span. Startup en beëindiging zitten alleen in de totale procesduur. De resterende tijd wordt niet aan een specifieke routine toegeschreven.

Anders dan COST15's eerdere, andere prefix met open/write/close per stap is de diagnostische budget-I/O hier geen dominante kostenpost. Dit is een lokale directe meting, geen tijdtoerekening voor de gehele dag. Het verschil met NEXT18's oude timeoutdoorvoer is evenmin een bewezen structurele versnelling: omgeving en meetpad zijn verschillend, geen gecontroleerde benchmark voor die vergelijking.

Op de gemeenschappelijke route zijn 139953 Jacobiaanaanroepen en 38599 extra line-searchpogingen boven de eerste per Jacobiaanstap geteld, plus 31916 verse V1-certificeringen. De eerder onderzochte vroege prefix had zulke extra line-searchpogingen niet. Dit bewijst extra iteratiewerk, maar splitst headtijd niet verder uit naar Darcy, sorptie, Jacobiaan of certificering.

## De eerste reductie, zonder gewijzigde regels

De geaccepteerde eerste gereduceerde stap blijft NEXT18-stap 42 op **35797,071397877706**, met gebruikte dt=0,0001414213562373095 dag en FrReduQ=0,1. De nieuwe attempttrace laat de aanloop zien:

1. Op beginmodeltijd 35797,07125645635 faalt dt=0,00002 na 30 iteraties. De host vraagt een kleinere retry.
2. De retry op DTMIN=0,00001 faalt ook na de oorspronkelijke uitgebreide 60 iteraties. De eindteller is 61 doordat de Fortran DO-lus is uitgeput; dat betekent geen 61 uitgevoerde iteraties. De gebruikelijke 30-iteratie-uitputting laat analoog 31 zien.
3. Het maximale compartimentresidu ligt op node 52: **0,011073178056294819**, tegen CRITDEVBALCP=0,000001. Het somresidu is **0,06965439025399942**, tegen CRITDEVBALTOT=0,00001. Het compartimentbalanscriterium faalt; het headveranderingscriterium, pondingcriterium en macrovoorraadcriterium staan bij deze specifieke eindpoging niet op fout.
4. De ongewijzigde headpolicy verhoogt IDecMpRat van 0 naar 1. TimeControl(5) kiest sqrt(DTMIN*DTMAX), met DTMAX=0,002. Macrorate gebruikt 0,1**IDecMpRat. De volgende poging accepteert daardoor de genoemde stap met factor 0,1.
5. Bij die acceptatie daalt IDecMpRat meteen terug naar 0: dt is groter dan de bij reductie vastgelegde dtold. De gebruikte FrReduQ van deze geaccepteerde berekening blijft 0,1; de volgende poging begint weer ongereduceerd. De twee waarden zijn daarom niet uitwisselbaar als bewijs van de gebruikte stapoperator.

Dezelfde herstel-/terugschakelprocedure komt herhaald voor: O2 telt tot zijn stop 476 niveauverhogingen en 476 verlagingen; O0 463 van beide. Dit verklaart waarom een reeks gereduceerde commits geen permanent gereduceerde toestand betekent. Alleen op FlDecMpRat na return tellen zou eerdere reeds gezette retryvlaggen kunnen verwarren met nieuwe niveauverhogingen; de diagnose gebruikt daarvoor de feitelijke wijziging van IDecMpRat.

Van de 2342 gemeenschappelijke afgewezen pogingen hebben 2187 de compartimentbalansvlag zonder headveranderingsvlag, 147 beide vlaggen, en 8 de headveranderingsvlag zonder compartimentbalansvlag. Het totale somresidu kan daarnaast falen; de vlagverdeling is geen uitsluiting daarvan. Bij geen daarvan is de ponding- of macrovoorraadvlag de geregistreerde oorzaak. Node 52 heeft in 1869 afwijzingen het grootste absolute compartimentresidu. Deze lokalisatie bewijst geen specifieke fout in de Darcy-/sorptieovergang: heads en afzonderlijke operatorbijdragen per iteratie zijn hier niet vastgelegd.

## Veel kleine stappen zijn een tweede mechanisme

De bestaande NEXT18 O0/O2-native stromen leveren exact dezelfde volledige deelvensters:

| Dagfractie, eindtijd van commits | Stappen | Mediaan gebruikte dt, dag | Gereduceerde stappen |
| --- | ---: | ---: | ---: |
| 0–0,0714 | 42 | 0,002 | 1 |
| 0,0714–0,25 | 1086 | 0,0001414213562 | 277 |
| 0,25–0,50 | 459 | 0,0002828427125 | 89 |
| 0,50–0,67 | 5932 | 0,00001640118474 | 210 |

In het dichte laatste venster zijn de meeste commits dus ongereduceerd. Een verklaring uitsluitend via de aantallen gereduceerde stappen mist dit grote werkvolume. De nieuwe O2-meting bereikt binnen dit venster 5413 commits; slechts 20 daarvan hebben numbit<=4. De oorspronkelijke invoer heeft NUMBIT_CRIT=4, FACT_DT_INCREASE=2, FACT_DT_DECREASE=0,5 en FACT_DT_FLDECT=3. TimeControl(3) vergroot dt op grond van iteraties alleen bij numbit<=4. Succesvolle stappen met bijvoorbeeld 6–13 iteraties verhogen de kleine stap langs die regel dus niet. Afwijzingen kunnen hem verder verkleinen. Dit ondersteunt het mechanisme waarbij een eenmaal kleine stap lang klein blijft, zonder dat iedere stap opnieuw stagneert.

Er zijn ook eventcaps in de oorspronkelijke TimeControl. De afzonderlijke bindende dtcap is niet gelogd; de herkomst van ieder constant klein dtplateau wordt daarom niet uitsluitend aan de iteratiecontroller toegeschreven. De oude minimumwaarde onder DTMIN wordt evenmin zonder eventdiagnostiek als fout bestempeld.

NEXT18 toont de eerste factor 0,01 op **35797,654088272546**. De huidige O2-route stopt op 35797,65332473032, O0 op 35797,64702062258. Deze tweede reductiediepte is dus met het bestaande budget bewezen maar **niet met de nieuwe attempttrace gekwalificeerd**. Er is geen extra modelroute gestart om de geselecteerde meetgrens te passeren.

## Betekenis en kleinste passende vervolgvraag

De bestaande grenzen zijn gerespecteerd. De gemeten vertraging hangt samen met afgewezen solverpogingen én een dicht veld van kleine geaccepteerde stappen. De eerste reductie volgt aantoonbaar de oorspronkelijke non-convergentieprocedure, in dezelfde oorspronkelijke native context en identiek tussen O0/O2. Een BAL-uitvoercorrectie of native installverschil is hier niet als oorzaak aangetoond.

Er is geen grond om op deze data tolerantie, iteratiebudget, dtbeleid, reductiepolicy of fysica te wijzigen. Een eventuele volgende gerichte diagnose moet de operatorbijdragen en iteratievoortgang bij de oorspronkelijke eerste node-52-afwijzing afbakenen; voor latere dtplateaus is expliciete herkomstregistratie van de gekozen dt nodig. Dat zijn vervolgmogelijkheden, geen reeds uitgevoerde kwalificatie of automatisch gestarte campagne. De volledige tweede BAL-periode, het latere factor-0,01-retryverloop en wetenschappelijke promotie blijven open.

Herbeoordeling zonder modellen: assess_diag19.py. RESULT.json, bronpatches, buildidentiteiten, oorspronkelijke native bestanden, attempt- en kostentraces en het geverifieerde DIAG19_EVIDENCE.zip bewaren het bewijs. De tracekolommen staan in TRACE_FIELDS.json.
