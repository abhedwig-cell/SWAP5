# Stromingen manuscript draft

## Werkstatus

Ruwe eerste tekst voor secties 1 tot en met 5. Niet voor indiening. Feiten over de actuele NHI-softwarecontext zijn gecontroleerd op 19 september 2026. De tekst volgt de firewall in STROMINGEN_OVERVIEW_ARTICLE_PLAN.md.

# Van SWAP naar een modulair hydrologisch instrumentarium

## 1. Hydrologische modellering in beweging

Wie aan het Nederlandse watersysteem rekent, krijgt zelden met één hydrologisch domein tegelijk te maken. Neerslag en verdamping werken door in bodemvocht en gewasverdamping, de onverzadigde zone wisselt water uit met het grondwater, en grondwater en oppervlaktewater beïnvloeden elkaar. Voor regionale en landelijke toepassingen komt daar nog waterverdeling en beheer bij. Juist op die grenzen tussen deelsystemen ontstaat de behoefte aan modellen die niet alleen afzonderlijk goed functioneren, maar ook gecontroleerd met andere modelcomponenten kunnen samenwerken.

Het Nederlandse hydrologische instrumentarium verandert op dit punt zichtbaar. Binnen het NHI zijn eind 2025 stabiele releases opgeleverd van iMOD Python voor de opbouw van MODFLOW 6-modellen en van de iMOD Coupler voor de koppeling tussen MODFLOW 6 en MetaSWAP. Voor Ribasim kwam eveneens een stabiele release beschikbaar. Volgens het NHI vormt Ribasim een basis voor de vervanging van bestaande oppervlaktewatermodules als MOZART, DM en SIMRES, terwijl regionale waterbeheerders Ribasim inmiddels ook in combinatie met MODFLOW 6 toepassen [1]. De iMOD Suite bevat daarnaast expliciet een coupler om MODFLOW 6 met andere modelcodes te verbinden [2].

Deze ontwikkeling betekent niet dat er één nieuw model ontstaat dat alle hydrologie in zich opneemt. Het beeld is eerder dat gespecialiseerde componenten ieder een deel van het watersysteem beschrijven en via expliciete koppelingen informatie uitwisselen. MODFLOW 6 richt zich op het grondwater. Ribasim beschrijft de waterbalans, het netwerk en de waterverdeling in het oppervlaktewatersysteem [3]. Voor de onverzadigde zone bestaat in Nederland een lange traditie rond SWAP en MetaSWAP. Juist daar vindt op dit moment opnieuw een belangrijke ontwikkeling plaats.

Dit artikel beschrijft die ontwikkeling vanuit SWAP. Het doel is niet om nieuwe wetenschappelijke resultaten vooruit te lopen. We willen vooral laten zien waarom de modernisering van SWAP relevant is voor een modulair hydrologisch instrumentarium, welke plaats koppeling met grondwater en oppervlaktewater daarin heeft, en waarom kwalificatie van afzonderlijke componenten én hun onderlinge uitwisseling een belangrijk onderdeel van die ontwikkeling is.

## 2. SWAP in een veranderende modelomgeving

SWAP heeft een lange geschiedenis. De oorsprong van Soil Water Atmosphere Plant ligt in werk uit de jaren zeventig. In 2024 werd het vijftigjarig bestaan van het model gevierd, waarover in 2025 ook in Stromingen is teruggeblikt [4]. In die halve eeuw is SWAP uitgegroeid tot een procesgebaseerd model voor de verticale waterbeweging in de onverzadigde zone, gekoppeld aan onder meer verdamping, gewasontwikkeling, wortelwateropname en interactie met grondwater en oppervlaktewater.

Die lange geschiedenis is tegelijk een kracht en een praktische uitdaging. De wetenschappelijke modelinhoud is gedurende vele jaren uitgebreid en toegepast, terwijl de softwareomgeving waarin hydrologische modellen functioneren sterk is veranderd. Een model wordt tegenwoordig niet alleen beoordeeld op de vraag of een zelfstandige berekening kan worden uitgevoerd. Voor toepassingen in grotere modelketens zijn ook reproduceerbaarheid, geautomatiseerd testen, uitwisseling van toestand en fluxen, herstartbaarheid en koppeling met andere rekenkernen van belang.

Daarmee verandert de vraag die aan de software wordt gesteld. Het gaat niet simpelweg om het herschrijven van oude code in een modernere vorm. De hydrologische betekenis van de berekening moet herkenbaar en controleerbaar blijven terwijl onderdelen van de software anders worden georganiseerd. Dat vraagt om een scheiding tussen de wetenschappelijke rekeninhoud enerzijds en zaken als gegevensinvoer, uitvoer, tijdsturing en koppeling anderzijds.

Die ontwikkeling staat niet los van de Nederlandse praktijk. MetaSWAP is juist ontstaan om onverzadigde-zoneprocessen efficiënt in regionale grondwatermodellen te kunnen meenemen. In de publieke NHI-communicatie wordt inmiddels MultiSWAP genoemd als opvolger van MetaSWAP. Het NHI beschreef eerder al dat WENR en Deltares werken aan een nieuwe onverzadigde-zonemodule op basis van SWAP, met als doel een modelbasis te bieden die verschillende rekenroutes kan ondersteunen voor toepassingen met uiteenlopende eisen aan detail en rekentijd [5,6]. De precieze relatie tussen SWAP5, MultiSWAP en de uiteindelijke productie-inbedding moet in dit artikel daarom zorgvuldig worden benoemd. De namen zijn niet zonder meer synoniemen.

## 3. Wat SWAP5 op hoofdlijnen verandert

SWAP5 is in de eerste plaats een modernisering van de SWAP-modelbasis. Daarbij staat niet de introductie van één nieuw hydrologisch proces centraal. Het doel is de bestaande procesmatige modelinhoud zo te organiseren dat de rekenkern beter afzonderlijk kan worden getest, aangestuurd en gekoppeld.

Op hoofdlijnen betekent dit dat verschillende verantwoordelijkheden die in historische wetenschappelijke software gemakkelijk met elkaar verweven raken, explicieter uit elkaar worden gehaald. De hydrologische toestand van het systeem moet eenduidig beschikbaar zijn voor de berekening. Invoer en uitvoer mogen niet bepalen hoe de fysische rekenkern intern moet functioneren. Tijdsturing en modeluitvoering moeten controleerbaar zijn. En een externe modelcomponent moet via een duidelijk omschreven interface informatie kunnen uitwisselen zonder daarvoor de interne implementatie van SWAP te hoeven kennen.

Dat klinkt als een softwaretechnische exercitie, maar voor hydrologische toepassingen is het verschil inhoudelijk relevant. Wanneer een berekening onderdeel wordt van een gekoppeld systeem, moet duidelijk zijn welke grootheden aan de grens tussen twee modelcomponenten worden uitgewisseld, op welk moment dat gebeurt en welke modeltoestand bij die uitwisseling hoort. Ook moet achteraf kunnen worden vastgesteld met welke softwareversie, modelconfiguratie en invoer een resultaat is verkregen.

SWAP5 wordt daarom stapsgewijs opgebouwd en gekwalificeerd. Daarbij wordt gebruikgemaakt van bestaande modeldocumentatie, referentieberekeningen, geautomatiseerde tests en controles op onder meer waterbalansen en reproduceerbaarheid. Het feit dat functionaliteit technisch is geïmplementeerd, betekent in deze werkwijze niet automatisch dat zij al als gekwalificeerde productiefunctionaliteit wordt beschouwd. Dat onderscheid is belangrijk bij een model waarvan de bestaande toepassing en wetenschappelijke documentatie tientallen jaren beslaan.

De details van deze moderniseringsmethodiek vallen buiten dit overzichtsartikel. Voor de gebruiker is vooral van belang dat de nieuwe opzet de procesmatige SWAP-rekenbasis losser maakt van één specifieke uitvoeringsvorm. Daardoor kan dezelfde modelbasis zowel in zelfstandige berekeningen als, na afzonderlijke kwalificatie, als component in een gekoppelde modelomgeving worden gebruikt.

## 4. Van zelfstandig model naar gekoppelde component

De koppeling tussen onverzadigde zone en grondwater is hydrologisch vanzelfsprekend, maar numeriek en softwarematig niet triviaal. Een grondwaterstand beïnvloedt de vochttoestand en fluxen in het bodemprofiel. Omgekeerd beïnvloeden infiltratie, verdamping, drainage en verticale bodemwaterstroming de hoeveelheid water die het grondwatersysteem bereikt of verlaat. In een gekoppelde berekening moeten twee afzonderlijke modelcomponenten deze informatie gedurende de simulatie op een beheerste manier uitwisselen.

De modernisering van SWAP maakt het mogelijk deze uitwisseling explicieter te organiseren. Conceptueel kan een grondwatercomponent informatie over de onderrand van de onverzadigde zone leveren, waarna SWAP de reactie van bodem en vegetatie berekent en relevante fluxinformatie teruggeeft. Welke variabelen daarbij precies leidend zijn, hoe een koppelingsinterval wordt afgehandeld en welke numerieke strategie het meest geschikt is, zijn onderwerpen die afzonderlijke wetenschappelijke kwalificatie vereisen. Dit artikel loopt niet op die resultaten vooruit.

Hetzelfde onderscheid geldt voor de schaal waarop wordt gerekend. Een verticale bodemkolom, een grondwatercel en een oppervlaktewaternetwerk hoeven niet dezelfde ruimtelijke representatie te hebben. Dat een softwarekoppeling technisch meerdere landoppervlakte-eenheden aan een grondwaterrepresentatie kan verbinden, bewijst nog niet dat zo'n aggregatie onder alle hydrologische omstandigheden verantwoord is. De koppeling zelf en de fysische representativiteit van de gekozen schaal zijn verschillende vragen.

Dit onderscheid is belangrijk voor NHI-achtige toepassingen. Een modulair instrumentarium maakt het gemakkelijker om componenten afzonderlijk te ontwikkelen en te testen, maar verplaatst een deel van de wetenschappelijke aandacht naar de interfaces tussen die componenten. Niet alleen de afzonderlijke waterbalansen tellen, ook de betekenis en consistentie van de uitgewisselde toestanden en fluxen moeten duidelijk zijn.

## 5. MODFLOW 6, Ribasim en de onverzadigde zone

De ontwikkeling rond SWAP5 vindt plaats in een bredere vernieuwing van hydrologische modelsoftware. Binnen het NHI wordt MODFLOW 6 steeds nadrukkelijker gebruikt als grondwaterrekenkern. iMOD Python ondersteunt de opbouw van MODFLOW 6-modellen en de iMOD Coupler is bedoeld om MODFLOW 6 met andere modelcomponenten te verbinden [1,2]. Tijdens de Hydrology Software Days in 2025 werd bijvoorbeeld expliciet aandacht besteed aan de koppeling van Ribasim, MetaSWAP en MODFLOW 6 en aan de ontwikkeling van een onverzadigde-zonemodule [7].

Ribasim vult een ander deel van het systeem in. Het model berekent de waterbalans en waterverdeling binnen een netwerk van oppervlaktewatereenheden en kan worden gecombineerd met grondwaterberekeningen [3]. De stabiele release van eind 2025 wordt binnen het NHI gezien als basis voor verdere vervanging van oudere landelijke oppervlaktewatermodules, al is de landelijke schematisatie nog in ontwikkeling [1].

Voor de onverzadigde zone is de situatie op dit moment minder eenvoudig in één productnaam te vatten. MetaSWAP blijft relevant in bestaande gekoppelde toepassingen en vormt onderdeel van de huidige iMOD Coupler-koppeling. Tegelijk communiceert het NHI sinds 2025 over een nieuwe module op basis van SWAP en wordt MultiSWAP in 2026 publiek aangeduid als opvolger van MetaSWAP [5,6]. SWAP5 ontwikkelt ondertussen de gemoderniseerde SWAP-modelbasis en de technische en wetenschappelijke voorwaarden voor gebruik in moderne gekoppelde omgevingen.

Voor dit overzicht is daarom vooral de richting van belang, niet het voortijdig vastleggen van een definitieve productarchitectuur. Het Nederlandse instrumentarium beweegt naar een situatie waarin grondwater, onverzadigde zone en oppervlaktewater als duidelijker afgebakende modelcomponenten kunnen samenwerken. Welke concrete configuraties uiteindelijk voor regionale en landelijke toepassingen worden gebruikt, hangt niet alleen af van beschikbare software, maar ook van kwalificatie, rekentijd, schaalkeuze, beheer en de eisen van de toepassing.

Daarmee verschuift ook de betekenis van modelontwikkeling. De vraag is niet meer uitsluitend of ieder afzonderlijk model de juiste processen beschrijft. Even belangrijk wordt of de combinatie van componenten een reproduceerbare en hydrologisch interpreteerbare beschrijving van het gehele systeem oplevert. Juist daar ligt de komende jaren een belangrijk deel van het ontwikkel- en onderzoekswerk.

## Bronnen voor deze werkversie

[1] NHI, Nieuwe releases voor modelsoftware, 10 juni 2026. https://nhi.nu/nieuwsoverzicht/nieuwe-releases-voor-modelsoftware/

[2] NHI, iMOD5 en iMOD Suite. https://nhi.nu/tooling/imod-5-en-imod-suite/

[3] NHI, Ribasim. https://nhi.nu/modelcode/ribasim/

[4] Heinen, M., Mulder, M., Hack-ten Broeke, M., Bartholomeus, R. en Van Dam, J. (2025). SWAP 50 jaar. Stromingen 2025, editie 1. https://nhv.nu/kennis/stromingen/swap-50-jaar/

[5] NHI, Nieuwe module voor onverzadigde zone, 18 juni 2025. https://nhi.nu/nieuwsoverzicht/nieuwe-module-voor-onverzadigde-zone/

[6] NHI, NHI-webinar #4, MultiSWAP: opvolger van MetaSWAP, 18 maart 2026, vermeld in het NHI-nieuwsoverzicht. https://nhi.nu/nieuwsoverzicht/

[7] Deltares, Hydrology Software Days 2025, MODFLOW 6 and iMOD User Day. https://softwaredays.deltares.nl/-/hydrology-software-days-day-4d-2025

## Redactionele notities voor vervolg

1. Voor indiening moet de nomenclatuur SWAP5, MultiSWAP en MetaSWAP formeel worden gereconcilieerd met de actuele projectauthority.
2. Sectie 3 mag niet worden uitgebreid met P1-resultaten over transactionele migratie of preservation evidence.
3. Sectie 4 mag niet worden uitgebreid met PUB-GC-resultaten over q_bot, q_u, response identity, whole-window exchange, convergentie of E1-E7.
4. Sectie 5 mag geen definitieve NHI-productarchitectuur claimen zolang die niet formeel is vastgesteld.
5. De volgende versie kan secties 6 tot en met 10 toevoegen: schaalvraag, qualification op hoofdlijnen, rekentechnische haalbaarheid, betekenis voor gebruikers en actuele ontwikkelstatus.