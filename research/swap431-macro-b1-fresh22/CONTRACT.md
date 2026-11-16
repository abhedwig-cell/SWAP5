# Afgebakend contract voor de actieve minimumvoorraad in de gekoppelde iteratie

Dit contract betreft uitsluitend de oorspronkelijke standaard-macrodomeinprocedure, dezelfde node-52-afwijzing en domein 3. Het wijzigt geen fysische vergelijking, voorraadgrens, drempel of acceptatiecriterium. Het is een afbakening van een consistente numerieke behandeling, geen reeds gevalideerde solverimplementatie.

## 1. Eén operator bij één proefprofiel

Voor een geaccepteerde beginstaat S en oorspronkelijke dt moet de gebruikte residuvector F(h;S,dt) bij ieder proef-headprofiel h de actuele matrix-GWL, geometrie, potentiële fluxen, minimumvoorraad, uitstroomoverschot, native beslispredicaten en actuele fluxen samen bepalen. De residu- en line-searchnorm moeten uit diezelfde evaluatie komen. Een oude rate met een nieuw h is geen actuele evaluatie van dit contract.

Een numerieke optimalisatie mag alleen resultaten hergebruiken als zij de geldigheid voor het actuele profiel waarborgt. Alleen kijken of de oude limiterfactor 1 was, volstaat niet: LIMIT21 laat zien dat de grens tijdens de headverandering actief wordt. De minimumvoorraad op de oude GWL vastzetten zou het bestaande fysische model veranderen en valt buiten dit contract.

## 2. Behoud de oorspronkelijke grens en branchvolgorde

Voor de hier gemeten tak gelden, met hoeveelheden over dt:

`T = W + I − O`

`L = min(VonderGWL(h), W)`

`E = max(0, L − T)`

De bestaande eventueel volgende herverdeling blijft onderdeel van de operator; zij is in het geselecteerde bewijs niet actief. De native drempel `E/dt > 1e-7`, de vergelijking `O > E` en de bestaande max(0,...) worden ongewijzigd uitgevoerd. Er wordt geen nieuwe epsilon, waterbron, gladstrijking of versoepelde residugrens toegevoegd.

In het geselecteerde bereik blijft de instroomfactor 1. Daar zijn de branches:

- Geen actieve uitstroombeperking: factor f=1 volgens de native drempelbeslissing.
- Gedeeltelijke beperking: f=1−E/O als de native tak dit kiest.
- Volledige beperking: f=0 als de native vergelijking en afkap dit opleveren. Door oorspronkelijke voorraadsubtracties kan in de grenssituatie een zeer kleine positieve f overblijven; die rekenvolgorde blijft behouden.

De gebruikte componentflux is `q_k=f*o_k/dt`. Zij moet zowel in de matrixresiduvector als in de macrovoorraadrekening dezelfde waarde hebben. De diagnostische uitspraak dat vrij water nul is, vervangt niet de oorspronkelijke factorberekening.

## 3. Newtongevoeligheid moet de actieve beperking bevatten

Voor een Newtonbehandeling is alleen opnieuw berekenen van q onvoldoende om de bestaande afgeleide tot de afgeleide van die operator te maken. Binnen de gedeeltelijk actieve tak, zonder herverdeling of actieve instroombeperking:

`df = −dE/O + E*dO/O²`

`dE = dL − dI + dO` bij vaste geaccepteerde W.

`dq_k = (f*do_k + o_k*df)/dt`.

Voor L geldt lokaal `dL=dVonderGWL` als het volume onder matrix-GWL kleiner is dan W, en `dL=0` als W de minimumkeuze bepaalt. De gevoeligheid van dat volume bevat de keten via de actuele matrix-GWL en, waar relevant, de head-afhankelijke geometrie. Bij een branchgrens bestaat niet automatisch één klassieke afgeleide: de gekozen eenzijdige/actieve tak moet expliciet worden behandeld en iedere trial opnieuw aan de oorspronkelijke branchpredicaten worden getoetst.

Dit is een analytische afleiding van de bestaande beperkte flux. De huidige SATFLOW-afgeleide gebruikt actuele rate gedeeld door het opgeslagen headverschil; zij bevat geen expliciete ketenregel voor f, E of L. headcalc voegt de macrobijdrage bovendien alleen aan de centrale diagonaal toe. Dat is een benadering, geen volledige afgeleide van deze head-afhankelijke domeinbrede begrenzing.

## 4. Domeinbrede en ruimtelijke afhankelijkheid niet weglaten

De factor deelt het totale uitstroomoverschot door de totale potentiële domeinuitstroom en werkt door op alle uitgaande componenten van het domein. De matrix-GWL volgt uit heads elders in het profiel. De gewijzigde flux op node 52 hoeft daarom niet uitsluitend van h52 of zijn onmiddellijke buren af te hangen.

Een consistente linearisatie moet die afhankelijkheden kunnen vertegenwoordigen; alleen een lokale correctie aan dFdhM(52) zonder onderbouwing volstaat niet. Dit contract kiest nog geen algemene dichte solver, geen volledige numerieke Jacobiaan en geen brede solververvanging. Eerst moet voor dezelfde oorspronkelijke proefcontext de benodigde gekoppelde gevoeligheid worden gekwantificeerd.

## 5. Proefstaat, afwijzing en acceptatie

De geaccepteerde voorraad en beginhistorie blijven tijdens Newton/line search de vaste basis S. Werkarrays die de provider tijdens een evaluatie bijwerkt moeten bij herhaalde evaluatie dezelfde operator voorstellen. Een afwijzing moet de oorspronkelijke herstel- en retryprocedure behouden; een mislukte probe mag geen geaccepteerde commit worden.

De bestaande V1-controle blijft verplicht voor eventuele acceptatie. Alleen de oorspronkelijke compartiment-, totale balans-, head- en pondingcriteria bepalen de toelating. Een betere maar nog te grote restfout is geen acceptatie. Een nieuwe methode moet ook haar gekozen actieve tak bij de definitieve evaluatie opnieuw bevestigen.

## 6. Wat is nu bewezen en wat blijft nodig?

FRESH22 bewijst met O0/O2 dat de noodzakelijke actuele-evaluatiestap uitvoerbaar is zonder wijziging van fysica of criteria, maar bij de geselecteerde originele dt niet voldoende is voor convergentie binnen 30 iteraties. De twee runs veranderen uitsluitend het macro-freezegedrag binnen poging 38; zij implementeren nog geen constraint-consistente Jacobiaan. Geen claim dat een betere Jacobiaan op zichzelf gegarandeerd convergeert.

De kleinste volgende afbakening is een lokale controle van de gekoppelde gevoeligheid bij dezelfde gedeeltelijk actieve begrenzing, inclusief de GWL-keten, domeintotalen en branchkeuze. Daarvoor moet een probe de providerwerkstaat gecontroleerd kunnen herstellen en opnieuw dezelfde residuoperator oproepen. Pas na zo'n controle kan een minimale numerieke aanvulling worden gekozen en afzonderlijk getoetst. Dit contract autoriseert of start geen aanvullende modelcampagne; de huidige opdracht eindigt met deze afbakening en de ene onderzochte kandidaat.
