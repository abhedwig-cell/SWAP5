# NODE41: gerichte diagnose van poging 357, node 47

**De afwijzing is exact gereproduceerd en de stagnatie is gelokaliseerd bij de discrete verzadigingscelgrens op GWL=-60 cm.** Tijdens de dertig iteraties wisselt de native cel tussen 47 en 48. Daardoor schakelt de bestaande ABSORPTION-loop de ongesatureerde macro-uitstroom op node 47 volledig uit of in. Het residu wisselt negentienmaal van teken en blijft veel groter dan de bestaande grens. O0 en O2 leveren dezelfde numerieke diagnose.

De nieuwe correctie is hier uitgesloten omdat haar gekwalificeerde 50/51-/cel-51-geometrie niet aanwezig is. De actuele hoofdinterpolatie is 47/48, de native verzadigingscel is 47 of 48 en de perched-zone-indeling verandert mee. De providergegevens zijn in alle dertig Jacobianen actueel. Deze ronde verandert geen correctievoorwaarden of fysische formules.

## Exacte context en scope

Basis is PERIOD40 `05d0fd1fdb14ffe505c4c0e9d58a4cc639386185`. De observatiebron is vóór builds en modelroutes vastgelegd in `28e70e7ee`. De oorspronkelijke eigen native checkpoint op t1900=35797 heeft SHA-256 `21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16`.

Beide routes herhalen exact de 356 voorafgaande commits van het eigen gecorrigeerde PERIOD40-traject en stoppen na de werkelijke afwijzing van poging 357. Begin van die poging: t1900=35797,487000006880 en dt=0,001000001146167051 dag. De eerste 357 pogingtraces, inclusief residuen, tellers en uitkomst van de geselecteerde afwijzing, zijn exact gelijk aan PERIOD40 buiten de rekentijdvelden. Ook alle voorafgaande budget-, voorraad- en beide Jacobiaantraces zijn gelijk.

De wijzigingen zijn uitsluitend observaties en de stop na deze geselecteerde afwijzing: node-47-logging, operatoruitsplitsing voor nodes 44–57 en een observer die de reeds beschikbare actuele providergegevens leest. Geen extra MACRORATE-evaluatie, eindige-differentieproef, nieuwe numerieke variant, kleinere retry, periode-uitbreiding of brede campagne. De numerieke termen, fysica, invoer, toleranties, MAXIT, dt- en reductieregels zijn behouden. `OBSERVATION_CHANGES.patch` en de bronvergelijkingen in `assess_node41.py` maken dit controleerbaar.

## Iteratievoortgang

Er zijn dertig Jacobianen, 105 vector-/providerevaluaties en 104 lijnzoekproeven: 74 extra proeven boven één per Newton-iteratie. Het oorspronkelijke maximum van vier lijnzoekproeven wordt in negen iteraties uitgeput. Die negen iteraties eindigen met een grotere doelwaarde dan de vorige iteratie. De code gaat daarna volgens de bestaande regeling door naar de convergentietoets; dit is niet gewijzigd.

| Iteratie | GWL (cm) | Native cel | Residu node 47 | Laatst werkelijk geteste factor | ½ FᵀF |
|---|---:|---:|---:|---:|---:|
| 1 | -59.978693386 | 47 | +0.056466295 | 1.000000 | 0.00242200576 |
| 3 | -60.000662638 | 48 | -0.031533940 | 0.333333 | 0.000888007365 |
| 6 | -60.000568625 | 48 | -0.030118909 | 0.037037 | 0.000794251989 |
| 10 | -60.000000401 | 48 | -0.027880237 | 0.037037 | 0.000669742367 |
| 26 | -60.000014328 | 48 | -0.025031095 | 0.111111 | 0.000511224804 |
| 30 | -60.000549212 | 48 | -0.025716259 | 0.037037 | 0.000535487874 |

Het initiële grootste residu is 0,19031264786385216. Na de eerste Newton-stap domineert node 47 het grootste residu in alle dertig iteratie-eindtoestanden. De kleinste bereikte waarde is 0,025031095286205937 en de uiteindelijke waarde 0,02571625908888784; de lokale grens blijft 1e-6. Het uiteindelijke somresidu is -0,007310765121685977 bij grens 1e-5. De lokale balansvlag blijft in alle iteraties actief; de kopveranderingsvlag van node 47 faalt alleen in de eerste drie iteraties. Er ontstaat nooit voorlopige convergentie, zodat de teller voor de aanvullende verse eindcertificatie nul blijft.

`O0_ITERATION_PROGRESS.csv` en `O2_ITERATION_PROGRESS.csv` bevatten alle dertig iteraties. Zij onderscheiden de laatst werkelijk geteste factor van de teller/factor ná de lijnzoeklus: bij uitputting meldt de eindtrace itry=5 en factor 1/81, terwijl daadwerkelijk vier proeven zijn gedaan en de laatste factor 1/27 was. Deze administratieve eindwaarden mogen niet als een vijfde evaluatie worden gelezen.

## Operator en omslag bij -60 cm

De ondergrens van cel 47 is precies -60 cm. `calcgwl_probe.f90`, functie `nodlev` rond regel 285, bepaalt via de celondergrenzen welke native cel de GWL bevat. `macrorate_node.f90:113` neemt die cel over in `ICpTpSatZon`. In ABSORPTION begrenst regel 1893 het beschouwde bereik expliciet tot `min(ICpBtDm(id), ICpTpSatZon-1)`, met het commentaar dat de deels verzadigde GWL-cel geen sorptie krijgt. De perched-zonevoorwaarde rond regel 1928 sluit eveneens een deels verzadigde perched-cel uit.

Dit levert in de **werkelijk uitgevoerde** 105 providerevaluaties op node 47 het volgende patroon:

| Native cel | Evaluaties | Totale ongesatureerde macro-uitstroom (cm/dag) |
|---|---:|---:|
| 47, GWL boven of op -60 | 56 | exact 0 |
| 48, GWL onder -60 | 49 | 0,05661226259 tot 0,05688505174 |

Bij native cel 47 stopt de ABSORPTION-loop boven node 47; bij cel 48 wordt node 47 wel behandeld. De gemeten uitstroom is geheel ongesatureerd en komt uit domeinen 3 en 4, vrijwel geheel uit domein 4. Op node 47 is in deze evaluaties geen verzadigde uitstroom of instroom gemeten.

De laatste operatoruitsplitsing, in cm/dag, is:

| Bijdrage | Waarde |
|---|---:|
| Matrixopslag | +0,0000723446203 |
| Bovenste verticale term | -0,3463775936612 |
| Onderste verticale term | +0,3772050320572 |
| Minus macro-uitwisseling | -0,0566160421052 |
| Sink, source en wortelterm | 0 |
| Residu | -0,0257162590889 |

De macroterm bestaat uit domein-3-uitstroom 0,0000824470396043 en domein-4-uitstroom 0,0565335950656074. Alle gelogde operatorregels sluiten op hun zeven componenten, maximaal verschil 2,78e-17. De sprong is daarmee aan een concreet bestaand providerpad gekoppeld. Deze observaties bepalen nog niet of het fysische contract van de deels verzadigde cel een wijziging rechtvaardigt; er is geen bewezen of geïmplementeerde fysische correctie in deze ronde.

## Waarom de correctie niet actief is

De dertig nieuwe-correctietraces melden allemaal code -3 met geldige actuele providerstempel. De eerste falende controle in `jac37_update.f90:20` eist native indices 51/51/51. Werkelijk gemeten zijn bij de Jacobiaanpunten zeventienmaal 48/48/48 en dertienmaal 47/47/-1. In die laatste toestand meldt de bestaande code PeGWL=999 als afwezigheidswaarde.

Ook andere geometrievoorwaarden falen: de werkelijke kopinterpolatie is steeds 47/48 en reproduceert de actuele GWL exact; h50 ligt tussen 4,31036 en 4,36354 cm en h51 tussen 6,17105 en 6,22137 cm. Daardoor faalt de vereiste h50<0<h51<1 in alle dertig iteraties. Extrapolatie met de vaste 50/51-formule wijkt ongeveer 0,307–0,324 cm van de werkelijke GWL af. De uitsluiting beschermt dus daadwerkelijk een ander geometrisch regime.

Verder zijn op alle dertig Jacobiaanpunten de instroom- en uitstroomfactoren in alle vijf domeinen één. Er is daar geen actieve uitstroombeperking waarvoor de nieuwe minimumvoorraadterm een factorafgeleide moet aanvullen. Domein 2 heeft bovendien steeds laterale en matrixinstroom en in zeventien punten interne instroom, buiten het eerdere uitsluitend-verticale-instroomcontract. De oude rang-één-aanvulling blijft eveneens inactief. Alleen vaste indices verplaatsen zou deze contractverschillen niet oplossen en is hier niet gedaan.

## Herstel, O0/O2 en grenzen

De gekozen poging weigert echt na MAXIT en vraagt een kleinere dt aan, zonder fluxreductie. De gedumpte falende solvertoestand en de echte iteratietraces zijn behouden. Daarna zijn de bestaande fysieke herstelroutines aangeroepen. De gecontroleerde opgeslagen kop-, vocht-, pond- en macro-watervoorraden zijn gelijk aan de oorspronkelijke beginstaat; de ledger is bytegelijk vóór en na de proef en na herstel. Er is geen targetcommit.

Volledige onmiddellijke bytegelijkheid van alle native hulpvelden wordt niet geclaimd: onder andere sorptiereferenties, sorptiviteit en krimphulpvelden verschillen. De falende kop voor de diagnose komt uit `solver_1.txt` en de iteratie-/operatortraces, niet uit de reeds fysiek herstelde retourdump. Deze ronde doet geen nieuwe retry-, algemene rollback- of native-herstartkwalificatie.

O0 duurt 2,048120 seconden en O2 1,523915 seconden; beide eindigen normaal en ongecensureerd binnen twintig seconden. Alle getoetste numerieke tekstuitvoer en de volledige afgeleide iteratietabellen zijn O0/O2-bytegelijk buiten de rekentijdvelden. De bestaande interne zestiensecondenstop is behouden.

Status: `PASS_DIAGNOSIS_ORIGINAL357_NODE47_PROGRESS_AND_GUARD_O0_O2`. B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`; de volledige periode/BAL blijft ongekwalificeerd. Er is geen algemene uitbreiding van de correctie, nieuwe fysica, brede campagne of canonieke toelating. B0, B1.12, canonieke SWAP5 en de no-macrorelease zijn niet gewijzigd.

`RESULT.json`, `TRACE_FIELDS.json`, de twee iteratie-CSV's en de ruwe uitvoer dragen de claims. `assess_node41.py` voert uitsluitend analyse uit. `NODE41_EVIDENCE.zip` bewaart bron, ruwe observaties en de werkelijk gebouwde native closure; `EVIDENCE.json` bindt checkpoint en SHA-256. Ieder opgenomen bestand wordt streamend tegen het manifest geverifieerd.
