# Ruimere tijdnauwkeurigheid na de wet4-reparatie

23 oktober 2026. Afgerond begrensd invoeronderzoek op canonical
`53010691c79d3e132914ce372059cf873d88b96d`, productieboom
`8eda6373e2d3b5e083514d550d9ab43c0525126f`. Geen productiecode of default gewijzigd.

De bestaande 97-daagse kolom is doorgerekend met 1x/4x neerslag, de toegelaten
expliciete `weather_line_search_retry` aan en warme start uit. De gevarieerde
waarde is het lokale model-certificate-drukhoogtebudget in cm. De bestaande
Newton-, compartiments-, totale massabalans- en transactiecriteria blijven gelijk.
De budgetwaarde is geen bovengrens voor de globale drukhoogtefout.

## Gemeten resultaat

Drie seriële herhalingen per punt, met omgekeerde volgorde in herhaling twee.
Er liep tijdens deze meting geen eigen compilatie. De tabel geeft de mediane
gebruikers-CPU van het native proces, inclusief bestaande waarnemingsuitvoer,
exclusief compilatie en analyse. Vergelijk alleen binnen deze meetronde;
absolute tijden verschillen van de eerdere PR1378-metingen door hostvariatie.

| Budget cm | 1x CPU s | 1x HeadCalc | 4x CPU s | 4x HeadCalc |
| --- | ---: | ---: | ---: | ---: |
| 0.001 | 1.630873 | 58,321 | 3.817932 | 138,848 |
| 0.003 | 1.122513 | 31,926 | 2.541748 | 78,584 |
| 0.01 | 0.919747 | 22,354 | 1.993889 | 51,171 |

Van 1e-3 naar 1e-2 daalt CPU met43.6% bij1x en47.8% bij4x. Bij4x dalen
de temporele afwijzingen van22,753 naar2,507, geaccepteerde interne stappen
van18,160 naar10,143 en Jacobiaanopbouwen van537,794 naar223,086.
Dit is winst door andere gekozen tijdnauwkeurigheid; de eerdere35% winst
door goedkoper mislukte Newtonpogingen is bij beide armen al ingeschakeld.
De percentages uit verschillende meetronden mogen niet rechtstreeks worden
opgeteld of met de oude absolute CPU-tijden vermenigvuldigd.

## Waterverdeling en gecontroleerde grens

Verschillen bij1e-2 ten opzichte van1e-3, niet ten opzichte van veldwaarheid
of een onafhankelijk geconvergeerde oplossing:

| Grootheid | 1x | 4x |
| --- | ---: | ---: |
| Grootste dagelijkse bergingsafwijking mm | 0.00825947 | 0.01608242 |
| Verschil eindberging mm | +0.00001463 | +0.00654950 |
| Verschil totale runoff mm | 0 | +0.00102437 |
| Grootste cumulatieve runoffafwijking mm | 0 | 0.00153560 |
| Verschil totale onderrandafvoer mm | -0.00001463 | -0.00757387 |
| Grootste dagelijkse onderrandafwijking mm | 0.00979791 | 0.02053566 |
| Grootste drukhoogteafwijking cm | 0.07550497 | 0.04914375 |

Transpiratie, biomassa en LAI zijn exact in deze fixture met voorgeschreven
onttrekking. Alle24 geselecteerde native processen voltooien97 dagen. De
oorspronkelijke onafhankelijke dagelijkse massareconstructie blijft ongewijzigd;
de maximale sluitfout over alle punten is2.79e-13mm. Dit staat los van de
kleine verschuivingen in de waterverdeling tussen instellingen.

Herhalingen geven exact dezelfde fysieke waarden en werktellers. Checked O0
en O2 zijn op1e-3 en1e-2 bij beide neerslagreeksen exact. De bestaande
close/reconstruct op dag48 geeft bij1e-2 voor beide reeksen exact dezelfde
fysieke waarden en werktellers als continu doorrekenen. De1e-3-arm is exact
aan de eerder toegelaten ON-dagwaarden/werktellers uit het PR1378-bewijs.

Voor deze kolom is1e-2 een bruikbare expliciete proefinstelling. Dit onderzoek
selecteert geen universele default en kwalificeert geen nieuwe bodem,
grondwaterrandvoorwaarde, dynamische wortelrespons of maaiveldformulering.
De algemene vraag over de flux/drukhoogtewisseling blijft afzonderlijk open.
Er zijn geen nieuwe1e-6-, hoogste-low-air- of uitgebreide RossFast-runs uitgevoerd.

## Reproduceerbaarheid

`study_perf01_retry_tolerance.py` voert de oorspronkelijke forcing en native
interface uit. `build_perf01_weather_surface.py --observe` levert de bestaande
waarnemer voor geaccepteerde fluxen; `select_perf01_line_search_retry.py
--observe-work` selecteert expliciet de toegelaten optie. Beide256-provider
closures zijn vers opgebouwd; bij herstel van de waarnemer zijn alleen de twee
observatieproviders opnieuw gecompileerd en de overige254 objecten op volledige
bronidentiteit hergebruikt. De gegenereerde waarnemers zijn bytegelijk aan het
toegelaten bewijs. Alle bron-, compiler-, object- en koppelidentiteiten blijven
in de bouwmetadata bewaard. De24 proceswaarnemingen kostten samen61.22s
wandtijd; de volledige vastgelegde compilatie/koppeling is afzonderlijk gemeten.

De eerste proef gebruikte per abuis de oudere waarnemer van aangeboden
oppervlaktefluxen. Het native proces voltooide, maar de onafhankelijke
massareconstructie verwierp de meting. Die ruwe uitvoer, diagnostiek en
oorspronkelijke bouwmetadata blijven apart bewaard; de mislukte meetopbouw
geldt niet als geslaagde balanscontrole. Er is geen assertie versoepeld.

Het bewijsarchief bevat alle ruwe processen, mislukte meetopbouw, recepten,
metadata en een volledige SHA256-inventaris. De verifier herberekent de
massabalans, verschillen, medianen, werktellers, oorspronkelijke fysieke
identiteit en herstart/O0/O2-gelijkheid. Vijf controles verwerpen ontbrekende
native uitvoer, gewijzigde fysieke bytes, gewijzigde waarnemer, ontbrekende
procesregistratie en een gewijzigde mediaan.

Replay: `python -B benchmarks/performance/verify_perf01_retry_tolerance.py
benchmarks/performance/PERF01_RETRY_TOLERANCE_20261023_EVIDENCE.tar.xz`.
De versiegebonden status onderscheidt dit invoeronderzoek van productiebeleid.

De parallelle NUT-integratie op `db8f2c26e69f0466727aea105b99a76cd14e120f`
is gereconcilieerd. Haar gewijzigde/nieuwe bronnen liggen buiten de gemeten
weerclosure. De opnieuw bepaalde geordende lijst van256 providers en alle
werkelijke bronhashes blijven exact, inclusief de gekwalificeerde waarnemers.
De oorspronkelijke meetboom blijft afzonderlijk gepind; de huidige grotere
productieboom wordt niet als destijds gecompileerd voorgesteld. Ruwe replay
en de actuele toegelaten bron-owner slagen op de samengestelde kandidaat.
Daarom zijn ongewijzigde native proeven niet opnieuw uitgevoerd.
