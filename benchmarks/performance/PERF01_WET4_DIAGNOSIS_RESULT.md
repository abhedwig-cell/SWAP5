# Waarom de viermaal natte run stopt

De run loopt op 23 februari 1999 vast bij de overgang naar verzadiging. Er zijn
twee aantoonbare eindmechanismen. Een ruimere nauwkeurigheidstolerantie verplaatst
de blokkade, maar maakt de oorspronkelijke viermaal natte berekening niet af.
Dit onderzoek wijzigt geen productiecode, waterbalansgrens of fysieke toestand.

| Hoofdbudget | Laatste interne tijd op dag 35 | Uiteindelijke afwijzing |
| --- | ---: | --- |
| 1e-6 cm | 74,13 seconden | Tijdnauwkeurigheid, na 33 pogingen |
| 1e-3 cm | 72,96 seconden | Tijdnauwkeurigheid, na 33 pogingen |
| 1 cm | 358,93 seconden | Geen convergentie bodemvergelijkingen, alle 33 pogingen |

Deze interne tijden zijn geen extern opgeslagen voortgang: de hele aangevraagde
eerste periode van 22,5 minuten wordt afgewezen. De opgeslagen bodemtoestand voor
en na de afwijzing is exact gelijk, gecontroleerd bij 1e-3 en 1 cm. Beide hebben
34 volledige dagen; geen van beide levert een complete waterbalans voor dag 35.

## Wat precies misgaat

Bij 1e-3 cm is de bovenste cel verzadigd. Zelfs een laatste proefstap van
3,44e-12 dag, ongeveer 0,30 microseconde, krijgt een genormaliseerde
tijdfoutindicator van 1,149 waar maximaal 1 is toegestaan. De bodemoplosser meldt
op die laatste proef wel convergentie. Het massaresidu is -2,17e-15 cm en voldoet
aan de ongewijzigde grens van 1e-14 cm. De waterbalanscontrole is dus niet de
uiteindelijke reden van stoppen. Bij 1e-6 cm is het eindmechanisme hetzelfde.

De gebruikte certificaatroute beoordeelt drukhoogteverandering uit opeenvolgende
stappen. Bij verzadiging verandert het numerieke karakter: het watergehalte kan
nauwelijks toenemen, terwijl de drukhoogte wel kan veranderen. De bestaande
MvG-provider gebruikt hier een kleine hulpcapaciteit `dt * 1e-7`; de foutschatter
gebruikt capaciteit maal celdikte en deelt door de wortel van het kleinste
gewicht. Het gladde, onverzadigde gedrag waarop de eerdere vergelijking steunde
kan hier niet zonder meer worden doorgetrokken. De trace toont bij 1e-3 cm een
drukhoogtesprong van ongeveer 0,10 cm bij vrijwel nul tijdsvoortgang. Dit is een
numerieke overgang, geen gemeten afwijking in runoff.

Bij 1 cm passeert de berekening de eerste blokkade. Later zijn de bovenste drie
cellen verzadigd en is de onderste bijna verzadigd. HeadCalc vraagt dan bij alle
33 pogingen een kleinere stap. Het laatste residu van de totale
bodemvergelijkingen bedraagt 0,0614 cm/dag tegenover de op dat moment geldende
numerieke grens van 0,0001048 cm/dag. Dit is een solverresidu in cm/dag, geen
opgeslagen waterverlies. De afgewezen kandidaat wordt teruggedraaid.

## Gerichte tegenproeven

Alleen de regen op die ene dag is veranderd, met alle voorafgaande viermaal
natte dagen, gewasinstellingen en numerieke controles gelijk:

| Regen op dag 35 | Budget | Uitkomst tot en met dag 35 |
| --- | --- | --- |
| 48,4 mm, oorspronkelijk | 1e-6, 1e-3 en 1 cm | Stopt |
| 47,5 mm | 1e-3 en 1 cm | Stopt |
| 47,0 mm | 1e-3 cm | Stopt |
| 40,0 mm | 1e-3 cm | Voltooit dag 35 |
| 0 mm | 1e-3 cm | Voltooit dag 35 |

Bij 40 mm blijft de bovenste dagelijkse einddrukhoogte negatief, -0,361 cm.
Het gerapporteerde dagresidu is -2,13e-12 mm. De eerste 34 dagen en alle eerder
geaccepteerde fluxen blijven exact gelijk. De vergelijking met Ksat, 47,5 mm/dag,
is dus op zichzelf geen verklaring en geen betrouwbare omschakelgrens.

Een afzonderlijke numerieke diagnose verhoogt alleen het aantal toegestane
herkansingen van 32 naar 48, zonder enige acceptatiegrens te verruimen. Ook die
run stopt. De laatste 49-pogingenreeks vraagt stappen van 4,10e-17 dag; door
afronding is het berekende eindtijdstip dan gelijk aan het begintijdstip. Meer
herkansingen is geen bruikbare oplossing. Dit is een private diagnosevariant,
geen voorstel voor een nieuwe standaardinstelling.

## Betekenis voor de tolerantiekeuze

De succesvolle tweemaal natte proef blijft bewijs voor haar eigen domein. De
viermaal natte proef levert geen geldige extra nauwkeurigheids-snelheidscurve.
Noch automatisch teruggaan naar 1e-6, noch verder verruimen tot 1 cm lost dit op.

De volgende ontwikkelstap is een samenhangende behandeling van verzadiging:
een geschikte tijdnauwkeurigheidscontrole en een werkelijk gekoppelde overgang
van opgelegde infiltratie naar oppervlakteberging/afstroming. De huidige
weer/gewaskoppeling legt de bovenflux vast voor de hele externe periode en
accepteert uitsluitend de fluxroute zonder ponding of runoff. Het bestaande
pondpad kan niet rechtstreeks met dit geschiedenis-certificaat worden
gecombineerd. Dit onderzoek kwalificeert geen vervangende koppeling, berekent
geen hypothetische runoffhoeveelheid en bewijst niet dat iedere solverafwijzing
uitsluitend door ontbrekende runoff wordt veroorzaakt.

## Bewijs en begrenzing

Drie O2-traces reproduceren de oorspronkelijke fysieke/werkprefix en fluxen
exact. Voor 1e-3 en 1 cm is ook de volledige diagnostische stdout bytegelijk in
O0 met runtimecontroles en O2. Een extra uitvoering van het definitieve recept
reproduceert de 1e-3-trace eveneens exact. De controlegevallen zijn tot dag 35
berekend, niet als nieuwe 97-dagenkwalificatie. De geometrie blijft de bestaande
viercellige kolom van 30 cm met illustratieve gewasparameters.

Baseline is `95a3bd5721a4dfb4c0c38823c475ff55b95bee57`. De 256 daadwerkelijk
gebruikte providerinvoerbestanden zijn tegen de vorige weather-buildmanifesten
gecontroleerd, inclusief de oorspronkelijke bronidentiteiten van de twee
bestaande print-overlays. Alle productie-, test- en integratiebestanden blijven
exact gelijk aan deze baseline. De uitgebreide bronboom bevat inmiddels ook de
onafhankelijke PR1358-uitvoercomponent; die is geen onderdeel van deze diagnose.

De bestaande standalone pond-policy-verificatiewrapper heeft op deze baseline
een `KeyError: qualified`: de PR1358-successor retourneert een statusnaam in
plaats van die oude sleutel. De wrapper is niet gewijzigd en krijgt hier geen
PASS-label. De onderliggende bron-/bewijscontroles en de actuele successor-owner
slagen afzonderlijk; de volledige resultaten en deze beperking zijn bewaard.
Er zijn geen brede F-CI-, low-air- of RossFast-runs geselecteerd.

Reproductie met een bestaande, exacte weather-build en een GNU13-compiler:

```bash
python benchmarks/performance/diagnose_perf01_wet4.py --base /tmp/weather-build --output /tmp/wet4-trace --compiler /path/to/gfortran
python benchmarks/performance/run_perf01_weather.py --build /tmp/wet4-trace --output /tmp/wet4-run --budget .001 --days 35
# Diagnosevarianten: voeg --max-retries 48 of --rain-on-feb23 40 toe aan de build.
python benchmarks/performance/assess_perf01_wet4_diagnosis.py /tmp/extracted-evidence
```

`PERF01_WET4_DIAGNOSIS_STATUS.json` bindt de recepten, samenvatting en het
evidence-archief. Het archief bewaart ruwe uitvoer, mislukte proeven, compilerlogs,
gegenereerde observerbronnen, weersinvoer en controlesommen. Het bevat geen
native objectbestanden of executables.
