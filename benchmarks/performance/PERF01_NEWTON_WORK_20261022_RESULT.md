# Mislukte Newton-pogingen: meetbaar minder werk

22 oktober2026. Afgerond, brongebonden numeriek onderzoek op de gerepareerde
canonical f4ef44cb. De productiecode en haar standaardinstellingen zijn niet
gewijzigd. De onderzoeksvariant is geen algemeen toegelaten solverbeleid.

## Uitkomst

Stop de huidige Newton-fase zodra alle acht dempingspogingen het kwadratische
residu niet hebben verminderd en de compartimentsbalans nog niet voldoet.
Gebruik daarna de bestaande corner-herstart of de bestaande terugkeer met
kleinere tijdstap. Elke daadwerkelijk geaccepteerde oplossing moet door alle
oorspronkelijke convergentie-, waterbalans- en temporele controles.

Drie afwisselend uitgevoerde, seriële paren per neerslagreeks, dezelfde O2-build,
97dagen, dezelfde1e-3cm vergelijkingsnauwkeurigheid, geen warme start:

| Neerslag | Oorspronkelijk, mediane CPU s | Onderzoeksvariant, mediane CPU s | Verschil |
| --- | ---: | ---: | ---: |
| 1x,227mm | 2.544512 | 2.125908 | -16.5% |
| 4x,908mm | 8.601036 | 5.338343 | -37.9% |

Dit zijn totale gebruikers-CPU-tijden van het native proces op deze host,
inclusief de bestaande waarnemingsuitvoer. Dagelijkse Newton-tellers worden
buiten de gemeten interne hydrologieklok geschreven. Tijdens de paren liep
geen eigen compilatie. Er is hostvariatie; de ruwe zes samples per neerslag
blijven bewaard. Eerdere losse screeningtijden waren geen definitieve benchmark.
Deze vergelijking maakt geen algemene of regionale snelheidsbelofte.

## Waardoor de winst ontstaat

Bij4x daalt het aantal Jacobiaanopbouwen van673078 naar537794 (-20.1%) en
het aantal dempingspogingen van1773872 naar792638 (-55.3%). Het aantal
solverafwijzingen stijgt van12371 naar13179; zij zijn aanzienlijk goedkoper.
HeadCalc-aanroepen stijgen licht van138057 naar138848 en geaccepteerde stappen
van18135 naar18160. De winst komt dus niet uit minder acceptatiecontrole.

Op dag84 daalt het aantal dempingspogingen van558785 naar140958. De mediane
interne dag-CPU daalt van1.344503 naar0.397648s, ongeveer70%. Het aantal
solverafwijzingen stijgt daar van4823 naar5190. Op1x blijven alle geaccepteerde
fysieke dagwaarden, HeadCalc-aanroepen en temporele afwijzingen exact;
de tussentijdse Newton- en dempingsaantallen nemen af.

Dit ondersteunt de eerdere diagnose: veel kosten zitten in het lang voortzetten
van een vastgelopen Newton-fase. Het bewijst geen voordeel van het afschaffen
van de flux/headwissel zelf. De algemene maaiveldformulering blijft apart werk.
Ook de keuze van voorstellen voor volgende tijdstappen is niet gewijzigd.

## Fysieke verschillen en controles

Bij4x is de grootste dagelijkse bergingsafwijking0.000068285mm; de totale
runoff neemt0.000124473mm toe en de totale onderrandafvoer evenveel af.
De eindberging is exact. De grootste drukhoogteafwijking is0.000691065cm en
de grootste volumetrische vochtverschil6.60217e-7. Gewasbiomassa, LAI en
transpiratie blijven exact in deze fixture met voorgeschreven onttrekking.
De maximale onafhankelijk gereconstrueerde dagelijkse waterbalansafwijking
is2.004e-13mm. Bij1x blijven alle vergeleken fysieke waarden exact.

Beide97-daagse neerslagreeksen zijn ook uitgevoerd met O0, boundschecks en
FPE-traps: alle fysieke dagwaarden en bestaande werktellers zijn exact met O2.
Reconstructie na natte dag35 heeft exact dezelfde gehele fysieke stdout als de
doorgaande variant. Gedwongen afwijzing na een private stap behoudt alle21
vastgelegde64-bitwaarden
van water/warmte/geschiedenis/klok/herkomst, de gewasrevisie en afwezige receipts.
De ongewijzigde directe retry-, desaturatiecorner-, bovenrandafgeleide- en
warme-start/fallbackasserties slagen voor beide optimalisatieniveaus.

Twee andere gecontroleerde armen, maximaal12 en8 Newton-iteraties via de
bestaande invoer, voltooien eveneens alle dagen en slagen voor dezelfde fysieke
screening. Cap8 heeft bij4x een bergingsspreiding0.000183mm en runoffverschil
0.000317mm. Alleen vroeg afbreken van de mislukte dempingszoektocht gaf in de
eerste screening bij beide neerslagreeksen een lagere CPU; daarom is die arm
voorafgaand aan de seriële herhalingen geselecteerd. De andere armen zijn
geen mislukte berekeningen en blijven als alternatieven in de bewijsset staan.

## Reproduceerbaarheid en grens

Plan, recovery, scripts, werkmetingen, gegenereerde drivers en bronidentiteiten
staan naast dit rapport. Het bewijsarchief bevat alle ruwe screening-,
herhalings-, O0-, herstart-, rollback- en directe contractuitvoer. De verifier
gebruikt de oorspronkelijke onafhankelijke balansreconstructie en verwerpt
ontbrekend bewijs of gewijzigde productiebestanden. Alle256 objecten en hun
modulebestanden zijn vóór hergebruik op identiteit gecontroleerd; de volledige
compilatie is gedeeld, elke nieuwe native arm is daadwerkelijk uitgevoerd.

Replay: `python -B benchmarks/performance/verify_perf01_newton_work.py --self-test`.
De index en samenvatting pinnen bytes, inventaris, SHA256 en gemeten kosten.
De oorspronkelijke productiebron is ongewijzigd; daarom is geen brede F-CI,
hoogste low-air of RossFast-uitbreiding uitgevoerd. Er zijn geen nieuwe1e-6
berekeningen geselecteerd.

De variant mag niet stilzwijgend de algemene solver vervangen: een niet-monotone
Newton-reeks kan soms alsnog convergeren. De geteste kleinere-staproute vangt
dat hier op; een universele garantie volgt daar niet uit. Een productievoorstel
moet de precieze toepassingsgrens en expliciete numerieke selectie vastleggen,
de oorspronkelijke failure/corner/rollbackcontracten houden en de werkelijk
geraakte source/native owners kwalificeren. Dit rapport sluit de gecontroleerde
onderzoeksronde af; productiepromotie is een volgende implementatieronde.
