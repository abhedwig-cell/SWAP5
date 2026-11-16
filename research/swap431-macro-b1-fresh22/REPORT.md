# FRESH22 — afbakening van de actieve minimumvoorraadkoppeling

**Een actuele macro-evaluatie is een noodzakelijke stap, maar lost de oorspronkelijke node-52-afwijzing op zichzelf niet op.** De ene geselecteerde kandidaat faalt met O0/O2 nog steeds binnen de oorspronkelijke 30 iteraties. Het contract is daarom afgebakend tot actuele residuen én een behandeling van de domeinbrede actieve beperking in de gekoppelde gevoeligheid. CONTRACT.md bevat de exacte scope, ketenregel en acceptatievoorwaarden. Er is geen nieuwe gekwalificeerde solver of fysische correctie.

## Exact één gerichte kandidaat

Baseline is LIMIT21 32daab024721a8b1f66b8417e771e809882beb0b. De native route start opnieuw vanaf hetzelfde oorspronkelijke eigen bestand op 35797. De eerste 36 geaccepteerde stappen en 37 headpogingen blijven exact gelijk aan LIMIT21, inclusief alle niet-timingkolommen en de oorspronkelijke beginexports.

Uitsluitend in headpoging 38 wordt vóór iedere Jacobiaan de groep macro-freezevlaggen teruggezet. Daardoor gebruiken alle line-searchvectoren actuele MACRORATE-fluxen en gebruikt iedere Jacobiaan de bestaande afgeleideroute bij het actuele profiel. De fysieke providers, minimumvoorraad, instroom-/uitstroombegrenzingen en herverdeling zijn bytegelijk aan LIMIT21. Ook V1, tolerantie, MAXIT, dt en reductiepolicy blijven behouden. Dit is een lokale wijziging van numeriek freezegedrag, geen ongewijzigde solverrun en geen exact-Jacobiaanimplementatie.

De oorspronkelijke geselecteerde context is poging 38, begin t1900=35797,070666666681 en dt=0,0013333333333333333 dag. De eerste node-52-vectorrecord binnen de poging is exact gelijk aan LIMIT21. Er is geen gewijzigd head geïnjecteerd, geen andere retry geselecteerd en geen aanloop opnieuw getuned.

Precies twee modelroutes, O0 en O2, stoppen na return van die ene headpoging, vóór de volgende hostretry of commit. De harde limiet blijft twintig seconden per route. Werkelijke procesduur is **1,164 s voor O0** en **0,714 s voor O2**, beide normaal en zonder censuur. De oorspronkelijke interne headcalc-herstelstap bij afwijzing wordt wel uitgevoerd; target_return bevat dus herstelde h/theta. solver_1.txt bewaart de laatste proefresiduen vóór dat interne herstel. Er is geen nieuwe geaccepteerde stap 37 of voortzetting tot periode-einde.

## O0/O2-resultaat

Alle niet-timingtraces en exports zijn exact gelijk tussen O0/O2. De provider- en operatorgegevens blijven onafhankelijk reconstrueerbaar; de native limiterformules zijn opnieuw nagerekend. Bij de kandidaat is geen macro-vector bevroren: 59 vectoraanroepen berekenen 59 keer de actuele macro-rates; 30 Jacobiaanaanroepen gebruiken 30 keer de bestaande macro-afgeleiden.

| Zelfde oorspronkelijke poging | LIMIT21 oorspronkelijke route | FRESH22 kandidaat, O0/O2 |
| --- | ---: | ---: |
| Uitgevoerde iteraties | 30 | 30 |
| Grootste absolute eindresidu | 0,0167522750183 | 0,000114304236263 |
| Somresidu | 0,184491590146 | −0,000448408847401 |
| Node met grootste eindresidu | 52 | 52 |
| Gebruikte fluxfactor | 1 | 1 |
| Uitkomst | Afwijzing | Afwijzing |

De kandidaatrestfout is kleiner, maar ligt nog ongeveer **114 maal boven CRITDEVBALCP=1e-6**. Het totale residu overschrijdt CRITDEVBALTOT=1e-5 eveneens. Er is dus geen acceptatie en geen versoepeling. De uiteindelijke compartimentbalansvlag faalt; de headveranderingsvlag is op dat moment niet de afwijzingsgrond.

De oorspronkelijke vijf-iteratiecyclus met voorlopige convergentie en verse residusprong komt in deze kandidaat niet voor. Geen poging bereikt voorlopige convergentie die de V1-certificering activeert; het aantal verse certificeringen is 0. Dit betekent niet dat V1 is verwijderd: de voorwaarden ervoor worden niet gehaald. De line search gebruikt 58 trials bij 30 Jacobiaanstappen, dus 28 extra trials boven de eerste per iteratie.

## Actieve grens en ontbrekende gevoeligheid

De extra limitertrace registreert 89 volledige macro-evaluaties, samen 267 records. De minimumvoorraadregel blijft exact zoals LIMIT21. In 74 evaluaties is de uitstroomfactor gedeeltelijk actief, in 15 is hij 1. Bij de laatste evaluatie is de factor **0,9096059901245779**. Het head op node 52 beweegt tussen circa 3,03051 en 3,06794 cm; de laatste iteraties blijven kleine wisselingen rond de gedeeltelijk beperkte tak vertonen. Er is in deze kandidaat geen volledig wegvallen van de node-52-flux bij een achteraf uitgevoerde refresh nodig om toch de criteria te missen.

De actuele rates worden dus meegenomen, maar de bestaande macro-afgeleide bevat niet expliciet de gevoeligheid van de voorraadgrens en domeinbrede factor. In de geselecteerde gedeeltelijke tak geldt analytisch:

`q_k = f*o_k/dt`, `f=1−E/O`, `E=L−W−I+O`.

Bij vaste geaccepteerde W moet een Newtonbehandeling daarom zowel veranderingen van de potentiële component o_k als van E/O omvatten. L is de minimumkeuze tussen volume onder actuele matrix-GWL en aanwezige voorraad. Het volume reageert via GWL op het headprofiel; de factor wordt bovendien gedeeld door de totale domeinuitstroom. Dit koppelt meerdere componenten en nodes.

Broninspectie ondersteunt dit verschil: SATFLOW(4) gebruikt actuele uit-/instroom gedeeld door het opgeslagen headverschil. headcalc verwerkt de macro-afgeleide uitsluitend in dFdhM. Er is geen expliciete differentiatie van de minimumkeuze, matrix-GWL-keten of limiterfactor. De betreffende oorspronkelijke GWL-bron is met hash als calcgwl_reference.txt vastgelegd. Deze bronanalyse identificeert ontbrekende termen voor een volledige Newtonlinearisatie; de huidige proef kwantificeert nog niet iedere Jacobiaancomponent en bewijst niet dat toevoegen ervan voldoende is voor convergentie.

## Afgebakende uitkomst

De consistentiebehandeling moet minimaal één actuele constrained operator voor residu en line search behouden, de actieve tak volgens de oorspronkelijke predicaten herbeoordelen en bij een Newtonaanpak haar domeinbrede/GWL-afhankelijkheid in de gevoeligheid meenemen. De oude minimumvoorraad bevriezen, de grens gladstrijken, een nulvoorraad veronderstellen of V1 overslaan valt buiten dit contract. Een lokale correctie aan alleen de node-52-diagonaal krijgt evenmin zonder afhankelijkheidsonderbouwing toelating.

De gelokaliseerde current-operator-kandidaat is **niet geschikt verklaard als oplossing** en krijgt geen productie- of referentiepromotie. De fysieke minimumvoorraadregel is niet als fout aangetoond. De kleinste mogelijke volgende stap is een afzonderlijk afgebakende gevoeligheidscontrole bij dezelfde gedeeltelijk actieve tak met gecontroleerd herstel van providerwerkstaat. Er is nog geen algemene solververvanging, numerieke volle Jacobiaan, extra variant, factor-0,01-route of volledige tweede BAL-periode uitgevoerd.

assess_fresh22.py controleert alleen bestaande bestanden. RESULT.json, CONTRACT.md, de lokale kandidaat-/driverpatch, bronidentiteiten, native bouwclosure en FRESH22_EVIDENCE.zip bewaren de afbakening en het negatieve kwalificatieresultaat.
