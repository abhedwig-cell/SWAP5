# Modulaire testbaarheid en lokale ontwikkelcyclus

**Status: Proposed ontwikkelstandaard; opt-in implementatieproef.** Baseline:
`1800a1b0d5a8ec38e5e5a2c5a15e916f922dd520`, canonical
`integration/f-ci-canonical`. Formules, state-layout, toleranties,
referenties, workflows en bestaande admissiongates blijven behouden. Eén
productiebackend krijgt een allocatiecontrole voor een optionele macroporieconfiguratie,
na een reproduceerbare crash in de oorspronkelijke geïntegreerde Boesten-test.
De afsluitende canonical-reconciliatie is
`8dac664db83dda8338ef0ffe0f92b55541876978` (PR #1218); zijn productie- en
referentietrees zijn byte-identiek aan de meetbasis.
Werkunit/recovery: `integration/audits/MODULAR_TESTABILITY_20261013.json`.

## Diagnose en afbakening

SWAP5 heeft kleine wetenschappelijk toetsbare functies, maar de uitvoerbare
kwalificatieroutes mengen vaak componentbewijs met runtime- en preservationbewijs.
Dat is een ontwikkelprobleem als een ontwikkelaar alleen het directe contract
wil onderzoeken. Voor admission zijn die ruimere controles wel nodig.

Functionele modulariteit betekent een afgebakende verantwoordelijkheid.
Buildonafhankelijkheid betekent dat de compiler slechts een begrensde verzameling
providers nodig heeft. Testbaarheid vereist ook valide constructie van inputs,
controleerbare output en een oracle. Fysische onafhankelijkheid betekent dat een
proces zonder zijn normale partners betekenisvol kan worden beoordeeld. Die vier
eigenschappen vallen niet samen. Een kleine `use ..., only:` beperkt geïmporteerde
namen, maar verkleint niet het te compileren Fortran-providerbestand.

De bestaande Boesten-route compileert haar uitgebreide runtimeclosure vóór de
procestest. De procestest linkt vervolgens alleen `mod_restricted_surface_evaporation`
en de driver. Die module heeft geen SWAP-imports. Het weglaten van overige
compilaties verandert dat procesprogramma niet. Het weglaten van runtimeprogramma's
zou wel dekking verliezen: deze proef presenteert daarom alleen gelijkheid van
de **zelfde procesleg**, geen vervanging van de volledige kwalificatie.

Een tweede probleem zit in codeorganisatie. De read-only geaccepteerde
temperatuuraccessor importeert fysieke state-types uit
`mod_fmr_serialized_reference_backend`. De compiler bouwt daardoor 154
bronbestanden, hoewel de accessor geen watervergelijking oplost. De afhankelijkheid
van geaccepteerde state-identiteit is noodzakelijk; de plaatsing van state-types
in dezelfde compilatie-eenheid als de gehele backend is dat niet per definitie.
Een typesplit vraagt gedeelde state/restart/HY/RT-kwalificatie en wordt hier niet
uitgevoerd om een benchmark te verbeteren.

## Tien componenten

De volledige directe providergraph, transitieve bronvolgorde, bronhashes en
werkelijk uitgevoerde compiler-/linkcommando's staan in de evidence. De aantallen
hier zijn **providerbronbestanden**, inclusief de expliciet genoemde legacyfixture
waar nodig, zonder gegenereerde probe en eventuele externe `headcalc.f90`.
Full Richards bevat 16 productieproviders plus één legacyfixture; de accessor
153 productieproviders plus diezelfde fixture. Dit is geen fixturevrije
standalone-applicatie. De compile/linkprobes bewijzen API-bouwbaarheid, geen fysische
kwalificatie. De drie geselecteerde productiedrivers toetsen werkelijk gedrag.

| Component / productiebron | Publiek contract en noodzakelijke inputs | Closure | Verborgen toestand / initialisatie en testgrens |
| --- | --- | ---: | --- |
| Hydrauliek: `src/solver/mod_b110_default_mvg_provider.f90` | K(h), provider voor theta/C/dKdh; expliciete cofgen-parameters, node en head | 2 | Contractprovider plus eigen module. Parameterinitialisatie en providerbinding verplicht; foutieve node/nonfinite head fail-closed. FSI39 en MICRO05 zijn begrensde oracles, geen bewijs voor alle 12 modellen |
| Full Richards: `src/adapter/mod_reference_richards_legacy_binding.f90` | `reference_richards_legacy_solver_t%solve`, request/result/workspace | 17 | Worker/state-binding, lineaire solve en legacy `variables`/grid zijn noodzakelijk in deze seam. Bestaande legacy fixtures zijn contextscaffolds, geen onafhankelijke hydraulic oracle. Werkelijke solve en mass/retry moet apart draaien |
| Tijdstap: `src/runtime/mod_timestep_controller_contract.f90` | Pure controllerproposals uit accepted context; safety floor/ceiling | 2 | Historische decision service is directe provider. Expliciete context, geen gehele runtime nodig. Componenttest bewijst geen correcte eventclipping/publicatie |
| Transaction: `src/transaction/mod_transaction_reference.f90` | `execute_reference_interval`, abstract state/model/context, mass/status | 1 | Concrete modeltestdouble geeft controle over fouten; testdouble kwalificeert geen productiephysics. A23BL en attempt-context toetsen accept/retry/rollback, productie-integratie blijft verplicht |
| Verdamping: `src/process/mod_restricted_surface_evaporation.f90` | Black/Boesten-contributie uit parameters, forcing en committed pair | 1 | Geen imports buiten intrinsieke modules. Mutable kandidaat expliciet; input-state blijft authority tot commit. Procesoracle en invalid-input tests nodig; hydraulische mass-owner en joint restart vragen runtime |
| Wortelopname: `src/process/mod_root_water_uptake_process.f90` | `evaluate_macro_feddes_drought_uptake`, parameters/request/hydraulic view/flux | 3 | Viewcontract en solvercontract; geen HeadCalc-internals. Valide profiel/rootparameters nodig. Lokale stress/sinkverdeling plus accepted-soil/mass/crop-compositie |
| Drainage: `src/process/mod_drainage_hooghoudt_equivalent_depth.f90` | Voorbereide geometrie, status en equivalent depth | 1 | Geen mutable globale data. Branchegrenzen/ongeldige geometrie lokaal toetsbaar. Voorbereiding is geen afvoer- of grondwaterownershipbewijs |
| Gewas: `src/crop/mod_wofost81_assimilation.f90` | Pure `totass81`/`assim81`, expliciete canopy/weer/N-inputs | 1 | Geen kalender/lifecycle-init. PCSE-6.0.13-bron-faithful oracle onder `tests/fwof/pp02`. Assimilatie bewijst geen crop-lifecycle, N-owner of accepted-watergebruik |
| Temperatuur: `src/process/mod_restricted_soil_temperature.f90` | Parameters/state/forcing/hydraulic view/workspace/result; trial en restart | 5 | Solver/view/heatcontracts; valide volumefracties en heatstate. F-VQ58 dense DeVries-oracle, energieclosure, refinement, reject/restart; coupled water/frost vraagt niveau 3 |
| Gedeelde runtime: `src/runtime/mod_fmr_crop_accepted_soil_temperature.f90` | `sample_committed_crop_soil_temperature`, lineage/revision/time/node | 154 | Backend-types bepalen grote closure. Echt committed state construeren, cold/absent/invalid/mismatched state afwijzen. Dit is state-authoritytest, geen onafhankelijke fysische temperatuurfunctie |

Bij de eerste verkenning was de compatibility task2-adapter geselecteerd. De
25-bestanden-importclosure compileerde niet met de algemene legacy scaffold:
ontbrekende variabelen en een scalar `cofgen` versus vereiste array. Dat is
concreet bewijs dat een `use`-graph geen bruikbare initialisatie- of buildautoriteit
is. De audit gebruikt vervolgens de geaccepteerde Full Richards-solverseam.
De mislukte compilerlogs blijven bewaard; een mislukte probe wordt niet PASS.

De drainagebron heeft bestaande onafhankelijke equivalent-depth/branch-authority
F-VQ38, beschreven in `docs/science/drainage-formulations.md`. De latere
runtime-oracle F-VQ73 wordt door F-CI61 exact gereconstrueerd uit commit
`ea40e2d850aa9b4b23b25ba6b4a63ffd39811001`; zijn donorlocators zijn
`tests/fvq/run_fvq73_independent_runtime.sh` en
`tests/fvq/test_fvq73_fpm14_drainage_response_independent.f90` op dat commit.
Deze donorlocators zijn geen huidige working-tree-bestanden. Het oude
admissionscript met zijn historische canonical-racelock wordt niet als actuele
gate aangeroepen. De nieuwe lokale drainagecontrole toetst domein en limiet,
geen volledige independent branch-oracle.

Directe niet-intrinsieke imports: hydrauliek → solvercontract; timestep →
historische decision service; root → hydraulic view → solvercontract;
temperatuur → hydraulic view en heatcontract → solvercontract; runtime-accessor
→ transaction, kernel, backend, heatcontract. De vier pure/zelfstandige
transaction-/verdampings-/drainage-/assimilation-eenheden hebben geen
niet-intrinsieke imports. Voor Full Richards staat de grotere volledige graph
in `AUDIT.json`, inclusief legacyproviders. De compiler valideert de modulevolgorde.


### Daadwerkelijke O0-bouwprobes

| Component | Providers | Totaal gecompileerde Fortranbestanden | Compilerverzoeken | Build + link + probe (s) |
| --- | ---: | ---: | ---: | ---: |
| hydraulics | 2 | 3 | 3 | 1.096 |
| richards | 17 | 19 | 18 | 8.939 |
| timestep | 2 | 3 | 3 | 0.465 |
| transaction | 1 | 2 | 2 | 1.350 |
| evaporation | 1 | 2 | 2 | 0.927 |
| root | 3 | 4 | 4 | 1.895 |
| drainage | 1 | 2 | 2 | 0.309 |
| crop | 1 | 2 | 2 | 0.213 |
| temperature | 5 | 6 | 6 | 1.703 |
| runtime | 154 | 156 | 155 | 38.118 |

De laatste probe-aanroep compileert de kleine driver en eventueel HeadCalc en
linkt ze tegelijk. Daarom kan het aantal Fortranbestanden hoger zijn dan het
aantal compilerverzoeken. De benchmarkdrivers gebruiken afzonderlijke compile-
en linkaanroepen. Beide telwijzen zijn expliciet in de ruwe commando-evidence.

## Bestaande tooling en implementatie

`tests/support/augment_bartholomeus_backend_sources.py` blijft de bestaande
source-augmenter. Zijn CLI-output wordt vergeleken met de ongewijzigde canonical
implementatie. Een opt-in importeerbare `strict_closure` voegt duplicate-provider,
unresolved-import, cycle en include/preprocessor/submodule-afwijzing toe.
Onbekende buildinputs worden niet als veilige onafhankelijkheid geaccepteerd.
Er komt geen tweede qualificationselector en geen nieuw verplicht register.
De gemeten tien closurebudgetten en duplicate-bronafwijzing worden door lokale
tests bewaakt. Een budgetwijziging vereist opnieuw meten en verantwoorden.

`tests/modularity/run_modular_tests.py` bedient drie bestaande ongewijzigde
Fortran-productiedrivers: FSI39 MvG, Boesten-proces en accepted crop-heataccessor.
Hij compileert echte productieproviders, bewaart O0/O2 afzonderlijk, controleert
science-markers en volledige stdoutidentiteit, en legt bronvolgorde, compilerflags,
compiler/frontend/library-identiteit en artifacthashes vast.

Koud betekent een lege artifactdirectory, niet een leeggemaakte OS-pagecache.
Warm betekent heruitvoering in dezelfde levende gecontroleerde transactie.
Elke scientific driver wordt opnieuw uitgevoerd; geen eerdere PASS wordt geërfd.
Alle bron-, flag-, omgeving-, compiler- en artifactidentiteiten moeten gelijk zijn.
Een gewijzigde bron krijgt een nieuwe build. Beschadigde artifacts worden
fail-closed afgewezen. Dit is geen persistente compilation-cache of bewijsinheritance.
O0/O2, verschillende flags en verschillende closures worden niet vermengd.
Stdoutidentiteit is geen aanvullende numerieke oracle. Voor de bestaande drivers
blijven hun ongewijzigde assertions en referentietoleranties de wetenschappelijke
autoriteit; executablehashes worden daarnaast per optimalisatieniveau vergeleken.

De bestaande cache-V1 blijft opt-in en ongewijzigd. De gemeten eerste-vullingskosten
maken eerst verkleinen van lokale closures en hergebruik binnen één transactie
logischer dan verdere cross-run-cachecomplexiteit. Kosten van actual identitychecks
zijn apart gemeten; de capsule is geen volledig gekwalificeerde OS/toolchainclosure
voor cross-run of cross-host inheritance.

## Vier testniveaus en wijzigingsbeslissing

| Wijziging | Onmiddellijk, vóór volgende ontwikkelstap | Stabiele integratiekandidaat | Admission / inheritance |
| --- | --- | --- | --- |
| Pure formule, parameter- of branchecontrole | Niveau 1: daadwerkelijke productiecall, independent oracle waar beschikbaar, invalid/limitcases, bestaande O0/O2 | Niveau 3: getroffen flux/state-compositie en huidige solverroute | Niveau 4: owning scientific/preservation/F-CI-contract; unrelated evidence uitsluitend bij complete onveranderde closure |
| Mutable processtate of outputcontract | Niveau 1 plus 2: input nonmutation, A/B/A, fail-closed, producer/consumer, units en mass-owner | Niveau 3: accepted physical state, reject/retry, joint restart, gerichte downstreamprocessen | Niveau 4: verplichte owner-, restart-, Full Richards- en preservationgates |
| Solver, timestep, kernel/state-layout of gedeelde runtime | Niveau 1 plus 2: contract, numerical properties, finite inputs, reject/restore; affected existing tests | Niveau 3 vroeg: event/temporal, mass, continuation, producer/consumer en relevante coupling | Niveau 4 verplicht volgens owning authority; brede relevante preservation kan niet worden uitgesteld voorbij de contractgrens |
| Buildrunner, dependencyselectie, flags of compileromgeving | Negatieve selection/identity/compilation-controls; originele assertions daadwerkelijk uitvoeren en route-output vergelijken | Niveau 3: alle getroffen integratieprogramma's; buildbesparing is geen sciencebewijs | Niveau 4 bij vervanging van default/admissionrunner; deze opt-in feedbackroute vervangt niets |
| Alleen beschrijvende documentatie | Docs/links/schema/whitespace | Geen numerieke run door documentatie alleen | Geen inheritance zonder expliciete dependency/authoritybinding; gelezen config/manifests zijn uitvoerinputs |

Niveau 1 bewijst gedrag binnen het directe contract. Niveau 2 bewaakt state en
interfaces. Niveau 3 bewijst gerichte samenwerking met de echte solver en accepted
fysieke toestand. Niveau 4 bewaakt alle door de bestaande autoriteit verplichte
historische, mass-, restart-, F-CI- en couplingclaims. Geen niveau kan stilzwijgend
als een ander worden benoemd. Onder onzekerheid over impact wordt conservatief
breder getest, niet op alleen de Fortran-importgraph gekozen.

## Compacte ontwikkelstandaard

1. Nieuwe fysische functionaliteit heeft één herkenbare verantwoordelijkheid,
   expliciete parameters/forcing/state/result en een kleine uitvoerbare
   productiedriver. Een testkopie van de formule vervangt de productiecall niet.
2. Mutable state blijft explicit committed/candidate/workspace; geen verborgen
   initialisatie via globale variabelen, files of kalender. Bestaande legacyseams
   worden als uitzondering met concrete initialisatievoorwaarde beschreven.
3. Bij de driver hoort de kleinste daadwerkelijk compileerbare en linkbare
   productieclosure, met expliciete externe procedures/fixtures/flags. Grotere
   noodzakelijke dependencies worden in de bestaande PR/workunit verantwoord.
   Graphanalyse is geen automatische wetenschappelijke testselectie.
4. Level-1/2 feedback gebeurt lokaal tijdens ontwikkelen. Level-3 compositie volgt
   zodra de betrokken route uitvoerbaar is en vroeger als shared semantics geraakt
   wordt. Level-4 gebeurt voor stabiele admissionkandidaten en waar een huidige
   autoriteit dit eerder vereist. Bestaande gates blijven doorslaggevend.
5. Identieke objecten kunnen binnen één gecontroleerde uitvoering gedeeld worden
   bij exacte flags/bron/provider/module/toolchainbinding. O0/O2 blijven gescheiden;
   drivers worden onafhankelijk gelinkt en uitgevoerd. Cross-run inheritance
   vereist terminal bewijs en volledig bewezen ongewijzigde inputclosure.
6. Een PR beschrijft directe contracttests, echte compositietests, gemeten closure,
   ontbrekende oracles en bounded claim. Een niet-zelfstandig onderdeel krijgt een
   concrete reden, geen algemene bewering dat het modulair is.

De huidige proef vereist geen brede state-typesplit of productieherontwerp.
Voor resterende migraties beginnen pure hydraulische/process/oraclecontrollers
klein; drainage/irrigatie/root/NUT-SOL krijgen daarnaast expliciete mass-owner en
accepted-state-compositie; cropkalender/lifecycle en coupling blijven gedeelde
contractwerkpakketten. Onderzoek van een backend-state-typesplit is de volgende
architectuurkandidaat, pas met HY/RT/restart-preservation. Een klein feedbackpad
verkort foutdetectie; hoeveel arbeidsuren de totale migratie bespaart blijft
UNKNOWN zonder prospectieve ontwikkelmetingen.

## Meetresultaten en grenzen

De voltooide A/B-proef bevat 54 records: drie componenten, drie afwisselende
rondes, O0/O2 en oorspronkelijk koud / gericht koud / gericht warm. Gemeten
commit: `2daabb9d4a014c4b1616c95505abd04d5e95a439`, met de productiebronnen
van canonical. GNU Fortran 13.3.0, dezelfde host en dezelfde flags per
component. De tabel geeft medianen van de **som O0 + O2 per ronde**, geen
som van losse medianen. Ruwe records bevatten alle drie de samples.

| Component en route | Compilatie (s) | Link (s) | Uitvoeren (s) | Identiteitcontrole (s) | Totaal (s) | Compilerverzoeken |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| MvG oorspronkelijk koud | 3.144 | 0.178 | 0.011 | 0.587 | 4.051 | 8 |
| MvG gericht koud | 2.906 | 0.141 | 0.012 | 0.724 | 3.862 | 8 |
| MvG gericht warm | 0 | 0 | 0.013 | 0.698 | 0.706 | 0 |
| Boesten procesleg oorspronkelijk koud | 280.158 | 0.174 | 0.006 | 1.064 | 282.169 | 458 |
| Boesten procesleg gericht koud | 0.431 | 0.156 | 0.011 | 0.563 | 1.384 | 6 |
| Boesten procesleg gericht warm | 0 | 0 | 0.011 | 0.602 | 0.615 | 0 |
| Accepted heat oorspronkelijk koud | 187.583 | 0.419 | 0.012 | 1.429 | 190.550 | 314 |
| Accepted heat gericht koud | 174.675 | 0.400 | 0.012 | 1.045 | 176.411 | 314 |
| Accepted heat gericht warm | 0 | 0 | 0.008 | 1.060 | 1.081 | 0 |

Boesten gaat van 228 gecompileerde Fortranbestanden per optimalisatie naar twee:
452 vermeden compilaties per O0/O2-paar. Alle oorspronkelijke procesassertions
draaien; de executables zijn byte-identiek tussen routes per optimalisatie en
alle stdout is identiek, ook over O0/O2 en herhalingen. Warm hergebruikt MvG zes,
Boesten vier en accepted heat 312 compilaties per paar. Geen scientific driver
wordt overgeslagen. MvG en accepted heat hebben **geen kleinere koude closure**;
hun koude tijdverschillen bewijzen geen architectonische versnelling. Accepted
heat bewijst wel efficiëntere herhaalde toetsing in dezelfde transactie.

Bij warme uitvoering zijn compiler-/dependencychecks de grootste kostenpost.
Dit is een bewust transparante eerste proef; optimalisatie van de scan is later
mogelijk zonder de scientific driver te wijzigen. Een nieuwe Python-aanroep
is weer koud. De proef kwalificeert geen algemene cross-run-cache.

De host is gedeeld; ander SWAP5-kwalificatiewerk was zichtbaar. OS-pagecache is
niet geflusht. De afwisselende rondes en raw samples maken variatie zichtbaar,
maar leveren geen portable snelheidsfactor of gemeten arbeidsurenbesparing.
De oorspronkelijke 99,35 s irrigatiekwalificatie en 340 compilerverzoeken zijn
historische evidence, geen huidige solverbenchmark en geen directe comparator
voor deze andere Boesten-procesleg.

### Positieve en negatieve wetenschap en backendreparatie

Vijftien toolingcontrols slagen, inclusief daadwerkelijke compilerfout,
scientific-driverfout, bronwijziging tijdens bouwen, artifactcorruptie,
environmentdrift, graphfouten en de tien closurebudgetten. De bestaande
source-augmenter CLI behoudt zijn canonical output; de brede Boesten-lijst telt
227 bronnen vóór de driver, SHA256 van stdout
`508c878ae08afe3d645eb3392ea615cd912c122ace9b98ace20d9d1333e3f634`.

Aanvullende echte productiecalls toetsen ongeldige en niet-eindige hydraulische
inputs, Boesten nonmutation en domein, drainagegrenzen, tijdstapcontract,
root/frost-interactie en de oorspronkelijke F-VQ58 temperatuurdriver. De
PCSE-gebonden assimilatiecontroller controleert 1206 cases op O0 en O2 met
maximale absolute en relatieve afwijking nul. MICRO05 literal MvG en A23BL
transaction draaien ook via hun oorspronkelijke runners. Testdoubles in A23BL
blijven contractbewijs; zij vervangen geen productiephysics.

Een NaN in Boesten wordt onder de behouden floating-point-traps op O0 met
SIGFPE geweigerd; O2 retourneert de ongeldige-inputstatus. Beide negatieve
subprocessen zijn vastgelegd. **Een gelijk error-statuscontract over O0/O2 is
hier niet bewezen.** De controller accepteert uitsluitend deze specifieke
uitkomsten, niet een willekeurige crash. De bekende contractkloof blijft open;
geen flags of tolerantie zijn verzwakt.

De oorspronkelijke volledige Boesten-preservation crashte op O0, zowel met
standaard als onbeperkte stack. De afzonderlijke procesleg bleef PASS. Een
debugbuild lokaliseerde de crash bij dereferentie van niet-gealloceerde
`self%macropore_config` in de serialized backend, terwijl Boesten geldig is
zonder actieve macroporiën. Dit is een concrete verborgen optionele afhankelijkheid
die niveau 1 niet kan vinden. De gerichte reparatie gebruikt een geneste
`allocated`-controle, omdat Fortran geen short-circuit `.and.` garandeert.
De actieve donorberekening blijft dezelfde; geen fysieke formule is gekopieerd.

Reparatiepostimage: `51152a8ee74beef7a45204101bc830247b521285`. De oorspronkelijke
volledige Boesten-runner slaagt daarna op O0/O2, inclusief hydraulic mass-owner,
hard mass, afgewezen trial, gewijzigde-dt retry, exacte restartpair en ongeldige
option-layout. De oorspronkelijke MIGMAC11 productiecompile/donorcontrole
slaagt eveneens op O0/O2. Ook de oorspronkelijke PPA-WU05A9-compositie met
Boesten en actieve macroporiën slaagt op O0/O2, met echte Richards-top-input,
reject/replay en restart. De accessorvergelijking wordt na deze backendwijziging
opnieuw gebouwd en uitgevoerd: zes records, identieke stdout en identieke
executables per optimalisatie tussen routes. Dit ene postimage-paar is
scientific bevestiging; het wordt niet toegevoegd aan de drie baseline-timingrondes.

### Reconciliatie en toelatingsgrens

PR #1211 en #1213 zijn gemerged. Bij de laatste afsluitcontrole is ook PR #1218
gemerged naar canonical `8dac664db83dda8338ef0ffe0f92b55541876978`, vanuit head
`753656fb610ec3f1fd9cbcf98d94f651738d17ce`. Zijn afgeronde
`docs/audits/FCI_SHARED_BUILD_CLOSEOUT_20261013.md` bevat drie gedeelde-buildrondes,
volledige resume-OFF-preservation en aanvullende same-core Richards-paren.
Dat is zijn evidence, geen hier opnieuw gemeten resultaat. De canonical-update
behoudt productie-tree `98440388d8640d5c62ca03f9a193632b3df41ecd` en reference-tree
`c680d7a93aabfd1321c2bcee872aa0361b73fcb8` exact gelijk aan onze oorspronkelijke
baseline. Daarom veranderen de hier geteste productiecomponenten niet door die
update; de eigen allocatiereparatie blijft wel een nog niet admitted bronwijziging.

De drie overlappende performancebestanden worden expliciet op hun nieuwe
canonical-versie gehouden. Twee add/add-conflicten worden zo opgelost zonder
een parallel diagnosticsysteem of verlies van zijn extra counters, solver-walltimer
en toolchaincontrols. Onze uitgevoerde diagnoseversie blijft reproduceerbaar op
commit `7c48c21e1d23dd0d57966793865a85a1531bfca0` in de evidencebundle. De PR-diff
bevat na deze reconciliatie geen wijziging aan zijn drie performancebestanden.

Na reconciliatie zijn alle 156 bronnen van de zes accessor-postimage-records
opnieuw byte-gecontroleerd; zij blijven exact gelijk. Vijftien lokale controls,
docschecks en strict MkDocs slagen opnieuw. Moving F-CI met resume OFF wordt
opnieuw uitgevoerd en weigert dezelfde extra backendbron vóór brede science.
De volledige nieuwe logs en bronbinding staan in de afzonderlijke
`integration/audits/evidence/MODULAR_TESTABILITY_RECONCILIATION_20261013.tar.gz.b64`,
met decoded hash en membercontroles in de bestaande evidence-JSON.

De bestaande moving F-CI-runner is met resume OFF op de gerepareerde bron
uitgevoerd. De eerste poging weigerde ongetrackte Python-bytecode; na opruimen
weigert `verify_daily_demand_successor.py` de aanvullende productiebronwijziging:
zijn exacte source-successor staat uitsluitend drie dagelijkse-demandbestanden
toe. Dit is een **admission/source-authorityblokkade vóór brede wetenschap**,
geen wetenschappelijk PASS en geen numerical regressionbewijs. De bronpinnen
en admissionrunner zijn niet verruimd. De werkunit is geïmplementeerd, gericht
getest en gepersisteerd; volledige kwalificatie en canonical admission blijven
false. Voor backendadmission is een bevoegde exacte successor met volledige
vereiste owner-, coupling-, restart- en F-CI-preservation nodig. PR #1219 blijft
draft met die concrete grens; eerdere backend-PASS wordt niet geërfd.

De Full Richards-revisieproef gebruikt bestaande PR1218-tooling, exact gereconcilieerd
op `38c97e54553f3f0e0fb2be08baa3f6fe8f46ada9`. De oorspronkelijke driver vroeg een
counter die niet in de eerdere contractversie bestaat. Alleen deze optionele
observatie is verwijderd; constitutive-callcount staat UNKNOWN. Physics, instellingen,
masscontrole en input blijven gelijk voor alle revisies. Het is een 50-node
100-cm fixed-step diagnostic traject, geen F-KT/crop/couplingkwalificatie.

Vijf afwisselende herhalingen per horizon zijn voltooid, steeds O2. De timer
meet CPU uitsluitend rond de productie-`solve`; traject-I/O blijft buiten die
timer. De walltijd bevat I/O en controle en is geen solvertijd.

| Revisie | 0,1 dag wall / solve CPU (s) | 30 dagen wall / solve CPU (s) |
| --- | ---: | ---: |
| Eerder `50346642bd565f79134ea17d5462e544b354998c` | 0.007788 / 0.002397 | 2.056777 / 0.919759 |
| Recent `a3859c89eaf97256a6330bb9f6370013c4a9e2f2` | 0.007359 / 0.001059 | 1.580300 / 0.558928 |
| Huidig gemeten `7c48c21e1d23dd0d57966793865a85a1531bfca0` | 0.006883 / 0.001695 | 1.487261 / 0.537442 |

Alle dertig trajectories en beide gprof-runs slagen op de bestaande harde
massgrens 1e-12. Het lange traject heeft 6000 steps, 18001 nonlinear/Jacobian/linear
evaluaties en geen retries op iedere revisie. Recent/huidig zijn fysiek byte-identiek.
Eerder/huidig zijn dat niet: maximale headverschillen circa 2.56e-13 (kort) en
1.39e-12 (lang). De strikte comparator blijft daarom exit 1 met
`equivalent=false`; er is geen nieuwe equivalencetolerantie ingevoerd.
Constitutieve callcount blijft UNKNOWN. De gemeten lange productie-solve is
hier niet trager; korte millisecondemetingen ondersteunen geen algemene
regressieclaim. Een eerlijke matched SWAP4.3.1-runtimevergelijking blijft UNKNOWN.
Zijn bestaande immutable bronarchief is byte-gecontroleerd, niet herverzameld.

De latere allocatiecontrole bevindt zich buiten deze minimale solverclosure.
Evidencebinding controleert expliciet dat alle werkelijk gecompileerde
productiebronnen, driver en fixture tot reparatiepostimage 51152a8 ongewijzigd
zijn. Na de canonical-reconciliatie wordt de nieuwere, afzonderlijk gekwalificeerde
diagnosedriver behouden. Onze oude driverresultaten worden niet als uitvoering
van die nieuwere driver of de latere documentaire HEAD voorgesteld.


### Reproduceerbare opdrachten

De initial-audit-evidence staat in
`integration/audits/evidence/MODULAR_TESTABILITY_INITIAL_20261013.tar.gz.b64`
(decoded SHA256 `87d63a0efbf8c9e964b4b162ddc10462e33042b05468b98676a3d70568f5069e`).
Alle terminale en oorspronkelijke failed logs staan in
`integration/audits/evidence/MODULAR_TESTABILITY_FINAL_20261013.tar.xz.b64`
(decoded SHA256 `d952785389af2d46a114cca19db652d0177355d031838e9b60293958ddc4bff5`).
De bijbehorende audit-JSON verifieert 11561 padidentiteiten, 229 unieke raw blobs
en native terminal-markers. Identieke uitvoerbytes zijn slechts eenmaal opgeslagen;
`INDEX.json` wijst ieder oorspronkelijk pad naar `blobs/<sha256>`, met lengte.
Dit bewaart de volledige ruwe trajectuitvoer, geen samenvatting daarvan.

Decodeer base64 en open respectievelijk gzip/xz. Reconstrueer voor ieder indexpad
de genoemde blob en controleer hash en lengte. Het opgenomen `MODULAR_CODE.bundle`
bevat de werkelijk gemeten lokale commits en de reparatie, met canonical baseline
als prerequisite. Na fetch van die baseline kan `git bundle verify` en
`git fetch <bundle> refs/heads/work/modular-testability-20261013` die geschiedenis
herstellen. GitHub-snapshotcommits hebben andere commitmetadata; zij vervangen
de gemeten lokale SHA's niet. De definitieve gepubliceerde tree wordt afzonderlijk
tegen de lokale tree gecontroleerd.

```bash
# Use the qualified GNU Fortran toolchain on PATH. Each output directory is new.
python tests/modularity/test_modular_controls.py
python tests/modularity/run_modular_tests.py --output /tmp/modular-audit --audit-build
python tests/modularity/run_modular_tests.py --output /tmp/modular-benchmark --benchmark --repeat 3
python tests/modularity/summarize_results.py /tmp/modular-benchmark/RESULTS.json /tmp/modular-summary.json
python tests/modularity/run_contract_guards.py /tmp/modular-guards
python tests/physics/run_ppa_micro05_literal_mvg.py
bash tests/transaction/run_a23bl_gate.sh
WU04B_PRESERVATION_ONLY=1 bash tests/fapp/run_ppa_wu04b_boesten_evaporation.sh
bash tests/fmig431/run_crop_accepted_soil_temperature.sh
# Restore measured commit 7c48c21 from the bundle for this exact diagnostic run.
# Current canonical has its own extended diagnostic driver and separate evidence.
python tools/performance/run_richards_revision_audit.py --output-dir /tmp/richards-revisions --repeat 5
```

Voer meetblokken serieel uit. De auditcontroller bevat geen testselectie voor
canonical admission. De Richards-controller weigert ook byteverschillen tegen
de eerdere revisie met exit 1, zelfs wanneer alle afzonderlijke mass-/science-runs
slagen. Lees `CONTROL.json` om science-failure van strikte vergelijkingsverschillen
te onderscheiden; verander geen tolerantie om dat verschil te verbergen.
