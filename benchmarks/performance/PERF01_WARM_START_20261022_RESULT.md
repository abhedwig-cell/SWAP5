# Warme start gemaakt en beproefd

Datum: 22 oktober 2026. Status: lokaal geïmplementeerd en fysisch gecontroleerd;
standaard uit, geen canonical-admission of merge.

De Reference-oplosser kan nu een eerdere iteratie of succesvolle oplossing als
numerieke beginwaarde gebruiken. De fysieke uitgangstoestand, waterinhoud,
oppervlakteberging en forcing blijven uit de oorspronkelijke request komen.
Een cache mag alleen dezelfde fysieke oorsprong hergebruiken, of een exact
overeenkomend succesvol eindpunt voor een vervolg voorspellen, met dezelfde
geometrie, hydraulische parameters en forcing. Elke externe applicatiestap wist
de geldigheid; de cache zit niet in de fysieke herstarttoestand.

Een predictor moet eerst een factor 100 kleiner kwadratisch residu geven dan de
koude beginwaarde. Hij krijgt maximaal drie Newton-iteraties per gewone fase.
Bij mislukken volgt een koude poging met de oorspronkelijke limieten en gates.
Beide HeadCalc-aanroepen en alle werkelijke Newton-/hydraulische evaluaties
worden meegerekend. De bestaande begrensde cornerfase blijft beschikbaar.

De expliciete parameter is `weather_trial_warm_start`, standaard false. Voor de
rechtstreekse solver bestaat de numerieke selectie `reuse_trial_head`. Alleen
de begrensde weather Reference/MvG/mean1/freebottom-route met vaste bron- en
wortelsinks komt in aanmerking; onbekende of hoofdafhankelijke providers houden
de koude route. Hydraulische wetten, oppervlaktewet, tolerantie en fysieke
acceptatiecriteria zijn niet aangepast.

## Prestatiemeting

Drie afwisselende, seriële aan/uitparen per neerslaggeval, dezelfde actuele
productieproviders en compilerinstellingen. Alleen de expliciete optie in de
gegenereerde bestuurder verschilt. Elke berekening duurt 97 dagen, met 64
externe intervallen per dag en een temporeel vergelijkingsbudget van 10^-3 cm.

| Neerslag | Mediaan koud, CPU s | Mediaan warm, CPU s | Warm/koud |
| --- | ---: | ---: | ---: |
| 1×, 227 mm | 2,027 | 2,330 | 1,149 |
| 4×, 908 mm | 7,260 | 8,087 | 1,114 |

Deze implementatie levert dus in deze proef geen snelheidswinst. Bij 4× neemt
het werkelijk getelde aantal HeadCalc-aanroepen toe van 138.057 naar 155.353,
terwijl de geaccepteerde substeps slechts veranderen van 18.135 naar 18.221.
De extra predictorcontroles en koude terugvallen betalen zich hier niet terug.

Ook dag84 laat geen overtuigende winst zien: mediane gemeten kern-CPU ongeveer
1,395 s koud versus 1,525 s warm. Er is duidelijke timingvariatie, waaronder één
warme dag84-waarneming van 5,342 s bij exact dezelfde fysieke uitkomsten en
werktellers. De volledige ruwe waarnemingen blijven behouden. Dit is lokaal
prestatiebewijs en geen overdraagbare snelheidsgarantie; eerdere tijden uit een
andere sessie worden niet als een gematchte vergelijking gebruikt.

## Fysieke en transactionele controles

Alle twaalf seizoensberekeningen voltooien. Bij 4× is het grootste dagelijkse
bergingsverschil warm/koud 0,000297 mm. Het verschil in totale runoff is
+0,000532 mm en in onderranduitvoer -0,000529 mm. Bij 1× is het grootste
bergingsverschil 0,000262 mm en blijft runoff nul. De onafhankelijke bruto
dagbalansen sluiten op afrondingsniveau. Biomassa, LAI en transpiratie blijven
gelijk in deze proef met voorgeschreven dagelijkse opname.

Werkelijke controles op huidige productiecode:

- O0 met runtimechecks en O2: 97-daagse fysieke stdout/ontvangstbewijzen exact;
- actieve reconstructie na natte dag35: exact gelijk aan de ononderbroken warme
  berekening, binnen hetzelfde proces;
- geforceerde afwijzing na één private stap: 21 fysieke/toestandsbits, gewasrevisie
  en afwezigheid van gepubliceerde bruto-fluxbewijzen behouden;
- directe productiecontracten voor een kleinere herpoging, exacte
  eindpuntvoorspelling, gewijzigde forcing/parameteridentiteit/fysieke oorsprong,
  niet-eindige cache, cachewissen, default-OFF en mislukte warme plus koude fase;
- oorspronkelijke crossing- en dag43-cornerdrivers ongewijzigd geslaagd;
- zes oorspronkelijke weatherprofielen en twee ongewijzigde solvercontracten
  per optimalisatie, inclusief bytegelijke koude voor/na-uitvoer;
- default-OFF seizoenontvangstbewijzen exact gelijk aan de oorspronkelijke
  PR1361-berekening.

Twee eerdere, volledig doorlopende maar tragere prototypes blijven in de
bewijsset. De eerste gaf slechte voorspellers het volledige Newton-budget.
De tweede begrensde dat werk en voegde vervolgvoorspelling toe. Hun oude veld
`headcalc_calls` telde solverrequests en liet koude terugvalaanroepen weg; die
oude tellers zijn geen bewijs van minder werkelijk solverwerk. De definitieve
teller is daarvoor hersteld en de definitieve benchmark is opnieuw uitgevoerd.

## Besluit en grens

Behoud de geteste optie als onderzoeksvoorziening, standaard uit. Automatische
activering zou deze 1×/4×-proef vertragen. Warme initialisatie is daarmee nog
geen oplossing voor de grote kosten van mislukte Newton-pogingen rondom
verzadiging. Een verdere optimalisatie moet aantonen dat zij dat aantal of de
kosten van die pogingen werkelijk vermindert.

PR1361 blijft draft. De bestaande SOL/NUT/FSI35-bron-/toelatingsketen moet het
gewijzigde solverbeeld nog expliciet beoordelen. Nieuwere canonical-wijzigingen
op onder meer dezelfde backend zijn gezien maar niet overschreven of als
geïntegreerd geclaimd. Geen 10^-6-run, hoogste low-air-matrix of uitbreiding van
RossFast is geselecteerd.

Contract: `docs/science/PERF01_WEATHER_WARM_START.md`. Herstelpunt:
`benchmarks/performance/PERF01_WARM_START_20261022_STATUS.json`. Brongebonden
bewijs en ruwe runs: `PERF01_WARM_START_20261022_EVIDENCE.tar.xz` met index en
samenvatting. Controle:
`python benchmarks/performance/verify_perf01_warm_start.py --self-test`.
