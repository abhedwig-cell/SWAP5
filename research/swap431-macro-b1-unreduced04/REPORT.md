# SWAP431-MACRO-B1-UNREDUCED04

**Besluit: `B1_CANDIDATE_NOT_READY` voor een ongereduceerde fysische B1-referentie.** De ongewijzigde V1-iteratie verwerpt op deze ene oorspronkelijke begincontext alle vier oorspronkelijke tijdstappen, ook met het volledige oorspronkelijke budget van zestig iteraties per poging. Bij `dtmin=1e-5 d` vraagt de oorspronkelijke code opnieuw om fluxreductie. De proef herstelt de toestand en stopt daar; er wordt geen gereduceerde of ongeconvergeerde stap geaccepteerd.

Dit is een uitspraak over de bestaande V1-route binnen de bestaande numerieke grenzen, geen bewijs dat een ongereduceerde wiskundige oplossing niet bestaat. De gereduceerde V1-variant blijft afzonderlijk onderzoeksbewijs met de eerder genoemde uitsluitingen. B1.12, B0, canonical en de macroporiënvrije release zijn niet gewijzigd.

## Basis en contract

Onderzoeksbasis: `f1271cc1d99e611dbc287cc6ca8c11dfc46c732c`, definitieve INVENTORY03. Nieuwe branch: `research/swap431-macro-b1-unreduced04-20261113`. De gebruiker gaf `go` na het concrete voorstel één begrensde ongereduceerde heroplossings-/afwijzingsproef uit te voeren. Dat autoriseert deze experimentele selectie; het promoveert geen nieuwe referentie.

De actuele remote branches zijn gecontroleerd; er was geen opvolger van INVENTORY03. Canonical was inmiddels `980273f819ef0984da90dc478e26d2b1e340fcc2`. De delta sinds `e157e65ff` betreft uitsluitend algemene experimentele macroporiënvrije project-/bodemranddekking. De oorspronkelijke archieven, de V1-onderzoeksbron en de hier geërfde native closure zijn daardoor niet gewijzigd; geen canonical wijzigingen zijn overgenomen of uitgevoerd.

De proef begint bij exact de eerder gemeten oorspronkelijke context: `t1900=35796.9513533331`, `dt=0.0001414213562373095 d`, op het punt waar de oorspronkelijke uitvoering V1 met reductieniveau één zou aanroepen. Alle gedeelde gemeten beginvelden komen exact overeen met INVENTORY03. De volledige oorspronkelijke prefix blijft V1 en gebruikt de bestaande modelinvoer. Alleen op deze levende context wordt `IDecMpRat=0` geselecteerd.

De bestaande `FlDecMpRat=true` uit de begincontext blijft in de definitieve proef behouden: oorspronkelijke `headcalc` gebruikt deze flag ook om zijn bestaande iteratiebudget te verdubbelen. De wet `FrReduQ=0.1**IDecMpRat`, fysica, Jacobiaan, bevriezing, lijnzoeker, criteria, tijdstapgrenzen en oorspronkelijke verkleiningsregel zijn niet gewijzigd. Elke poging gebruikt aantoonbaar `FrReduQ=1`. Na afwijzing worden daadwerkelijk `SoilWaterStateVar(2)`, `MacroStateVar(2)` en, wanneer toegestaan, `TimeControl(5)` gevolgd door de oorspronkelijke drainage-/opslagroute uitgevoerd.

Vooraf zijn maximaal vier pogingen per modelroute en twintig seconden per route vastgelegd. Zodra `headcalc` bij minimumdt opnieuw reductieniveau één aanvraagt, wordt na rollback gestopt. Geen reset om die aanvraag te omzeilen; geen kleinere stap dan dtmin; geen tolerantieverruiming of doorgaan-zonder-convergentie. Een directe kleine controle vanuit onaangeroerde begincontext was alleen geselecteerd als een kleine retry zou slagen. Dat gebeurde niet, dus die conditionele controles zijn niet uitgevoerd.

## Werkelijke uitkomsten O0/O2

De definitieve O0/O2-routes leveren **bytegelijke ruwe meetvectoren en dezelfde vier afwijzingen**. Elke poging kreeg de volledige zestig bestaande iteraties. De Fortran-lusindex na uitputting is 61; dat betekent zestig uitgevoerde iteraties, niet 61.

| Poging | dt (dag) | Laatste lokale solverresidu | Som laatste solverresidu | Uitkomst |
| --- | --- | --- | --- | --- |
| 1 | `1.414213562373095e-4` | `1.839876363338378e-3` | `-1.922009307350458e-3` | afgewezen |
| 2 | `4.714045207910317e-5` | `1.122212934795949e-1` | `8.157597524220922e-1` | afgewezen |
| 3 | `1.571348402636772e-5` | `9.894222962661647e-2` | `1.819282670732871e-1` | afgewezen |
| 4 | `1e-5` | `9.519149396336430e-2` | `-9.590048763429958e-2` | oorspronkelijke fluxreductie aangevraagd; proef gestopt |

De oorspronkelijke lokale grens is `1e-6`; de absolute totale grens `1e-5`. Alle vier laatste solverresiduen overschrijden beide grenzen. De eerste stap laat dus ook zonder voorafgaande nieuwe afgewezen pogingen geen acceptatie toe. Het al eerder gevonden verschil tussen gereduceerde en ongereduceerde uitwisseling wordt hier niet alleen diagnostisch geëvalueerd: de matrix is werkelijk opnieuw geïtereerd met ongereduceerde rates.

**Grens van deze meetwaarden:** dit zijn de laatste residuen van de oorspronkelijke afgewezen V1-iteratie, met haar op dat moment gebruikte uitwisseling en eventuele oorspronkelijke bevriezing. Zij zijn geen nieuwe verse gekoppelde acceptatiecertificaten. De onafhankelijke Python-beoordelaar reconstrueert datzelfde residu uit theta/thetm1, geometrie, drukhoogten, gebruikte geleidbaarheden, randfluxen, sinks/sources en uitwisseling; de grootste afwijking is `6.939e-18 cm/d`. Er is geen succesvolle V1-eindcontrole of geaccepteerde toestand in deze route.

De definitieve O2-route kost `0.823 s`; O0 `1.079 s`. Geen censuur en geen volledige tweedaagse eindrun; elk proces stopt op de geselecteerde context na de vierde afwijzing.

## Herstel, behoud en geheugen

Na elke werkelijke rollback zijn de gemeten matrix-theta, matrixfracties, domein-/totale/compartimentvoorraden, macrovolumes, domeinbodems en sorptieklok exact gelijk aan de oorspronkelijke beginwaarden. Er is geen geaccepteerde tijdvoortgang, `SoilWater(3)` wordt niet uitgevoerd en de gecommitteerde voorraadverandering is nul.

Na de eerste drie rollbacks verschillen nog trialeventflags en nulklok-sorptiviteiten. Dat is dezelfde beperkte klasse van herberekenbaar trialwerk als eerder gemeten, geen nieuw bewijs van een schadelijke procesgeheugenfout. Na de vierde rollback zijn ook alle hier gemeten event-, referentie- en sorptiviteitsvelden exact gelijk aan de begincontext. Dit is een meting van de genoemde velden, geen volledige snapshot/restartkwalificatie van alle SAVE-toestand.

Matrix- en domeinuitwisseling blijven gepaard op afrondingsniveau; de onafhankelijke optelling verschilt maximaal `1.388e-17 cm/d`. Er is geen geaccepteerde ongereduceerde stap waarvoor een nieuwe geaccepteerde waterinventaris geclaimd kan worden. Het eerdere INVENTORY03-behoudsbewijs betreft de gereduceerde stap en wordt niet tot bewijs van ongereduceerde convergentie verheven.

Er is geen aanvullende procesgeheugenpatch geïmplementeerd. De oorspronkelijke droge/eventeindroute en korte eigen herstart blijven ongekwalificeerd.

## Bewaarde eerste proefruns

De eerste twee O0/O2-proefruns zetten bij selectie naast het niveau ook `FlDecMpRat=false`. Daardoor kregen de drie grotere stappen maar dertig iteraties, hoewel de levende begincontext via haar retryflag het oorspronkelijke dubbele budget toestaat. Die eerste afwijzingen kwalificeren het eindbesluit niet. Hun exacte bronnen, executables, runrecords en vectors blijven bewaard in `pilot-cleared-retry-flag/` en Git.

Na die constatering is uitsluitend de selectie gecorrigeerd: de oorspronkelijke flag blijft behouden en een nieuwe reductieaanvraag wordt herkend aan verandering van `IDecMpRat` uit nul, niet aan de reeds bestaande flag. De twee definitieve routes tonen daarna de afwijzingen met zestig iteraties op alle vier stapgroottes. In totaal zijn vier korte modelroutes uitgevoerd, waarvan twee voorlopige en twee definitieve. Geen tijdslimiet is verhoogd; de langzaamste van alle vier duurde `1.210 s`.

## Werkelijke bronwijziging en bewijs

Alleen `headcalc_inventory.f90` en `soilwater_inventory.f90` zijn experimentele kopieën. De eerste voegt metingen toe vóór acceptatie en vóór de oorspronkelijke afwijzingsafhandeling. De tweede voert de hierboven beschreven ene unscaled route uit en weigert de aangevraagde scaled fallback. Dit is een expliciete onderzoeksuitvoeringspolicy, geen wijziging van de oorspronkelijke reductiewet of een nieuwe algemene solver.

De native O0/O2-closures zijn via de oorspronkelijke STATE02-capsule op SHA-256 gecontroleerd. Alleen de twee observatieobjecten zijn werkelijk opnieuw gebouwd en gekoppeld met GNU Fortran 16.2.0, MSYS2 UCRT64 Windows. Definitieve compile/linkcommando's, object-/bron-/executablehashes, alle vier runrecords en de ruwe velden zijn bewaard. De losse `assess_unreduced04.py` voert alleen gegevenscontrole uit.

## Eindbesluit en volgende stap

**V1 is niet gereed voor de nu onderzochte ongereduceerde fysische referentie-eis.** De technische blokkade is concreet: de bestaande V1-iteratie haalt bij deze ene oorspronkelijke toestand geen acceptatie vóór zij de oorspronkelijke fluxreductie nodig heeft, zelfs met het volledige geërfde iteratiebudget en alle oorspronkelijke dt-verkleiningen.

Dit rechtvaardigt geen wijziging van de reductiewet, dtmin of toleranties. De meest verdedigbare afzonderlijke vervolgstap is diagnose van de stagnatie binnen uitsluitend deze toestand: oorspronkelijke bevriezing, lijnzoeker en lokale actieve procesovergangen, zonder nieuwe algemene solvercampagne. Alleen wanneer dat een concrete vergelijking rechtvaardigt, kan de **reeds bestaande** V2 met actieve koppeling op dezelfde context onder een apart begrensd contract worden vergeleken. Die vervolgstap is hier niet gestart; er is geen derde algemene variant gebouwd.

De gereduceerde V1 blijft behouden als expliciet uitgesloten numerieke onderzoeksvariant. De officiële B1.12 blijft de referentie. Er is geen promotie-PR, geen wijziging van canonical of releasebasis en geen macroporiënmigratie.

Gegevenscontrole zonder modellen: `python research/swap431-macro-b1-unreduced04/assess_unreduced04.py`.
