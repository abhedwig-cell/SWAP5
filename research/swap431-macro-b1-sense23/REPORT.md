# SENSE23 — gevoeligheid van de actieve minimumvoorraad en proefstaatherstel

**De GWL-keten en een ontbrekende niet-lokale macrogevoeligheid zijn numeriek bevestigd.** Bij dezelfde gedeeltelijk actieve domein-3-begrenzing beïnvloedt h50 de uitwisseling op node 52 met circa **−0,87360973 per dag**. De bestaande macro-Jacobiaan heeft op die niet-tridiagonale positie geen bijdrage. Twee perturbatiegroottes en O0/O2 geven hetzelfde resultaat. Alle expliciet vastgelegde providerstaat herstelt bytegelijk na iedere probe, en de oorspronkelijke FRESH22-iteratie gaat daarna numeriek exact verder.

Dit is een lokale gevoeligheids- en transactiecontrole van MACRORATE, geen nieuwe solver, volledige residu-Jacobiaan, geconvergeerde headpoging of volledige tweede BAL-periode.

## Oorspronkelijke meetcontext en grenzen

Baseline is FRESH22 4976c403d7eeeb7c8158d2b34d3d07c1585ffe96. Dezelfde native aanloop bereikt headpoging 38, t1900=35797,070666666681, dt=0,0013333333333333333. Binnen diezelfde current-operator-poging wordt precies één toestand geselecteerd: iteratie 30, na de bestaande Jacobiaanevaluatie en vóór de volgende tridiagonale oplossing. De h50/h51/h52-waarden zijn respectievelijk −0,2651396357450431, 1,369870475797295 en 3,062061139766548 cm. De grens is gedeeltelijk actief.

Per O0/O2 worden in hetzelfde proces veertien MACRORATE-evaluaties gedaan: basis, centrale perturbaties van h50/h51/h52 met ±1e-4 en ±5e-5 cm, en opnieuw de basis. Geen andere modelcontext, dt, parameter of solvervariant is toegevoegd. Theta wordt zoals in headcalc opnieuw uit het proefhead bepaald; SWKIMPL=0 houdt de oorspronkelijke matrixconductiviteit tijdens deze poging vast. De macroprovider berekent zelf GWL, geometrie, potentiële fluxen en begrenzingen opnieuw. Alleen de macrooperator wordt geprobed; boundtop, rootextraction en de volledige residuvector worden niet als extra operator aangeroepen.

De normale afwijzing na 30 iteraties blijft exact behouden. De route eindigt zoals FRESH22 na return van deze poging, vóór de volgende hostretry of commit. De harde proceslimiet blijft twintig seconden.

## GWL-keten en fluxgevoeligheden

Alle veertien punten blijven binnen dezelfde gedeeltelijke begrenzingstak: de minimumvoorraad is het volume onder de actuele matrix-GWL, de instroomfactor is 1 en er is geen herverdeling van oppervlakte-instroomoverschot. Het verzadigde matrix-indexnummer blijft 50. De domeingeometrie blijft in deze lokale perturbaties gelijk.

De centrale verschillen bij epsilon=5e-5 cm geven:

| Gevoeligheid naar | dGWL/dh | dWmin/dh | dQ domein3,node52/dh | dQ totaal,node52/dh |
| --- | ---: | ---: | ---: | ---: |
| h50 | 1,0248696114 | 0,00457036448 | −0,8736097313 | −0,8736097313 |
| h51 | 0,1983644148 | 0,00088459807 | −0,1649258767 | −0,1649258767 |
| h52 | 0 | 0 | −0,0101621315 | −0,1236791226 |

De fluxgevoeligheden hebben eenheid per dag; voorraad- en GWL-gevoeligheden zijn ten opzichte van cm head. Q is positief van macro naar matrix. De macrobijdrage aan residu F heeft het tegengestelde teken.

De GWL-interpolatie tussen h50 en h51 geeft analytisch:

`GWL = z51 + disnod51*h51/(h51−h50)`.

De analytische afgeleiden zijn 1,02486961047 naar h50 en 0,198364414743 naar h51. De centrale verschillen sluiten hierop aan binnen 1e-8. De volumeketen sluit eveneens: `dWmin = (VlMpDmCp(3,50)/dz50)*dGWL`, met volumedichtheid 0,004459459459459437. De lokale verandering van h52 verandert de GWL en Wmin in deze tak niet.

Voor de gedeeltelijke beperking is ook de keten uit CONTRACT.md getoetst:

`df = −(dWmin−dI+dO)/O + E*dO/O²`

`dq52 = (f*do52 + o52*df)/dt`.

De rechterleden gebruiken de werkelijk gemeten potentiële domeintotalen en nodecomponent, niet een onbeperkte surrogaatflux. De gereconstrueerde domein-3-fluxafgeleide wijkt minder dan 1e-8 af van het rechtstreeks geprobeerde centrale verschil. De twee epsilonwaarden verschillen voor de totale node-52-macrogevoeligheid minder dan 1e-7; de grootste gemeten afwijking is ongeveer 2,4e-9.

Voor h50 veranderen de potentiële instroom, potentiële totale uitstroom en potentiële node-52-uitstroom in deze probe niet. De volledige gemeten fluxverandering volgt daar dus uit de GWL/minimumvoorraad/factor-keten. Voor h51 verandert ook de potentiële totale domeinuitstroom; voor h52 verandert de potentiële nodecomponent zelf. Die bijdragen zijn afzonderlijk bewaard in RESULT.json.

De huidige headcalc voegt de macro-afgeleide uitsluitend aan de centrale diagonaal toe. De niet-nulle gevoeligheid van node-52-macroflux naar h50 valt twee kolommen van die diagonaal en zelfs buiten de gewone tridiagonale rij. Hiermee is de eerder alleen uit bronanalyse afgeleide niet-lokale koppeling nu daadwerkelijk gemeten. Er wordt geen volledige vervangende Jacobiaan of convergentiegarantie uit drie richtingen afgeleid.

## Gecontroleerd proefstaatherstel

De transactie gebruikt geen native eigenbestand als onvolledige trialserializer. Zij bewaart de geauditeerde, expliciet persistente closure van deze MACRORATE-probe:

- Alle 90 eigen velden van MOD_macropore en 73 velden van MOD_swap_mp, inclusief volledige arrays en providerwerkvelden.
- Zestien hostvelden voor h/theta/k, conductiviteitswerkvelden, GWL-uitvoer en vaste proefcontext.
- Alle 104 expliciet SAVE-lokalen van MACRORATE, de twee SAVE-arrays van SATFLOW, drie SAVE-arrays van ABSORPTION en acht onder blanket-SAVE vallende CALCGWL-lokalen. Inclusief diagnostische limiterwerkvelden en het macrovolgnummer.

TRANSACTION_FIELDS.json legt de exacte veldnamen vast. De overige lokale scratch van de geselecteerde oproepclosure heeft geen expliciete persistente Fortran-status en wordt niet als een algemeen geheugenbeeld geclaimd. De modulevelden die MPVOLUME bijwerkt vallen binnen de snapshot. Er is geen algemene serializer voor andere SWAP-routines toegevoegd.

De snapshot is **20.347.880 bytes**. Na iedere probe wordt de basis teruggelezen en opnieuw uitgeschreven. Alle veertien na-herstelbestanden én de definitieve snapshot zijn bytegelijk aan de basis, met SHA256 `aec5d4383614499853fe809018b53844d54d852a205a77f45c28ea28378f62c3`. O0 en O2 hebben dezelfde snapshotinhoud. De twee nulperturbaties geven exact dezelfde limiterwaarden en volledige macro-uitwisselingsvector.

Na herstel gaat de normale tridiagonale oplossing verder. Alle 36 reeds geaccepteerde budgetregels, 38 headpogingen zonder timing, node-operator-/iteratietraces, limitertrace, laatste proefresiduen en teruggekeerde h/theta zijn bytegelijk aan FRESH22. De afwijzing blijft maxresidu 1,1430423626257458e-4 op node 52 en somresidu −4,4840884740053887e-4. De probes worden nergens als geaccepteerde stap geïnstalleerd.

De instrumentatie bewaart en herstelt daarnaast de IEEE-status bij ingang van de probescope, na ieder punt en bij vertrek. De opaque statuswoorden komen binnen elk proces exact overeen; zij worden niet tussen processen als draagbaar gegevensformaat vergeleken. De uitvoeringen melden bij afsluiten nog `IEEE_DENORMAL`; deze melding is bewaard en haar herkomst buiten de afgebakende transactie is niet afzonderlijk vastgesteld. Er wordt daarom geen algemene identiteit van alle floating-pointstatus ten opzichte van de ongewijzigde FRESH22-binary geclaimd. De vastgelegde providerdata, basisherhaling en numerieke voortzetting zijn wel exact, evenals herstel naar de IEEE-status bij scope-ingang.

## Uitvoeringen en uitsluitingen

De eerste O0/O2-instrumentatieprocessen stopten bij initialisatie met SIGSEGV doordat de normale CALCGWL-route doorliep naar het toegevoegde snapshot-entrypoint. Deze invoegfout is hersteld met een expliciete normale return; de twee mislukte runs blijven als RESUME bewaard. Er waren daarvoor ook herstelde voorbereidings-/linkfouten, zonder succesvolle meetroute.

Daarna zijn de twee geselecteerde meetroutes uitgevoerd als RESUME_VERIFIED. Na toevoeging van expliciet IEEE-herstel zijn dezelfde veertien punten nogmaals uitgevoerd als RESUME_IEEE. Totaal dus **zes modelprocesaanroepen: twee setupfouten en vier succesvolle uitvoeringen**, geen zes inhoudelijke varianten. Alle processen bleven onder twintig seconden en zijn ongecensureerd. Zelfs de opgetelde modelprocesduur over deze herhalingen blijft per optimalisatie onder drie seconden. De definitieve processen duren **1,175 s O0** en **1,126 s O2**. De eerste en definitieve succesvolle meetwaarden zijn bytegelijk.

De lokale GWL-/voorraadketen en het afgebakende proefstaatherstel zijn hiermee gekwalificeerd. Er is geen geconvergeerde solvercorrectie, algemene branchgrensafgeleide, volledige Jacobiaan, factor-0,01-route, native restartuitbreiding, volledige tweede BAL-periode of referentiepromotie. Een eventuele minimale solveraanvulling moet de nu gemeten niet-lokale actieve koppeling kunnen vertegenwoordigen; een correctie alleen aan de node-52-diagonaal is hiermee niet onderbouwd.

Herbeoordeling zonder modellen: assess_sense23.py. Ruwe probes, schema, bronpatch, builds, foutregistraties en de geverifieerde SENSE23_EVIDENCE.zip bewaren de herstelbare bewijsbasis.
