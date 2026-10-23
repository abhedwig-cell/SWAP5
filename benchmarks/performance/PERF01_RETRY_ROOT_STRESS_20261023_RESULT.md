# Rekentijd en actieve wortelstress bij ruimere tijdnauwkeurigheid

23 oktober2026. Afgerond begrensd invoeronderzoek op canonical
`ead21ff0a325f4d5a96be889c1fec083e7c8ba4d`, broncontext
`bda16ceab3a21eb7cd2a4c340348aea2d5a41929`. De256 werkelijk gebruikte providers,
geordende closure, gegenereerde waarnemers en O0/O2-executables zijn exact aan
de bestaande gemeten builds. Daarom is geen nieuwe compilatie uitgevoerd.
Productiecode, fysieke criteria en defaults zijn ongewijzigd.

De bestaande97-daagse30cm/viercellenproef gebruikt nu haar reeds beschikbare
`sensitive`-profiel: hlim3l=-100,hlim3h=-150,hlim4=-500cm. Dit verandert expliciete
wortelstressparameters; er is geen nieuw stressmodel geïmplementeerd. De bestaande
weer/gewasinterface levert werkelijke wateropname terug aan de dagelijkse
gewasontwikkeling. De retry-optie staat aan, warme start uit. De gevarieerde
waarde is het bestaande lokale model-certificate-drukhoogtebudget.

## Gemeten uitkomst

Drie seriële O2-herhalingen per budget en neerslag, met omgekeerde volgorde in
herhaling twee. Geen eigen compilatie tijdens timing. Mediane native
gebruikers-CPU, inclusief bestaande waarnemingsuitvoer:

| Budget cm | 1x CPU s | 4x CPU s |
| --- | ---: | ---: |
| 0.001 | 1.596745 | 3.902015 |
| 0.003 | 1.086204 | 2.467214 |
| 0.01 | 0.936877 | 1.866368 |

Van1e-3 naar1e-2 is dit41.3% minder CPU bij1x en52.2% bij4x. Dit is een
vergelijking van nauwkeurigheidsinstellingen binnen deze meetronde, geen
implementatieversnelling bij gelijke nauwkeurigheid of algemene snelheidsbelofte.

Bij1e-3 zijn38 stressdagen actief bij1x en5 bij4x; alle budgetten behouden
die aantallen. Het totale tekort ten opzichte van potentiële transpiratie is
respectievelijk2.81451 en0.15542mm. De proef is dus geen herhaling met inactieve
stress. De4x-stress is beperkt en bewijst geen algemene natte-wortelstressgrens.

## Verschillen bij1e-2 ten opzichte van1e-3

| Grootheid | 1x | 4x |
| --- | ---: | ---: |
| Totale transpiratie bij1e-3 mm | 82.129479 | 84.799961 |
| Verschil totale transpiratie mm | +0.00049430 | +0.00017509 |
| Grootste dagelijkse transpiratieafwijking mm | 0.00009889 | 0.00007402 |
| Grootste dagelijkse bergingsafwijking mm | 0.00821039 | 0.01608242 |
| Verschil eindberging mm | -0.00011925 | +0.00662180 |
| Verschil totale runoff mm | 0 | +0.00113669 |
| Verschil totale onderrandafvoer mm | -0.00036547 | -0.00793355 |
| Verschil eindbiomassa procent | +0.0005151% | +0.0001472% |
| Grootste LAI-afwijking | 0.00020307 | 0.00013707 |
| Grootste drukhoogteafwijking cm | 0.06894123 | 0.04914375 |

Deze kleine verschillen ondersteunen1e-2 als expliciete instelling in deze
proefkolom. Het zijn verschillen tussen twee instellingen, geen onafhankelijke
foutgrenzen of veldvalidatie. Een universele default of nieuw bodem-/grondwater- /
worteldomein volgt hier niet uit. De structurele maaiveldformulering blijft
afzonderlijk open. Er zijn geen nieuwe1e-6-, hoogste-low-air- of uitgebreide
RossFast-runs uitgevoerd.

## Controles en reproduceerbaarheid

Alle24 native processen voltooien97 dagen; samen59.52s wandtijd. De bestaande
onafhankelijke dagelijkse massareconstructie blijft ongewijzigd. De grootste
sluitfout is2.79e-13mm. Herhalingen geven exact dezelfde fysieke dagwaarden en
werktellers. Checked O0/O2 zijn exact op1e-3 en1e-2 onder beide neerslagreeksen.
De bestaande close/reconstruct na dag48 geeft bij1e-2 exact dezelfde gehele
fysieke reeks en werktellers als continu doorrekenen.

De onderzoeksrunner en -verifier ondersteunen nu expliciet het bestaande
`sensitive`-profiel. De originele profielasserties blijven intact en het gehele
eerder geïntegreerde PR1379-archief slaagt opnieuw met de uitgebreide verifier.
Bij het stressprofiel wordt geen vergelijking met de andere wortelparameters
als behoudsassertie gebruikt: de native commandoregel moet werkelijk `sensitive`
selecteren en de werkelijke opname moet een positief stresssignaal geven.

Het nieuwe archief bevat alle ruwe processen, exacte input- en bouwmetadata,
gegenereerde waarnemers, recepten en volledige SHA256-inventaris. Zes negatieve
controles verwerpen ontbrekende uitvoer, gewijzigde fysieke bytes, gewijzigde
waarnemer, ontbrekende procesregistratie, gewijzigde mediaan en verkeerd profiel.
Replay controleert alle256 bronhashes en de huidige geordende closure; ongewijzigde
afhankelijkheden worden hergebruikt zonder actuele bronwijzigingen als destijds
gecompileerd voor te stellen.

Replay: `python -B benchmarks/performance/verify_perf01_retry_tolerance.py
benchmarks/performance/PERF01_RETRY_ROOT_STRESS_20261023_EVIDENCE.tar.xz`.
De versiegebonden status onderscheidt onderzoeksintegratie van productiebeleid.
