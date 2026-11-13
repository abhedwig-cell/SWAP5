# SWAP431-MACRO-B1-STAGNATION05

**De stagnatie is gelokaliseerd: een oorspronkelijke scherpe omschakeling van onverzadigde macroporiënabsorptie rond `h45=-10 cm`, met daarbovenop V1's bevriezings-/eindcontrolecyclus. De bestaande V2 verwijdert de bevriezing, maar convergeert op deze toestand evenmin.** Eindstatus blijft `B1_CANDIDATE_NOT_READY` voor een ongereduceerde fysische referentie.

## Basis en begrenzing

Basis is de definitieve UNREDUCED04-commit `6003fd2383dd0c97bb40238936fc38cb1d601471`. Nieuwe branch: `research/swap431-macro-b1-stagnation05-20261113`. De gebruiker autoriseerde expliciet gerichte diagnose en zo nodig vergelijking met de bestaande V2, binnen dezelfde grenzen. `STATUS.json`, `V2_SELECTION.json` en `THRESHOLD_SELECTION.json` bewaren de opeenvolgende selecties vóór hun modelproeven.

De actuele remote had geen opvolger van UNREDUCED04. Canonical was `af65d5a267ec33024779122002cc84fc344ee7e4`; de delta sinds `980273f81` betreft macroporiënvrije oorspronkelijke geschiedenis-/reactiedekking. De oorspronkelijke macrobron, onderzoeksvarianten en opgeslagen native closure zijn ongewijzigd. Geen canonical wijziging is overgenomen of aangebracht.

Elke route gebruikt dezelfde oorspronkelijke V1-prefix en dezelfde opgeslagen begincontext: `t1900=35796.9513533331`, `dt=0.0001414213562373095 d`. Pas daar wordt ongereduceerde uitwisseling geselecteerd. De oorspronkelijke retryflag en daarmee zestig oorspronkelijke Newtoniteraties blijven behouden. Deze ronde herhaalt uitsluitend de **eerste** stapgrootte; niet opnieuw de vier dt-groottes of het volledige tweedaagse eindvenster.

Geen fysische wet, lokale/totale/pondgrens, dtmin, iteratielimiet of backtrackinglimiet is gewijzigd. Er is geen derde algemene solvervariant gemaakt. De extra drempelkopie voert slechts een oorspronkelijke operator-evaluatie uit en stopt vóór Newtoniteratie/acceptatie.

## Meting zonder verstoring

De V1-probe schrijft alleen al berekende gegevens: vóór/na de Jacobiaan, na elke backtrackkandidaat, na de iteratiecriteria en vóór/na V1's verse eindcontrole. Er wordt voor de iteratietrace geen extra fysische evaluatie aangeroepen. Eén uitvoerbestand per geselecteerde poging voorkomt de eerder kostbare per-poging open/close-tracering.

De vijf bestanden met begincontext, beginpoging, laatste solvervector, teruggekeerde toestand en rollback zijn voor V1 **bytegelijk aan UNREDUCED04**, bij O0 en O2. De diagnose verandert dus de onderzochte afwijzing niet. De globale lusindex in de initiële trace kan nog 61 van een eerdere prefixpoging bevatten; alleen de werkelijke iteraties 1–60 worden als iteraties geteld.

De bestaande V2 is de eerder geregistreerde bronvariant: alleen de oorspronkelijke bevriezingsoptimalisatie staat uit. Zij wordt als afzonderlijk benoemde routine pas in de geselecteerde context aangeroepen; haar prefix blijft V1. Alle gemeten beginvelden zijn exact gelijk en de eerste drie iteratieroutes zijn gelijk tot V1 de bevriezing inschakelt. Er is dus geen vergelijking tussen twee verschillende trajectgeschiedenissen.

## Bevinding 1: V1 blijft een zes-iteratiecyclus herhalen

V1 schakelt de bevriezing in en bereikt vervolgens op iteraties `7,13,19,25,31,37,43,49,55` voorlopige convergentie van het bevroren deelprobleem. De gecachete lokale residuen voldoen op die negen momenten aan `1e-6`, evenals de totale residuen aan `1e-5`. V1 doet daarna terecht de verse gekoppelde eindcontrole, bij exact dezelfde drukhoogten.

Die verse controle geeft telkens weer een lokaal residu van ongeveer `0.1284 cm/d`. Bijvoorbeeld iteratie 7:

| Grootheid | Bevroren voorlopige beoordeling | Verse gekoppelde beoordeling |
| --- | --- | --- |
| h45 | `-10.039819393461206 cm` | exact gelijk |
| Uitwisseling compartiment 45 | `0.04526139529513873 cm/d` | `0.1736682761306392 cm/d` |
| Grootste lokale residu | `7.95e-7 cm/d` ongeveer | `0.1284076765339081 cm/d` |

De eindcontrole verwerpt die voorlopige oplossing; daarna begint dezelfde combinatie van actief itereren, grensoverschrijden en opnieuw bevriezen. In totaal zijn er 120 backtrack-evaluaties, waarvan 19 met bevroren uitwisseling, en tien uitgeputte lijnzoekingen. De laatste gebruikte solverresidunorm is `0.0018398763633383775 cm/d`, met bevroren uitwisseling. Dat getal is **geen** verse gekoppelde nauwkeurigheidsmaat en mag niet als bewijs worden gebruikt dat V1 nauwkeuriger is dan V2.

## Bevinding 2: de bestaande V2 lost de onderliggende overgang niet op

V2 houdt de koppeling actief op alle evaluaties. Zij gaat rond de grens bij compartiment 45 heen en weer en wordt na zestig iteraties afgewezen. Het laatste actieve lokale residu is `0.08908466476123594 cm/d`; het totale residu `0.08925500948420444 cm/d`. Beide overschrijden de oorspronkelijke grenzen ruim.

| Kenmerk | V1 | Bestaande V2 |
| --- | --- | --- |
| Uitgevoerde Newtoniteraties | 60 | 60 |
| Backtrack-evaluaties | 120 | 166 |
| Uitgeputte lijnzoekingen met verslechterde laatste kandidaat | 10 | 14 |
| Maximaal uitgevoerde kandidaten per lijnzoeking | 4 | 4 |
| Evaluaties met bevroren koppeling | 19 | 0 |
| Voorlopige convergentie gevolgd door falende verse controle | 9 | 0 |
| Geaccepteerde stappen | 0 | 0 |

De kleinste werkelijk geëvalueerde lijnzoekfactor is `1/27`. Wanneer alle vier kandidaten falen, neemt de oorspronkelijke iteratielus de laatste kandidaat toch mee naar de volgende Newtoniteratie. Dat is een eigenschap van de oorspronkelijke uitvoering, geen geaccepteerde fysische tijdstap en hier niet als nieuwe programmeerfout gekwalificeerd. De factor in de trace na het verlaten van de lus kan al `1/81` zijn; die is niet als kandidaat geëvalueerd.

Bij V2 zijn veertien van die laatste kandidaten slechter dan de vorige doelfunctiewaarde. De evaluatiereeks passeert de lokale grens herhaaldelijk. Weglaten van de bevriezing verwijdert dus V1's specifieke eindcontrolecyclus, maar niet de procesomschakeling en de herhaalde uitputting van de lijnzoeker.

Voor beide varianten veranderen de lokale q45-rates niet tussen de gemeten toestand vóór en na de oorspronkelijke Jacobiaanberekening bij dezelfde h. Deze waarneming levert geen nieuwe volledige Jacobiaankwalificatie op; zij toont hier geen afzonderlijke rate-/Jacobiaanevaluatie-inconsistentie. Een gebruikelijke gladde afgeleide binnen één tak beschrijft vanzelfsprekend geen sprong tussen twee takken.

## Bevinding 3: één onafhankelijk lokaal operatorpaar toont de sprong

Alleen na de twee bovenstaande proeven is één drempelpaar geselecteerd. Elke kant begint onafhankelijk uit exact dezelfde oorspronkelijke V1-prefix, voorraad en sorptiegeschiedenis. Als trialdrukhoogten wordt de laatste verworpen V2-vector gebruikt. Alle drukhoogten blijven gelijk, behalve h45: links `-10.0000001 cm`, rechts `-9.9999999 cm`. De oorspronkelijke semigeïmpliciete geleidbaarheden blijven gelijk; `vector_F(1)` evalueert de oorspronkelijke ongereduceerde operator éénmaal. Daarna stopt het proces zonder acceptatie of `MACROSTATE`-commit.

| Grootheid | Links | Rechts |
| --- | --- | --- |
| h45 (cm) | `-10.0000001` | `-9.9999999` |
| q45 (cm/d) | `0.17319212624189878` | `0.04527206268922028` |
| F45 (cm/d) | `-0.03963183677313875` | `0.0882889101089921` |
| Bovenkant verzadigde matrixzone | 51 | 51 |
| Som natte wandfracties op compartiment 45 | 2 | 2 |

De uitwisseling springt `-0.1279200635526785 cm/d`. Het residu springt `+0.12792074688213084 cm/d`; de niet-uitwisselingsterm verklaart daarvan slechts `6.833294523556077e-7 cm/d`. De matrix-theta verandert `1.5544121545474354e-11`. Alle andere uitwisselingscomponenten zijn exact gelijk; de overige residuverschillen komen door de gewijzigde aangrenzende drukgradiënten en zijn maximaal `2.43e-7 cm/d`.

De sprong zit in de geaggregeerde **onverzadigde uitstroom uit macroporiën naar matrix**. Verzadigde/perched classificatie en natte wandfractie veranderen hier niet. De sorptieklok is overal gelijk aan de oorspronkelijke klok. Positieve-klokreferenties en sorptiviteiten zijn aan beide kanten gelijk. Een opnieuw berekende eventflag verandert wel; er wordt geen klok geïntegreerd of procesgeheugen gecommit.

De oorspronkelijke `ABSORPTION` bevat precies hier de harde Darcy-voorwaarde:

```fortran
if (H(ic) < cofgen(9,lay)-1.d-8 .AND. HMp > 1.d-8) then
   DelH = dmax1(0.d0,HMp-H(ic))
else
   DelH = 0.d0
end if
```

Vervolgens kiest de oorspronkelijke routine tussen sorptie en de Darcy-term en begrenst MACRORATE de potentiële uitwisseling met beschikbare voorraden. De bron en het ene operatorpaar onderbouwen dus een lokale harde overgang in deze context. Dit is geen epsilon-campagne en geen bewijs dat de fysische voorwaarde fout is. De bron noemt de `h_enpr`-aanpassing expliciet als GEM-aanpassing; haar bedoelde fysische contract is hier niet stilzwijgend vervangen.

Bij vastgehouden andere drukhoogten ligt nul tussen de twee gemeten residutakken, maar de overgang is niet glad. Daarmee is een duidelijke belemmering voor deze Newton-/lijnzoekroute vastgesteld. Het bewijst **niet** dat het volledige gekoppelde stelsel nergens een ongereduceerde oplossing heeft: andere drukhoogten zouden in een andere numerieke route kunnen mee veranderen.

## Toestand, kosten en bewaring

Beide solverroutes voeren na de afwijzing de oorspronkelijke rollback uit. De gemeten matrix-theta, geometrie, domein-/totale-/compartimentvoorraden en sorptieklok zijn exact gelijk aan de beginwaarden. Event-/sorptiviteitstrialwerk blijft apart geclassificeerd; geen schadelijke geheugenfout of noodzakelijke herstelpatch is hier aangetoond. Er is geen geaccepteerde stap, dus geen nieuwe geaccepteerde waterbalans of restartkwalificatie. Het gereduceerde behoudsbewijs uit INVENTORY03 blijft op zijn eigen scope staan.

Alle vier profielen (`V1`, `V2`, `LEFT`, `RIGHT`) zijn werkelijk uitgevoerd op native GNU Fortran 16.2.0 MSYS2 UCRT64 Windows bij O0 en O2. **Alle ruwe profielbestanden zijn bytegelijk O0/O2.** De acht routes kosten samen `8.948 s`; de langzaamste `1.743 s`. Geen enkele route bereikt twintig seconden. Geen volledige tweedaagse eindrun, geen herhaling van de vier-dt-serie, geen 481-daagse run en geen nieuwe scenariofamilie.

Twee fouten bij het opzetten van de diagnosekopieën zijn vóór modeluitvoering door de compiler gevonden: een V2-dispatch op de verkeerde tekstmatch en een routinenaamwijziging die eerst de commentaarregel raakte. Beide bouwlogs zijn bewaard in `setup-build/`; er is geen foutieve executable uitgevoerd. De gecontroleerde broncorrecties veranderen alleen meetdispatch en naamgeving. De oorspronkelijke V1/V2-vergelijkingslogica blijft intact.

Bron-/executable-identiteiten, daadwerkelijke compile/linkcommando's, oorspronkelijke closurehash, runrecords, iteratietraces en het operatorpaar zijn opgeslagen. De bewijscapsule bewaart ook de definitieve diagnose- en operatorexecutables. `assess_stagnation05.py` controleert de bewaarde gegevens zonder model of compiler te starten.

## Eindbesluit en kleinste vervolgstap

**Beide bestaande varianten zijn op deze oorspronkelijke stap niet gereed voor een ongereduceerde fysische B1-referentie.** V1's bevriezing verklaart een herhaalde voorlopige convergentie die de verse eindcontrole terecht weigert. De bestaande V2 maakt duidelijk dat bevriezing niet de enige blokkade is. De scherp geschakelde oorspronkelijke absorptieterm en de uitgeputte lijnzoekingen vormen de onderliggende lokale numerieke kwetsbaarheid.

Er is daarom geen solver-, geheugen- of fysische correctie voorgedragen. De meest verdedigbare volgende stap is **uitsluitend het bedoelde fysische contract van deze oorspronkelijke air-entry-/Darcy-/sorptieovergang vaststellen en lokaal kwalificeren**. Pas daarna kan een aantoonbaar bedoelde lokale correctie of expliciete numerieke behandeling van de omschakeling worden gekozen. Automatisch gladstrijken zou de wet veranderen zonder bewijs; extra iteraties, dichte Jacobianen, ruimere criteria of lager dtmin zijn door deze diagnose niet gerechtvaardigd.

Die vervolgstap is niet gestart. Er is geen derde algemene solvervariant, referentiepromotie, canonical-/B0-/B1.12-/releasewijziging of migratie. Geen promotie-PR geopend.

Gegevenscontrole: `python research/swap431-macro-b1-stagnation05/assess_stagnation05.py`.
