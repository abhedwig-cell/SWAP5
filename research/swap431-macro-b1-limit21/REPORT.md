# LIMIT21 — verzadigde domein-3-fluxbegrenzing op node 52

**De uitstroom valt weg doordat de oorspronkelijke minimumvoorraadbegrenzing actief wordt. De potentiële flux blijft positief.** Bij de verse gekoppelde evaluatie stijgt de uit het headprofiel berekende matrixgrondwaterstand boven het oorspronkelijke macrowaterniveau van domein 3. Het berekende volume onder die matrixgrondwaterstand overstijgt dan de aanwezige domeinvoorraad. De code reserveert daardoor de gehele voorraad als minimum; zonder instroom resteert geen water voor netto uitstroom. De oorspronkelijke uitstroomfactor gaat naar vrijwel nul. Dit verklaart de eerder gemeten node-52-residusprong, zonder een nieuwe fout of correctie te veronderstellen.

## Dezelfde route en grenzen

Basis is NODE20 2b1929461bebcd7bb8063a0542b17ef1f1c7e654. Precies twee native modelroutes zijn uitgevoerd, O0 en O2 vanaf het bestaande NEXT18-eigen bestand op de afgesloten grens 35797. De normale host doorloopt dezelfde aanloop, afwijzingen, rollback en gereduceerde retry. Alleen pogingen 38, 50, 51 en 52 krijgen extra domein-3-registratie. Stop blijft commit 42 of 16 gemeten seconden, met harde proceslimiet 20 seconden.

O0 stopt normaal na **0,672 s**, O2 na **0,647 s**. Geen censuur, extra variant, langere periode, herconstructie van een latere toestand of brede campagne. Instrumentatie voegt alleen diagnostische scalars en WRITE/FLUSH/CLOSE toe. Fysica, BAL, native codec, solver, tolerantie, dt, freeze/refresh en reductieregels zijn ongewijzigd.

Alle 42 geaccepteerde budgetregels, 52 headpogingen zonder timing, oorspronkelijke native/beginexports en alle bestaande NODE20-operator-/iteratierecords zijn exact behouden. De extra trace bevat **672 records voor 224 echte MACRORATE-evaluaties** per optimalisatie; de extra O0/O2-traces zijn bytegelijk. Ook een oorspronkelijke afgeleide-aanroep berekent in MACRORATE eerst rates: daarom registreert de trace zowel rates- als afgeleideverzoeken en geeft iedere evaluatie een eigen volgnummer.

## Geobserveerde beslisketen

Voor de geselecteerde standaarddomeinprocedure zijn potentiële hoeveelheden over dt gemeten, niet alleen afgeleide fluxrates:

1. `Wtmp = W + InPot − OutPot`.
2. `Wmin = min(volume onder actuele matrix-GWL, W)` voor domein 3. De bijzondere rapid-drainage-aanvulling geldt alleen domein 1.
3. `OutExcess = max(0, Wmin − Wtmp)`.
4. Eventuele herverdeling kan dit overschot later verminderen. In alle geselecteerde evaluaties is het te herverdelen oppervlakte-instroomoverschot nul: deze tak is niet actief en OutExcess blijft exact gelijk.
5. De oorspronkelijke factor is aanvankelijk 1. Als `OutExcess/dt > 1e-7`, gebruikt de code bij `OutPot > OutExcess` de factor `max(0, 1 − OutExcess/OutPot)`; anders wordt hij 0.
6. `QOutSat(3,52) = factor × OutSatPot(3,52) / dt`.

De invoerfactor blijft bij alle 224 domein-3-evaluaties 1: beperking door de maximumvoorraad verklaart deze resultaten niet. Iedere genoemde formule en beide beslispredicaten zijn onafhankelijk uit de trace nagerekend. Ook de domeintotalen sluiten. De uit de actuele in-/uitrates gereconstrueerde proef-eindvoorraad blijft op of boven het oorspronkelijke minimum. Dit is controle van lokale proefberekeningen, geen geaccepteerde volledige periodebalans.

## Concrete laatste verse controle van poging 50

De laatste tijdelijk hergebruikte domein-3-rate komt uit vectorberekening 40 in iteratie 28. De verse V1-controle is vector 43 in iteratie 30. De operator vóór die controle gebruikt al het nieuwe headprofiel maar nog de oude rate; onderstaande bronkolom toont waar die oude rate werkelijk is berekend. De twee ratebronnen hebben dus verschillende heads. De eerdere NODE20-voor-/napaarvergelijking op hetzelfde actuele headprofiel blijft exact behouden.

| Grootheid | Bron van hergebruikte rate | Verse evaluatie |
| --- | ---: | ---: |
| h52, cm | 3,066434199927 | 3,074107012827 |
| Matrix-GWL, cm | −65,319723253534 | −65,313911069575 |
| Oorspronkelijk macrowaterniveau, cm | −65,319272862328 | −65,319272862328 |
| Aanwezige domeinvoorraad W, cm | 0,03536675615448 | 0,03536675615448 |
| Vrij water boven Wmin, cm | 0,00000200850132330 | 0 |
| Potentiële totale instroom, cm | 0 | 0 |
| Potentiële node-52-uitstroom, cm/dag | 0,00942333593638 | 0,00930563395888 |
| Toegepaste uitstroomfactor | 1 | circa 1,006×10⁻¹³ |
| Actuele node-52-uitstroom, cm/dag | 0,00942333593638 | circa 9,360×10⁻¹⁶ |

Bij de verse evaluatie bedraagt het volume onder matrix-GWL **0,03539066685190 cm**. Dat is groter dan de voorraad **0,03536675615448 cm**, zodat Wmin exact W wordt. De potentiële totale uitstroom is **7,315094718297236×10⁻⁷ cm**; Wtmp wordt **0,03536602464501085 cm**. Het berekende uitstroomoverschot is **7,3150947182965×10⁻⁷ cm**, vrijwel gelijk aan de volledige potentiële uitstroom.

Het overschot/dt is veel groter dan 1e-7, dus de beperkingstak is actief. Door afronding in de oorspronkelijke voorraad-aftrekkingen is `OutPot > OutExcess` hier nog net waar en resteert de kleine positieve factor in de tabel. Dit is numeriek vrijwel nul; er is geen alternatieve nulafkap of tolerantie ingevoerd. De potentiële nodeflux daalt slechts beperkt, terwijl het ontbreken van vrij water de actuele flux vrijwel geheel onderdrukt.

De term **vrij water** betekent hier water boven de oorspronkelijke minimumvoorraad, niet dat het domein fysiek leeg is. Er is circa 0,03537 cm water aanwezig dat de code als minimum behoudt.

## Andere geselecteerde afwijzingen en herstel

Dezelfde laatste freeze/refresh-overgang is ook bevestigd bij poging 38 en bij de oorspronkelijke minimumstap-poging 51:

| Poging | Vrij water bij bron hergebruikte rate, cm | Vrij water bij verse controle | Potentiële node-uitstroom bij verse controle, cm/dag | Actuele node-uitstroom erna, cm/dag |
| --- | ---: | ---: | ---: | ---: |
| 38 | 0,0000639272578912 | 0 | 0,00867031986714 | 2,455×10⁻¹⁶ |
| 50 | 0,00000200850132330 | 0 | 0,00930563395888 | 9,360×10⁻¹⁶ |
| 51 | 0,0000154865194231 | 0 | 0,00927401180326 | 5,614×10⁻¹⁴ |

In die bronberekeningen was voldoende water boven het minimum beschikbaar voor alle potentiële uitstroom. Bij de verse berekeningen is de matrix-GWL hoger dan het behouden macrowaterniveau en reserveert Wmin alle aanwezige voorraad. Er is daarbij geen sprong in het indexnummer van de bovenste verzadigde matrixnode: dit blijft 50. De niveaus en begrenzingsactiviteit veranderen wel.

Poging 52 blijft de oorspronkelijke echte retry met FrReduQ=0,1 en acceptatie na drie iteraties. Aan het einde is er positieve potentiële domeininstroom, is geen uitstroomoverschot actief en is de uitstroomfactor 1. Op node 52 is de potentiële verzadigde uitstroom dan zelf nul en bestaat er verzadigde instroom naar het domein. Er is bij de laatste verse controle geen verandering van de node-52-uitwisselingsoperator. Dit beschrijft de werkelijk gereduceerde route; het bewijst geen ongereduceerd alternatief.

## Betekenis en resterende grens

De eerder ontbrekende stap is nu vastgesteld: de verse berekening van matrix-GWL activeert de oorspronkelijke minimumvoorraadconstraint en daarmee de domeinbrede uitstroomfactor. Het vastgehouden operatorbeeld volgt die veranderende beperking pas bij de verse V1-evaluatie. De V1-afwijzing voorkomt hier dus acceptatie op basis van de achterhaalde macrofluxen.

De gemeten formules en beslissingen zijn intern consistent met de bestaande bron. Er is geen fout aangetoond in een ontbrekende voorraad, herverdeling, vermenigvuldiging of verkeerde keuze tussen potentieel en actueel. Dit is geen algemene fysische validatie van het minimumvoorraadcontract, noch een bewijs over alle begrenzings- of Jacobiaantakken. De domein-3-voorraadgrens is een actieve constraint binnen de gekoppelde berekening; de diagnose levert op zichzelf geen rechtvaardiging om haar, het freezebeleid of de criteria te veranderen.

Geen correctie, parameterwijziging, factor-0,01-vervolg, algemene solvervariant, volledige tweede BAL-periode of referentiepromotie. Eventueel verder werk vraagt een afzonderlijke afbakening rond de consistente behandeling van deze actieve begrenzing in de gekoppelde iteratie. Dat werk is hier niet uitgevoerd of automatisch gestart.

Herbeoordeling zonder modellen: assess_limit21.py. RESULT.json bewaart de oude ratebron en verse evaluatie per geselecteerde poging. TRACE_FIELDS.json beschrijft alle 43 kolommen en de drie meetfasen. De bronpatch, oorspronkelijke eigen bestanden, builds en het geverifieerde LIMIT21_EVIDENCE.zip bewaren het herstelpad.
