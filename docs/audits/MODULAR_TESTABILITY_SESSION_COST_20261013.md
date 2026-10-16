# Kritische uitvoeringsaudit van de modulaire workstream

Status: gemeten deelkosten, gerichte productiefeedback uitgevoerd; geen nieuwe
volledige F-CI gestart voor deze audit. Werkunit en oorspronkelijke wetenschap:
[modulaire testbaarheidsaudit](MODULAR_TESTABILITY_20261013.md).

## Meetbaarheid en reconstructie

Een exacte volledige uitsplitsing sinds de eerste Work-sessiestart is UNKNOWN.
Er is geen sluitende sessieklok met alle tool-, GitHub-, archiveer- en idle-events.
Wel bestaan oorspronkelijke compiler-events, 54 volledige benchmarkrecords,
getimede owner-/coupling-/preservationcontrollers en nieuwe directe native metingen.
De evidence bewaart ook mislukte pogingen; een mislukte uitvoering is geen PASS.
Dit rapport telt controllerduur niet nog eens bovenop de compiler/native-events
binnen die controller. Gelijktijdige taken zijn geen optelbare verstreken sessietijd.

| Activiteit | Werkelijk gemeten tijd | Reikwijdte / ontbrekende informatie |
| --- | ---: | --- |
| Compilatie | 1986,743756 s | 54 definitieve benchmarkrecords; brede kwalificatiesplit UNKNOWN |
| Linken | 4,770793 s | Dezelfde records, afzonderlijk van compilatie |
| Numeriek uitvoeren en native testdriver | 0,279767 s | Dezelfde records; assertions, output en physics onderling UNKNOWN |
| Identiteit- en dependencyvalidatie | 23,279491 s | Dezelfde records; dit is niet alle evidenceverwerking |
| Overige controller/IO | 6,074403 s | Rekenkundig residu van dezelfde records; geen zuivere Python-meting |
| Totaal van deze 54 records | 2021,148210 s | 3324 compilerverzoeken, 966 hergebruikte compilaties |
| Oudere v2 compiler-events | 17,402481 s | 27 compilaties in mislukte poging; link 0,569864 s, native 0,015756 s |
| Oudere v3 compiler-events | 727,918386 s | 1277 compilaties; link 9,403438 s, native 0,173614 s |
| Postfix-controle compiler-events | 490,505041 s | 624 compilaties; link 2,971474 s, native 0,054556 s |
| Richards-revisie-audit compilatie / link | 82,550368 / 0,648518 s | 92 compilerverzoeken, vijf builds inclusief profiling |
| Richards-revisie-audit native / profiling native | 24,337477 / 3,203328 s | 30 gematchte runs plus twee gprof-runs; strikt equivalente output FAIL blijft behouden |
| Python exclusief wachten op kinderen | UNKNOWN | Geen historische totale CPU-registratie |
| Evidence archiveren/verwerken | UNKNOWN | Validatietijd hierboven wel bekend; geen volledige archiefklok |
| GitHub-operaties | UNKNOWN | Geen uitputtende duurregistratie |
| Exclusieve wachttijd | UNKNOWN | Polling tijdens actieve berekeningen is geen extra testduur |

De v3 `FAILED.json` bevat de exacte prefix uit zijn tussentijdse `RESULTS.json`.
De collector controleert dit en telt de vereniging eenmaal, niet beide bestanden.
Compiler-eventtijden uit oudere batches missen controller-/identiteitoverhead;
ze zijn geen volledige testdoorlooptijden. De drie older batches en de definitieve
records zijn afzonderlijke uitvoeringen, geen nieuwe snelheidsvergelijking.

Een read-only `/proc`-steekproef van 120,367868 s in de reeds actieve F-CI-run
meet 120,48 CPU-s in de procesboom. Ondergrenzen per waargenomen proces zijn
55,06 CPU-s native driver/numeriek, 29,43 compilatie, 0,23 compiler/linkdriver,
0,44 Python, 0,55 shell en 0,31 onbekend. Nog 34,46 CPU-s zijn niet aan een
categorie toe te delen: korte processen en de laatste slice tussen samples.
Dit zijn CPU-ondergrenzen, geen volledige wall-split of extrapolatie naar uren.

## Grootste kosten en de noodzaak daarvan

1. De fresh highest low-air ownergate kostte **10678,726279 s** (2,97 uur).
   De normal-route kostte 496,858985 s met dezelfde soort brede buildclosure.
   De raw low-air-uitvoer toont voor één deeltraject 37791 substeps en 523944
   rejections; het volgende heeft 37801 / 524100. De gate omvat zes configuraties
   per optimalisatie en zes fine comparisons per configuratie. Daardoor is dit
   ook zwaar numeriek werk, niet alleen hercompilatie. Deze verse owning gate
   controleerde de gewijzigde serialized-backendgrens; geen highest case werd
   geërfd. Een apart begrensd direct executable-experiment hieronder onderzoekt
   die conclusie zonder de gate opnieuw te kwalificeren of toleranties te wijzigen.
2. De oorspronkelijke volledige moving F-CI kostte **8374,831716 s** (2,33 uur),
   exit 0, resume OFF. De twee runtime-reparaties raken optional-stategebruik en
   gekoppelde ledger/publicationsemantiek. Gerichte procesfeedback dekt die
   brede invloed niet. Eén stabiele preservationkandidaat was daarom verantwoord,
   na de gerichte eigenaar-, restart-, mass- en live-couplingcontroles.
3. De canonical-reconciliatie heeft nogmaals de volledige moving F-CI uitgevoerd:
   **7748,796257 s** (2,15 uur), exit 0, terminal PASS, resume OFF.
   Dit herhaalt veel onveranderde wetenschap: production-tree `d4412e09...` en
   reference-tree `c680d7a9...` zijn gelijk aan de vorige volledige PASS.
   Alleen de F-CI allocation-buildrouting en gecombineerde bronbewijsguard zijn
   anders. De al toegelaten canonical route heeft eigen full-route-evidence,
   maar het samengevoegde runnerpostimage is nieuw. De geldende
   [shared-routecontract](../development/FCI_SHARED_BUILD_ROUTE_CONTRACT_20261013.md)
   verlangt een werkelijke full local moving F-CI op persisted postimage voor
   route-admission. Dat verklaart de conservatieve herhaling; het bewijst niet
   dat alle herhaalde fysieke groepen op zichzelf gewijzigd of nodig waren.

De separate focused allocationcontrole kostte 1069,110812 s; SHARED 998,910659 s.
Dit is één volgorde onder overlappend ander werk, geen reproduceerbare A/B-winst.
De eerste canonical-fullpoging verloor compilerbestanden en faalde na 619,217103 s.
Dat is herstelverlies, geen wetenschap. De originele launcher, compiler en runtime
zijn vervolgens op hun geregistreerde hashes hersteld. De audit rechtvaardigt geen
nieuwe volledige run, ook niet voor deze documentatie/evidencewijziging.

De uitvoeringswerkwijze had te veel kleine status- en evidencepublicaties. De
volledige kosten daarvan zijn UNKNOWN. Ze verkorten de wetenschappelijke feedback
niet. De huidige afronding bundelt audit, ruwe metingen en eindstatus samen.

## Eén prioriteit: klein Boesten-procesfeedbackpad

Gebruik de bestaande controller, geen tweede framework of cross-run-cache:

```bash
# De gekwalificeerde compiler staat op PATH; een nieuwe outputdirectory is koud.
python tests/modularity/run_modular_tests.py --case boesten --output /tmp/boesten-feedback
```

Dit roept de ongewijzigde daadwerkelijke productieprocesdriver aan, met dezelfde
O0/O2-flags en assertions. Het proces heeft geen runtimeimports; de oorspronkelijke
runner compileerde toch eerst de brede runtimevoorzieningen. Die bouwvoorbereiding
is voor deze procesleg vermijdbaar. Het runtime/mass/restartdeel blijft apart nodig
als de desbetreffende afhankelijkheden of toelatingsgrens veranderen.

Drie afwisselende rondes in de definitieve benchmark meten een koude mediane
O0/O2-doorlooptijd van **282,169 s naar 1,384 s**: **280,785 s bespaard (99,51%)**.
Compilerverzoeken dalen van 458 naar 6, met 452 vermeden compilaties. Executables
zijn byte-identiek per optimalisatie; wetenschappelijke stdout is identiek over
routes, O0/O2 en herhalingen. Warm in dezelfde transactie: 0,615 s, nul compiler-
verzoeken. Dit is uitsluitend de procesleg, geen vervanging van de volledige
Boesten-kwalificatie en geen algemene solverversnelling.

Een actuele gerichte hercontrole op `0a77e6200a62eba46d5b0d2a6c62da958865719c`
slaagt: koud O0/O2 samen **1,394347 s**, warm **0,473724 s**; dezelfde stdout SHA256
`cdc46bcf142ebd693c82a7bc4c64a35e255fab8785653ce9eb6ca5ce79f9a679`.
Dit is een actuele uitvoerbaarheidscontrole; de herhaalde voor/na-evidence blijft
het genoemde drievoudige experiment, niet deze losse sample.

## Architecturele betekenis en volgende toelatingsbeslissing

Functionele modulariteit is aanwezig maar wordt niet overal als kleine buildclosure
benut. De Boesten-procesfunctie kan los worden getoetst; accepted heat blijft
154 providers nodig hebben doordat accepted-state-types in de serialized backend
staan. Dat is een codeorganisatiegrens, geen bewijs dat temperatuur fysisch van
water losstaat. Splits die backend niet alleen voor een benchmark: state ownership,
rollback, restart en integratie-evidence moeten zo'n wijziging dragen.

Pas de bestaande vier niveaus toe vóór het starten van een nieuwe dure gate:
kleine contractdrivers tijdens wijzigen; state/interface bij mutable-stategrenzen;
gerichte fysische samenstelling na lokale stabiliteit; volledige owning/admission-
preservation bij de stabiele integratiekandidaat. Leg in de bestaande werkunit vast
welke concrete gewijzigde dependency of contractclausule een brede herhaling vraagt.
Een docs/evidence-only opvolger met een volledig bewezen gelijk executable/scientific
oppervlak vraagt documentcontrole en bewijsvalidatie, geen nieuwe full F-CI.
Een oude PASS zonder bron-, driver-, flags-, compiler-, oracle- en omgevingsbinding
mag nooit als inheritance gelden. Bij een veranderd full-runnerpostimage gaat de
expliciete route-admissionautoriteit vóór de small-modulebuildgraph.

De twee volledige preservationruns samen kosten 16123,627973 s aan taakduur;
de mislukte compilerverliespoging voegt 619,217103 s toe. Dit is herhaalde
kwalificatiebelasting, geen exclusieve verstreken sessietijd. Hun verschil van
626,035459 s is geen gecontroleerde A/B-winst: route, planning en overlap verschillen.

## Rechtstreekse uitvoering van reeds gebouwde programma's

Twaalf uitvoeringen (drie afwisselende rondes, root/sensor op O0/O2) slagen zonder
compilerverzoek. Iedere stdout en exit zijn gecontroleerd tegen de oorspronkelijke
gekwalificeerde uitvoer en iedere executable heeft een vastgelegde SHA256.

| Native programma's | Mediane walltijd per O0/O2-paar | O0-samples (s) | O2-samples (s) |
| --- | ---: | --- | --- |
| Allocation root | 199,373929 s | 139,751 / 142,340 / 129,212 | 47,295 / 57,033 / 86,552 |
| Allocation sensor | 92,030207 s | 90,280 / 47,309 / 59,620 | 30,129 / 33,721 / 32,410 |

Alle vier samen hebben een mediane ronde van **307,454691 s**; de twaalf runs
kosten samen 895,652987 s. De totale focused SHARED-route kostte 998,910659 s,
de SEPARATE-route 1069,110812 s, met dezelfde wetenschappelijke native output.
Het verschil met directe uitvoering bevat build-, link-, validatie- en runnerwerk,
maar is geen gemeten zuivere compilatiesplit: de metingen zijn op verschillende
momenten en deels onder overlappend werk gedaan. De CPU- en wall-samples staan
apart in de raw evidence. De tijdvariatie verbiedt een algemene solverclaim.

Deze programma's toetsen echte Richards/state/restart-samenwerking. Het kleine
Boesten-contractprogramma heeft daarentegen geen solverinitialisatie en voert
slechts zijn expliciete procescontract uit. Modulaire testbaarheid vereist dus
ook een passende testscope; een klein driverbestand garandeert geen kleine
numerieke taak of dependencyclosure.

De begrensde low-air O2-observatie stopt na **60,020911 s**, met **57,573644 CPU-s**,
zonder compilatie. Ze haalt nog geen terminal resultaat: exit/volledige duurtijd
zijn UNKNOWN en de status is `CENSORED_NOT_QUALIFICATION`. De oorspronkelijke
hoogste ownergate blijft het PASS-bewijs. Dit experiment bewijst actieve zware
native uitvoering, geen nieuwe wetenschappelijke toelating en geen volledige
retrospectieve numerieke tijdsplit.
