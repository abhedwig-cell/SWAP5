# Modulaire testbaarheid en lokale ontwikkelcyclus

**Status: Proposed ontwikkelstandaard; opt-in implementatieproef.** Baseline:
`1800a1b0d5a8ec38e5e5a2c5a15e916f922dd520`, canonical
`integration/f-ci-canonical`. Geen productiephysics, state-layout, tolerantie,
referentie, workflow of bestaande admissiongate wordt gewijzigd.
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
hier zijn **modulebronbestanden**, zonder gegenereerde probe en eventuele externe
`headcalc.f90`. De compile/linkprobes bewijzen API-bouwbaarheid, geen fysische
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

Directe niet-intrinsieke imports: hydrauliek → solvercontract; timestep →
historische decision service; root → hydraulic view → solvercontract;
temperatuur → hydraulic view en heatcontract → solvercontract; runtime-accessor
→ transaction, kernel, backend, heatcontract. De vier pure/zelfstandige
transaction-/verdampings-/drainage-/assimilation-eenheden hebben geen
niet-intrinsieke imports. Voor Full Richards staat de grotere volledige graph
in `AUDIT.json`, inclusief legacyproviders. De compiler valideert de modulevolgorde.

## Bestaande tooling en implementatie

`tests/support/augment_bartholomeus_backend_sources.py` blijft de bestaande
source-augmenter. Zijn CLI-output wordt vergeleken met de ongewijzigde canonical
implementatie. Een opt-in importeerbare `strict_closure` voegt duplicate-provider,
unresolved-import, cycle en include/preprocessor/submodule-afwijzing toe.
Onbekende buildinputs worden niet als veilige onafhankelijkheid geaccepteerd.
Er komt geen tweede qualificationselector en geen nieuw verplicht register.

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

Resultaten worden ingevuld uit daadwerkelijk voltooide runs. Ruwe compilerlogs,
commandidentiteiten, auditprobes, negatieve controles en niet-geslaagde pogingen
worden in de bestaande `integration/audits/evidence/` hiërarchie opgenomen.
De A/B-proef vergelijkt hetzelfde process-driverprogramma op dezelfde bronpostimage
met dezelfde flags en host, in drie afwisselende rondes. Hij vergelijkt geen
ongelijke volledige versus lokale scientific suites als equivalente dekking.

De Full Richards-revisieproef gebruikt bestaande PR1218-tooling, exact gereconcilieerd
op `38c97e54553f3f0e0fb2be08baa3f6fe8f46ada9`. De oorspronkelijke driver vroeg een
counter die niet in de eerdere contractversie bestaat. Alleen deze optionele
observatie is verwijderd; constitutive-callcount staat UNKNOWN. Physics, instellingen,
masscontrole en input blijven gelijk voor alle revisies. Het is een 50-node
100-cm fixed-step diagnostic traject, geen F-KT/crop/couplingkwalificatie.
