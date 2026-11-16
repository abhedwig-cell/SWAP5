# NODE20 — oorspronkelijke node-52-afwijzing

**De geselecteerde afwijzing is een herhaalde cyclus van oplossen met tijdelijk vastgehouden macrofluxen en afwijzen bij verse gekoppelde evaluatie.** Op hetzelfde headprofiel veranderen bij die evaluatie uitsluitend de macro-uitwisselingsbijdragen. De grootste bijdrage komt van het vrijwel verdwijnen van verzadigde uitstroom uit macrodomein 3 naar de matrix. Dit is aangetoond met identieke O0/O2-traces. De onderliggende oorzaak van die veranderende verzadigde flux is nog niet als codefout vastgesteld; geen fysische of solvercorrectie uitgevoerd.

## Oorspronkelijke context en grenzen

Basis is DIAG19 2242ff1836016339e023337a16fd6a8861e00c4c, met het bestaande NEXT18-eigen V5-bestand op de afgesloten daggrens 35797. Precies twee modelroutes zijn uitgevoerd: een vers native proces voor O0 en O2. De normale oorspronkelijke host doorloopt de aanloop en retries; er is geen headprofiel geïnjecteerd of poging zelfstandig gereconstrueerd.

De vooraf geselecteerde headpogingen zijn 38, 50, 51 en 52. Poging 38 is de eerste oorspronkelijke afwijzing met node 52 als grootste residu. Pogingen 50/51 zijn de eerder gelokaliseerde eerste minimumstap-afwijzing en haar directe aanloop; poging 52 is de daaropvolgende echte gereduceerde retry. De route stopt na de bijbehorende commit 42, of na 16 gemeten seconden als dat eerder gebeurt. De harde proceslimiet blijft 20 seconden. Werkelijke procesduur: O0 **0,598 s**, O2 **0,437 s**, beide normaal gestopt en ongecensureerd. Geen brede campagne, gewijzigde stapregels of langere periode.

Alle fysica, V1-certificering, oorspronkelijke Darcycorrectie, native codec, BAL-code en acceptatie-/reductiecriteria blijven behouden. instrumentation.patch bevat alleen observaties, tellers en de geselecteerde vroege stop. Iedere node-vectorrecord splitst de daadwerkelijk gebruikte F op; er worden geen extra operator- of afgeleide-aanroepen voor een probe uitgevoerd.

## Identiteit en onafhankelijke reconstructie

Alle 42 geaccepteerde budgetregels en alle 52 headpogingen zonder timingkolom zijn exact gelijk aan DIAG19. Native installatie, ledger en beginexports blijven bytegelijk. O0/O2 produceren bytegelijke node-traces: **197 operatorrecords en 591 iteratierecords** per optimalisatie. De oorspronkelijke twee retry-afwijzingen en de gereduceerde acceptatie hebben precies dezelfde residuen als eerder.

Voor elk operatorrecord is onafhankelijk gereconstrueerd:

`F52 = opslag + sink − source + wortelopname − kmean52*hgrad52 + kmean53*hgrad53 − QExcMpMtx52`.

De maximale reconstructieafwijking is **2,51535×10⁻¹⁷**. De totale macro-uitwisseling is daarnaast gelijk aan de som van vijf domeinen. Per domein sluit de opsplitsing in onverzadigde uitstroom, verzadigde uitstroom, verzadigde instroom en perched-zone-instroom. De tekens volgen de bron: positieve QExc voedt de matrix en wordt van F afgetrokken.

In alle geselecteerde node-52-vectoren is theta=0,444 en de opslagterm nul. Wortelopname en source zijn eveneens nul. De sink en verticale matrixtermen blijven bij iedere gekoppelde voor-/naevaluatie exact gelijk. De actuele onverzadigde absorptiefluxen zijn alle nul. De guarded ABSORPTION-trace is leeg: er is geen record voor deze node in de geselecteerde absorptieberekeningen. De niet-nulle uitwisseling in de operator komt hier uit de verzadigde componenten.

## Iteratievoortgang en de verse sprong

| Poging | Begin t1900 | Gebruikte dt, dag | Iteraties | Verse controles | Uitkomst |
| --- | ---: | ---: | ---: | ---: | --- |
| 38 | 35797,07066666668 | 0,0013333333333 | 30 | 6 | Afwijzing |
| 50 | 35797,07125645635 | 0,00002 | 30 | 6 | Afwijzing |
| 51 | 35797,07125645635 | 0,00001 | 60 | 12 | Afwijzing en reductieverzoek |
| 52 | 35797,07125645635 | 0,0001414213562 | 3 | 1 | Acceptatie met factor 0,1 |

In de ongereduceerde pogingen ontstaat omstreeks iedere vijfde iteratie een voorlopig klein residu met flunsatok(3)=true: macrofluxen worden tijdelijk hergebruikt. V1 zet die vlaggen bij voorlopige convergentie terug en berekent de gekoppelde vector opnieuw. Het headprofiel blijft bij die controle exact gelijk, maar de macrofluxen veranderen. Het residu overschrijdt vervolgens opnieuw de oorspronkelijke criteria. Poging 38 benadert daarbij een herhalende vijf-iteratiecyclus; de laatste controleheads in iteraties 20, 25 en 30 zijn ongeveer 3,120444144119 cm. Meer iteraties binnen het oorspronkelijke uitgebreide budget maken poging 51 evenmin acceptabel.

Onderstaande waarden horen bij de laatste verse controle van iedere poging. F en fluxbijdragen zijn in cm/dag; de head staat in cm.

| Poging | h52 | F52 vóór verse controle | F52 erna | Sprong in −QExc52 |
| --- | ---: | ---: | ---: | ---: |
| 38, iteratie 30 | 3,120444144119 | −8,92467×10⁻¹² | 0,0167522750183 | 0,0167522750272 |
| 50, iteratie 30 | 3,074107012827 | −2,52159×10⁻¹³ | 0,0102943305696 | 0,0102943305699 |
| 51, iteratie 60 | 3,076168413058 | −4,55663×10⁻¹³ | 0,0110731780563 | 0,0110731780568 |
| 52, iteratie 3 | 4,414745614153 | 1,79695×10⁻¹¹ | 1,79695×10⁻¹¹ | 0 |

Voor **alle 25 verse controles** zijn de matrixtermen en heads vóór/na exact gelijk en wordt de volledige residusprong door de verandering in de macrobijdrage gereconstrueerd. De laatste ongereduceerde Jacobiaanfasen gebruiken de freezevlag; de bron slaat daar de actuele macro-afgeleide-aanroep over. Dit is registratie van de bestaande benaderingsprocedure, geen bewijs dat de complete gekoppelde Jacobiaan elders correct of incorrect is.

## Welke macrobijdrage verandert?

Voor poging 50, iteratie 30:

| Werkelijke verzadigde flux | Vóór verse controle | Erna |
| --- | ---: | ---: |
| Matrix naar macrodomein 1 | 0,1430198730741 | 0,1437166687809 |
| Matrix naar macrodomein 2 | 0,0142147061818 | 0,0143889051085 |
| Macrodomein 3 naar matrix | 0,00942333593638 | circa 9,36×10⁻¹⁶ |

De uitstroom uit domein 3 valt dus vrijwel weg. Samen met de extra instroom naar domeinen 1 en 2 geeft dit de totale residusprong van 0,0102943305699. In poging 51 gebeurt hetzelfde: domein-3-uitstroom verandert van 0,00948819826201 naar circa 5,61×10⁻¹⁴, naast toenemende instroom naar domeinen 1 en 2. De gereduceerde poging 52 heeft bij haar eindcontrole geen macrofluxsprong en voldoet ook aan de totale en compartimentcriteria; het grootste resterende residu ligt dan op node 50, niet node 52.

De heads op node 52 blijven in de geselecteerde ongereduceerde trajecten rond **+3 cm**. Dit is geen herhaling van de eerdere onverzadigde Darcy-/sorptieovergang rond −10 cm. De verzadigde stroming kan uiteraard zelf hydraulische headverschillen gebruiken; de afwezigheid van de onverzadigde absorptiebijdrage betekent niet dat alle Darcyfysica afwezig is.

## Diagnosegrens

De mechanische bron van de gemeten residusprong is nu gelokaliseerd: verzadigde macro-uitwisseling bij freeze/refresh. Waarom specifiek de domein-3-uitstroom bij die herberekening vrijwel nul wordt, is nog niet volledig vastgesteld. Potentiële fluxen, beschikbaar water en begrenzingsbeslissingen binnen de verzadigde macroverdeling zijn hier niet apart vastgelegd. Uit alleen de actuele rates volgt geen bewezen fout in waterbeschikbaarheid, stroombegrenzing, afgeleiden of eventgeheugen.

Daarom geen aanpassing van fysica, Newtoncriteria, freezebeleid, iteratiebudget, dt of reductiepolicy. De eerste gereduceerde retry is geobserveerd; geen variant zonder freeze, extra kleinere retry, factor-0,01-verloop, latere periode of volledige BAL-kwalificatie toegevoegd. De kleinste eventuele volgende diagnose zou de verzadigde domein-3-potentiaal en feitelijke begrenzing bij dezelfde voor-/naevaluatie volgen. Dat is een afbakening, geen automatisch gestarte campagne.

assess_node20.py herbeoordeelt dit resultaat zonder modellen. RESULT.json bevat iedere verse voor-/napaar. TRACE_FIELDS.json beschrijft de kolommen en stagebetekenis. De oorspronkelijke eigen bestanden, builds, patches en geverifieerde NODE20_EVIDENCE.zip bewaren het herstelpad. Status blijft diagnose; geen officiële promotie.
